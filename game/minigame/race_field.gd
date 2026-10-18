class_name RaceField
extends RefCounted

## 一条赛道的纯数据：障碍组与动物横穿时间表，全部由种子决定。
## 不碰节点；race_course.gd 照着建几何，race_racer.gd 照着绕。

const TALL := 0
const LOW := 1
const BEETLE := 0
const DUNG := 1
const SQUIRREL := 2

const FIRST_GROUP_Z := 22.0
const TRACK_END_MARGIN := 25.0
const EMPTY_SPACING := 0.1
const GAP_INSET := 0.3
const ANIMAL_FIRST_TIME := 3.0
const ANIMAL_TIME_MIN := 4.0
const ANIMAL_TIME_MAX := 7.0
const ANIMAL_Z_MARGIN := 20.0
const ANIMAL_SAMPLES := 200
const WALK_IN := 1.4
const WALK_STOP := 1.2
const WALK_OUT := 1.4
const START_X := 7.0


class Group extends RefCounted:
	var z := 0.0
	var kind := TALL
	var gap_x := 0.0
	var gap_width := 0.0


class Crossing extends RefCounted:
	var time := 0.0
	var side := 1
	var kind := BEETLE
	var z := 0.0


var groups: Array = []
var crossings: Array = []


func _init(seed_value: int = 1) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	_build_groups(rng)
	_build_crossings(rng)


## 动物相对中线的横向位置，elapsed 从本体进场算起：进场 → 停住 → 从另一侧走掉。
static func animal_x(side: int, elapsed: float) -> float:
	if elapsed < WALK_IN:
		return lerpf(START_X * side, 0.0, maxf(elapsed, 0.0) / WALK_IN)
	if elapsed < WALK_IN + WALK_STOP:
		return 0.0
	var t := clampf((elapsed - WALK_IN - WALK_STOP) / WALK_OUT, 0.0, 1.0)
	return lerpf(0.0, -START_X * side, t)


func _build_groups(rng: RandomNumberGenerator) -> void:
	var z := FIRST_GROUP_Z
	while z < Config.RACE_TRACK_LENGTH - TRACK_END_MARGIN:
		# 空档直接重掷，不消耗纵向距离：记录到的组间距必须留在 12~18m
		if rng.randf() < EMPTY_SPACING:
			continue
		var group := Group.new()
		group.z = z
		group.kind = TALL if rng.randf() < Config.RACE_TALL_CHANCE else LOW
		group.gap_width = Config.RACE_TALL_WIDTH if group.kind == TALL else Config.RACE_LOW_WIDTH
		var limit := Config.RACE_TRACK_HALF_WIDTH - GAP_INSET - group.gap_width * 0.5
		group.gap_x = clampf(rng.randf_range(-limit, limit), -limit, limit)
		groups.append(group)
		z += rng.randf_range(Config.RACE_GROUP_MIN_GAP, Config.RACE_GROUP_MAX_GAP)


func _build_crossings(rng: RandomNumberGenerator) -> void:
	var time := ANIMAL_FIRST_TIME
	for i in Config.RACE_ANIMAL_COUNT:
		var crossing := Crossing.new()
		crossing.time = time
		crossing.side = -1 if rng.randi() % 2 == 0 else 1
		var roll := rng.randf()
		if roll < 0.40:
			crossing.kind = BEETLE
		elif roll < 0.75:
			crossing.kind = DUNG
		else:
			crossing.kind = SQUIRREL
		crossing.z = _animal_z(rng)
		crossings.append(crossing)
		time += rng.randf_range(ANIMAL_TIME_MIN, ANIMAL_TIME_MAX)


## 横穿处离最近的障碍组至少 RACE_ANIMAL_CLEAR，否则可能正好堵住唯一那条缝。
func _animal_z(rng: RandomNumberGenerator) -> float:
	var best := ANIMAL_Z_MARGIN
	var best_clear := -1.0
	for i in ANIMAL_SAMPLES:
		var z := rng.randf_range(ANIMAL_Z_MARGIN, Config.RACE_TRACK_LENGTH - ANIMAL_Z_MARGIN)
		var clear := _clearance(z)
		if clear >= Config.RACE_ANIMAL_CLEAR:
			return z
		if clear > best_clear:
			best_clear = clear
			best = z
	return best


func _clearance(z: float) -> float:
	var nearest := INF
	for group in groups:
		nearest = minf(nearest, absf(z - group.z))
	return nearest
