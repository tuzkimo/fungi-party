class_name OwlRound
extends RefCounted

## 猫头鹰喂食的全部规则：四条投喂线、张嘴判定、三关推进、人机决策、名次与币。
## 不碰节点，能无头跑完整局。座位 0 = 玩家，1/2/3 = 稳 / 贪 / 胆小。
## 判定只有一句：东西抵达嘴边那一刻嘴张着吗？不做物理碰撞。

const SEATS := 4
const PLAYER := 0
## 一次 tick 最多走几个子步：快进和掉帧会让 delta 变大，这里防跑飞。
const MAX_STEPS := 16
## 步长贴着抵达时刻切齐：浮点累积会让 flying 停在 1e-17 上，差这一点就当到了
const EPS := 0.0001


class Mouth extends RefCounted:
	var score := 0
	var out := false
	## 显示用：这一刻嘴张着吗（玩家由输入写进来，人机每帧算）
	var open := false
	## 距抵达还有多久；0 = 这条线上没东西在飞
	var flying := 0.0
	## 这一颗的总下落时长，渲染算进度用
	var fall := 0.0
	var poop := false
	## 人机：剩余这么多秒时张嘴；-1 = 这一颗不张嘴
	var lead := -1.0
	## 距下一颗开始下落还有多久
	var wait := 0.0


var mouths: Array = []
var level := 0
var time_left := 0.0
var level_over := false
var events: Array = []

var _rng := RandomNumberGenerator.new()


func _init(seed_value: int = 1) -> void:
	_rng.seed = seed_value
	for i in SEATS:
		mouths.append(Mouth.new())
	start_level(0)


## 进第 index 关：分数和座位对象都留着，只重置这一关的临时状态。
func start_level(index: int) -> void:
	level = clampi(index, 0, Config.OWL_SECONDS.size() - 1)
	time_left = Config.OWL_SECONDS[level]
	level_over = false
	for m in mouths:
		m.out = false
		m.open = false
		m.flying = 0.0
		m.fall = 0.0
		m.poop = false
		m.lead = -1.0
		m.wait = _rng.randf_range(0.3, 0.7)


func player_out() -> bool:
	return mouths[PLAYER].out


## 结果只有两条通道：座位的状态（score/open/out）和 events。没有第二份返回值。
func tick(delta: float, presses: Array) -> void:
	if level_over:
		return

	mouths[PLAYER].open = bool(presses[PLAYER]) and not mouths[PLAYER].out

	# 按「最早抵达」切步：一步绝不跨过任何一次抵达，所以快进也精确
	var left := delta
	var steps := 0
	while left > 0.0 and steps < MAX_STEPS:
		steps += 1
		var step := left
		for m in mouths:
			if m.flying > 0.0 and m.flying <= step + EPS:
				step = m.flying
		left -= step
		time_left -= step
		for i in SEATS:
			var mouth: Mouth = mouths[i]
			var arrived := false
			if mouth.flying > 0.0:
				var open_now := _is_open(i)
				mouth.flying -= step
				if mouth.flying <= 0.0:
					arrived = true
					_arrive(i, open_now)
			if not arrived and mouth.wait > 0.0:
				mouth.wait = maxf(0.0, mouth.wait - step)
				if mouth.wait <= 0.0:
					_spawn(i)
		if time_left <= 0.0:
			time_left = 0.0
			level_over = true
			break

	if left > 0.0:
		# shortcut: 一帧要超过 MAX_STEPS 个子步（极端掉帧 + 快进）时，多余的模拟时间直接丢掉。
		# 后果只是这一关的钟走慢一点，不会错判、不会重复计分；真出现再补。
		time_left = maxf(0.0, time_left - left)
		if time_left <= 0.0:
			level_over = true
			return
	_refresh_open()


func _is_open(seat: int) -> bool:
	var mouth: Mouth = mouths[seat]
	if mouth.out:
		return false
	if seat == PLAYER:
		return mouth.open
	return mouth.lead >= 0.0 and mouth.flying > 0.0 and mouth.flying <= mouth.lead


func _arrive(seat: int, open_now: bool) -> void:
	var mouth: Mouth = mouths[seat]
	mouth.flying = 0.0
	if mouth.out:
		# 出局的座位线上要是还剩一颗（只有测试会这么摆），直接作废
		return
	if open_now and mouth.poop:
		mouth.out = true
		mouth.open = false
		events.append({"kind": "poop", "seat": seat})
	elif open_now:
		mouth.score += 1
		events.append({"kind": "eat", "seat": seat})
	else:
		events.append({"kind": "miss", "seat": seat})
	mouth.poop = false
	mouth.lead = -1.0
	mouth.wait = _gap()


func _spawn(seat: int) -> void:
	var mouth: Mouth = mouths[seat]
	if mouth.out:
		return
	mouth.poop = _rng.randf() < Config.OWL_POOP[level]
	mouth.fall = Config.OWL_FALL[level]
	mouth.flying = mouth.fall
	mouth.lead = -1.0
	if seat == PLAYER:
		return
	var chance: float = Config.OWL_NPC_GREED[seat - 1] if mouth.poop else Config.OWL_NPC_EAT[seat - 1]
	if _rng.randf() >= chance:
		return
	var span: Vector2 = Config.OWL_NPC_LEAD[seat - 1]
	mouth.lead = _rng.randf_range(span.x, span.y) * mouth.fall


func _gap() -> float:
	var span: Vector2 = Config.OWL_GAP[level]
	return _rng.randf_range(span.x, span.y)


func _refresh_open() -> void:
	for i in SEATS:
		if i == PLAYER:
			continue
		var mouth: Mouth = mouths[i]
		mouth.open = (
			not mouth.out and mouth.lead >= 0.0 and mouth.flying > 0.0 and mouth.flying <= mouth.lead
		)


## 分数从高到低；同分按座位序（玩家在前），名次因此不会每次重掷。
static func ranking(scores: Array) -> Array:
	var order := []
	for i in scores.size():
		order.append(i)
	order.sort_custom(
		func(a: int, b: int) -> bool:
			if scores[a] == scores[b]:
				return a < b
			return scores[a] > scores[b]
	)
	return order


static func coins(rank: int) -> int:
	return Config.OWL_RANK_COINS[clampi(rank, 0, Config.OWL_RANK_COINS.size() - 1)]
