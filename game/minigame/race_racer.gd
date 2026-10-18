class_name RaceRacer
extends RefCounted

## 人机跑法：纯逻辑模型，不碰节点也不走物理。
## 每帧决定纵向前进与横向目标；撞击用和玩家同一份 field 数据判定。

enum Style { STEADY, HUGGER, DASHER }

const MAX_DELTA := 1.0 / 30.0
const LOOKAHEAD := 18.0
const HUGGER_LOOKAHEAD := 8.0
const SIDE_SPEED := 7.0
const HUGGER_SIDE_SPEED := 5.0
const DASH_CLEAR := 8.0
const HIT_BACK := 0.5
const HIT_FRONT := 0.9
const HIT_HALF := 0.9
const KEEP_TARGET := 0.9
const PINE_OFFSET := 1.4
const PINE_HALF := 0.6
## 横向抖动：稳中型离缝心还有 1.3m 余量，贴边型零余量，所以它最容易抖出缝
const WOBBLE := [0.2, 0.35, 0.3]

var z := 0.0
var x := 0.0
var hits := 0
var finished := false
var finish_time := 0.0
var dash_left := 0.0
var dash_cd := 0.0
var freeze := 0.0

var _style: int
var _wobble_phase := 0.0
var _side := 1.0


func _init(style: int = Style.STEADY, seed_value: int = 1) -> void:
	_style = style
	_wobble_phase = float(seed_value % 97) * 0.37
	_side = 1.0 if seed_value % 2 == 0 else -1.0


func advance(delta: float, field: RaceField, elapsed: float) -> void:
	var d := minf(delta, MAX_DELTA)
	if freeze > 0.0:
		# 硬直期间不前进、不攒速度；x 也不动，否则会被拽回中线卡在障碍里
		freeze -= d
		return

	dash_cd = maxf(0.0, dash_cd - d)
	var speed := Config.RACE_BASE_SPEED
	if dash_left > 0.0:
		speed = Config.RACE_DASH_SPEED
		dash_left -= d
	z += speed * d
	if z >= Config.RACE_TRACK_LENGTH:
		finished = true
		finish_time = elapsed
		return

	var target := _steer_target(field, elapsed)
	x = move_toward(x, target, _side_speed() * d)
	x = clampf(x, -Config.RACE_TRACK_HALF_WIDTH, Config.RACE_TRACK_HALF_WIDTH)

	if _style == Style.DASHER and dash_left <= 0.0 and dash_cd <= 0.0 and not _blocked(field):
		dash_left = Config.RACE_DASH_SECONDS
		dash_cd = Config.RACE_DASH_COOLDOWN

	_check_hits(field, elapsed)


func _side_speed() -> float:
	return HUGGER_SIDE_SPEED if _style == Style.HUGGER else SIDE_SPEED


## 前方最近的障碍：有缝可钻的组瞄准缝，松鼠留下的松果从中线旁边绕。
func _steer_target(field: RaceField, elapsed: float) -> float:
	var lookahead := HUGGER_LOOKAHEAD if _style == Style.HUGGER else LOOKAHEAD
	var nearest := INF
	var target := 0.0
	for group in field.groups:
		var ahead: float = group.z - z
		if ahead > -KEEP_TARGET and ahead <= lookahead and ahead < nearest:
			nearest = ahead
			target = _gap_target(group)
	for crossing in field.crossings:
		if not _pinecone_dropped(crossing, elapsed):
			continue
		var ahead: float = crossing.z - z
		if ahead > -KEEP_TARGET and ahead <= lookahead and ahead < nearest:
			nearest = ahead
			target = _side * PINE_OFFSET
	target += sin(elapsed * 1.7 + _wobble_phase) * WOBBLE[_style]
	return clampf(target, -Config.RACE_TRACK_HALF_WIDTH, Config.RACE_TRACK_HALF_WIDTH)


func _gap_target(group: RaceField.Group) -> float:
	if _style == Style.HUGGER:
		# 贴边型瞄准离自己最近的那一侧缝沿，等于每次都擦着墙过
		var near_edge := group.gap_x - group.gap_width * 0.5
		var far_edge := group.gap_x + group.gap_width * 0.5
		return near_edge if absf(x - near_edge) <= absf(x - far_edge) else far_edge
	return group.gap_x


## 前方 8m 内有障碍就别冲刺，冲了也只会撞。
func _blocked(field: RaceField) -> bool:
	for group in field.groups:
		if group.z > z and group.z - z <= DASH_CLEAR:
			return true
	return false


## 只有松鼠会丢松果：它横穿到一半时留在中线，整局不消失。
func _pinecone_dropped(crossing: RaceField.Crossing, elapsed: float) -> bool:
	return (
		crossing.kind == RaceField.SQUIRREL
		and elapsed >= crossing.time + Config.RACE_ANIMAL_WARN + RaceField.WALK_IN
	)


func _check_hits(field: RaceField, elapsed: float) -> void:
	for group in field.groups:
		if absf(group.z - z) < _range(group.z) and absf(x - group.gap_x) > group.gap_width * 0.5:
			_bump()
			return
	for crossing in field.crossings:
		if absf(crossing.z - z) >= HIT_HALF:
			continue
		var animal := RaceField.animal_x(crossing.side, elapsed - crossing.time - Config.RACE_ANIMAL_WARN)
		if absf(x - animal) < HIT_HALF:
			_bump()
			return
		if _pinecone_dropped(crossing, elapsed) and absf(x) < PINE_HALF:
			_bump()
			return


## 前后判定范围不对称：已经过去半米不算撞，前方留半米余量。
func _range(group_z: float) -> float:
	return HIT_FRONT if group_z >= z else HIT_BACK


func _bump() -> void:
	
	hits += 1
	z = maxf(0.0, z - Config.RACE_HIT_PUSH)
	freeze = Config.RACE_HIT_FREEZE
	dash_left = 0.0
