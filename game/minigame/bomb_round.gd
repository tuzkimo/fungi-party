class_name BombRound
extends RefCounted

## 传炸弹的全部规则：引信、传递、判死、人机判断。不碰任何节点，能无头跑完整局。
## 座位按 南(0, 玩家) → 西(1) → 北(2) → 东(3) 排；玩家面朝北，所以下标 +1 是玩家的左手边，
## 外部传的 side 是「玩家的左右」：side -1 = 左手边 = 下标 +1，side +1 = 右手边 = 下标 -1。

enum Style { STEADY, GAMBLER, SPITEFUL }

const SEATS := 4
const PLAYER := 0
const NPC_STYLE := [Style.STEADY, Style.GAMBLER, Style.SPITEFUL]
## 燃烧速率每 0.4 秒重掷一次：看得见忽快忽慢，数不了秒。
const BURN_REROLL := 0.4

var alive: Array = [0, 1, 2, 3]
var death_order: Array = []
var holder := -1
var thrower := -1
var target := -1
var flight := 0.0
var lock := 0.0
var fuse := 0.0
var queued_side := 0
var over := false
var elapsed := 0.0
var events: Array = []

var _rng := RandomNumberGenerator.new()
var _error := 0.0
var _giver := -1
var _burn := 1.0
var _burn_left := BURN_REROLL


func _init(seed_value: int = 1) -> void:
	_rng.seed = seed_value
	_ignite()


func tick(delta: float) -> void:
	if over:
		return
	elapsed += delta
	_burn_left -= delta
	if _burn_left <= 0.0:
		_burn_left = BURN_REROLL
		_burn = 1.0 + _rng.randf_range(-Config.BOMB_FUSE_JITTER, Config.BOMB_FUSE_JITTER)
	fuse -= delta * _burn
	if fuse <= 0.0:
		_explode()
		return
	if flight > 0.0:
		# 飞行期间谁都不能动作：空中炸算扔的人，就靠这个 return 保住 thrower 字段
		flight -= delta
		if flight <= 0.0:
			_land()
		return
	lock = maxf(0.0, lock - delta)
	if holder == PLAYER:
		if queued_side != 0 and lock <= 0.0:
			_throw(queued_side)
		return
	_npc_think()


## side：-1 左 / +1 右。硬直期间只记方向（回来一结束自动扔），空中或已死直接拒绝。
func request_throw(side: int) -> bool:
	if over or not alive.has(PLAYER):
		return false
	if holder < 0 or flight > 0.0:
		return false
	if lock > 0.0:
		queued_side = -1 if side < 0 else 1
		return false
	return _throw(side)


## 相邻的存活者，跳过死者；side -1 = 下标 +1 方向。
func neighbour(seat: int, side: int) -> int:
	var step := 1 if side < 0 else -1
	for i in range(1, SEATS):
		var s := posmod(seat + step * i, SEATS)
		if alive.has(s):
			return s
	return -1


func tier() -> int:
	if fuse > Config.BOMB_TIER_WARN:
		return 0
	if fuse > Config.BOMB_TIER_HOT:
		return 1
	return 2


func danger() -> float:
	return clampf(1.0 - fuse / 3.0, 0.0, 1.0)


func _ignite() -> void:
	holder = alive[_rng.randi_range(0, alive.size() - 1)]
	lock = Config.BOMB_CATCH_LOCK
	fuse = _roll_fuse()
	queued_side = 0
	thrower = -1
	target = -1
	flight = 0.0
	_giver = -1
	_error = _roll_error(holder)
	events.append({"kind": "ignite", "seat": holder})


func _roll_fuse() -> float:
	var span: Vector2 = Config.BOMB_FUSE_4
	if alive.size() == 3:
		span = Config.BOMB_FUSE_3
	elif alive.size() <= 2:
		span = Config.BOMB_FUSE_2
	return _rng.randf_range(span.x, span.y)


## 人机每次接住重掷自己的判断误差；玩家座位没有误差。
func _roll_error(seat: int) -> float:
	if seat == PLAYER:
		return 0.0
	var limit: float = Config.BOMB_NPC_ERROR[NPC_STYLE[seat - 1]]
	return _rng.randf_range(-limit, limit)


func _throw(side: int) -> bool:
	if holder < 0:
		return false
	var to := neighbour(holder, side)
	if to < 0:
		return false
	events.append({"kind": "throw", "from": holder, "to": to})
	thrower = holder
	target = to
	holder = -1
	flight = Config.BOMB_THROW_SECONDS
	queued_side = 0
	return true


func _land() -> void:
	_giver = thrower
	holder = target
	target = -1
	thrower = -1
	lock = Config.BOMB_CATCH_LOCK
	_error = _roll_error(holder)


func _explode() -> void:
	var in_flight := flight > 0.0
	var dead := thrower if in_flight else holder
	if dead < 0:
		return
	alive.erase(dead)
	death_order.append(dead)
	events.append({"kind": "explode", "seat": dead, "in_flight": in_flight})
	holder = -1
	thrower = -1
	target = -1
	flight = 0.0
	lock = 0.0
	queued_side = 0
	_giver = -1
	if alive.size() <= 1:
		over = true
		events.append({"kind": "over", "winner": int(alive[0]) if alive.size() == 1 else -1})
		return
	_ignite()


## 抱到自己的忍耐线就扔；记仇型优先扔回上一手扔给他的人。
func _npc_think() -> void:
	if holder <= PLAYER:
		return
	var style: int = NPC_STYLE[holder - 1]
	var deadline := clampf(float(Config.BOMB_NPC_THROW_AT[style]) - _error, 0.3, 2.5)
	if fuse > deadline:
		return
	var side := -1 if _rng.randf() < 0.5 else 1
	if style == Style.SPITEFUL:
		if alive.has(_giver) and neighbour(holder, -1) == _giver:
			side = -1
		elif alive.has(_giver) and neighbour(holder, 1) == _giver:
			side = 1
	if not _throw(side):
		_throw(-side)
