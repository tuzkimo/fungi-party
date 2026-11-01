class_name NetRoom
extends RefCounted

## 一局的骨架：座位表、时钟、规则模型。服务器只跑这里的 RefCounted 东西，绝不实例化 3D 场景。
## 座位秩序沿用全项目的规矩：真人占 0..n-1（由调用方排好），人机从 n 往后补。

## 四款小游戏，和 game/minigame/ 下的场景一一对应
const KINDS: Array[String] = ["classroom", "bomb", "owl", "race"]

var kind := ""
## 长度恒为 Config.SEAT_COUNT，每格 {account: String, npc: bool}；人机格 account 为空
var seats: Array[Dictionary] = []
## 规则模型（StealEat / BombRound / OwlRound / RaceField），房间只负责推它和拍快照
var model: RefCounted = null
var elapsed := 0.0
var over := false
var winner := -1
## 这一局的随机种子：规则模型统一用它，两端算出来的随机序列才一样
var session_seed := 0

## 每号座位这一 tick 收到的输入；客户端只说「我按着」，规则在这里算
var _inputs: Array[Dictionary] = []


## 人数超员、账号重复、kind 不认识都返回 null：调用方记日志拒掉，不要「尽量建」。
static func create(kind_value: String, humans: Array[String], seed_value: int = 0) -> NetRoom:
	if not KINDS.has(kind_value) or humans.is_empty() or humans.size() > Config.SEAT_COUNT:
		return null
	var seen := {}
	for h in humans:
		if h.is_empty() or seen.has(h):
			return null
		seen[h] = true
	var room := NetRoom.new()
	room.kind = kind_value
	room.session_seed = seed_value
	for i in Config.SEAT_COUNT:
		var human := i < humans.size()
		room.seats.append({"account": humans[i] if human else "", "npc": not human})
		room._inputs.append({})
	room._build_model()
	return room


## kind → 客户端该进哪个场景。kind 表在这一个地方，服务器和客户端都读它。
static func scene_path(kind_value: String) -> String:
	match kind_value:
		"classroom":
			return Config.CLASSROOM_PATH
		"bomb":
			return Config.BOMB_PATH
		"owl":
			return Config.OWL_PATH
		"race":
			return Config.RACE_PATH
	return ""


func seat_of(account: String) -> int:
	for i in seats.size():
		if not seats[i]["npc"] and seats[i]["account"] == account:
			return i
	return -1


## 输入只认本局的人，外人返回 false 让调用方记日志。过期的输入（已结束）直接丢。
## 客户端多塞的字段一律不留：这里只挑规则用得着的那几个。
func input(account: String, payload: Dictionary) -> bool:
	var seat := seat_of(account)
	if over or seat < 0:
		return false
	if kind == "bomb":
		# 传炸弹是「点一下往哪边扔」，不是按着：合法的方向一收到就交给模型，不留到 tick
		var raw: Variant = payload.get("throw", 0)
		if typeof(raw) != TYPE_INT and typeof(raw) != TYPE_FLOAT:
			return false
		var side := signi(int(raw))
		if side == 0:
			return false
		(model as BombRound).request_throw(seat, side)
		return true
	if kind == "race":
		return _race_input(seat, payload)
	var held: Variant = payload.get("press", false)
	if typeof(held) != TYPE_BOOL:
		return false
	_inputs[seat] = {"press": held}
	return true


## 赛跑的输入有两种形状：横移留着下一 tick 用，跳跃/冲刺是「点一下」——立刻交给模型。
## 网络来的值一律先验类型，验不过就当这条输入不存在。
func _race_input(seat: int, payload: Dictionary) -> bool:
	var round := model as RaceRound
	var used := false
	if payload.has("move"):
		var raw: Variant = payload["move"]
		if typeof(raw) != TYPE_FLOAT and typeof(raw) != TYPE_INT:
			return false
		round.steer(seat, float(raw))
		used = true
	if payload.has("jump"):
		var jump: Variant = payload["jump"]
		if typeof(jump) != TYPE_BOOL:
			return false
		if bool(jump):
			round.jump(seat)
		used = true
	if payload.has("dash"):
		var dash: Variant = payload["dash"]
		if typeof(dash) != TYPE_BOOL:
			return false
		if bool(dash):
			round.dash(seat)
		used = true
	return used


## 推这一局：时钟 + 规则模型。模型说结束就结束。
func tick(delta: float) -> void:
	if over:
		return
	elapsed += maxf(delta, 0.0)
	if model == null:
		return
	if kind == "bomb":
		# 传炸弹的输入在 input() 里已经交给模型了，这里只推时间
		(model as BombRound).tick(delta)
	elif kind == "race":
		# 赛跑的横移和跳/冲也都已经进了模型，这里只推时间
		(model as RaceRound).tick(delta)
	else:
		var press: Array[bool] = []
		for i in seats.size():
			press.append(false if bool(seats[i]["npc"]) else bool((_inputs[i] as Dictionary).get("press", false)))
		if kind == "owl":
			# 猫头鹰一局三关：关间停顿和关卡推进在模型里（本地那一份在 owl.gd 的 Phase 机里）
			(model as OwlRound).tick_match(delta, press)
		else:
			model.tick(delta, press)
	over = bool(model.over)
	winner = int(model.winner)


## 这一局每个真人的收益（人机不算账）。没结束就是空。
func payouts() -> Dictionary:
	var out := {}
	if not over or model == null:
		return out
	for i in seats.size():
		if not bool(seats[i]["npc"]):
			out[str(seats[i]["account"])] = model.coins_for(i)
	return out


func snapshot() -> Dictionary:
	return {
		"kind": kind,
		"seats": seats.duplicate(true),
		"elapsed": elapsed,
		"over": over,
		"winner": winner,
		"seed": session_seed,
		"game": model.snapshot() if model != null else {},
		"earned": payouts(),
	}


## 按 kind 建规则模型。只建服务器上跑得动的东西（RefCounted，不碰节点）。
func _build_model() -> void:
	match kind:
		"classroom":
			model = ClassroomRound.new(session_seed, human_count())
		"bomb":
			var bomb := BombRound.new(session_seed)
			bomb.humans = human_count()
			model = bomb
		"owl":
			var owl := OwlRound.new(session_seed)
			owl.humans = human_count()
			model = owl
		"race":
			model = RaceRound.new(session_seed, human_count())


func human_count() -> int:
	var out := 0
	for seat in seats:
		if not bool(seat["npc"]):
			out += 1
	return out
