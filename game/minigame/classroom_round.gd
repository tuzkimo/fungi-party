class_name ClassroomRound
extends RefCounted

## 教室这一局的规则模型：倒数 → 视线推进 → 人机决策 → 回合 tick。
## 服务器拿它判定，客户端只照着它的快照画（tick 顺序照抄 game/minigame/classroom.gd 的 _process）。
## 全局规矩：真人占 0..humans-1，人机从 humans 往后。

const COUNTDOWN := 3.0
const MAX_DELTA := 1.0 / 30.0

var humans := 1
var countdown := COUNTDOWN
var gaze: Gaze
var eat: StealEat
var npcs: Array[NpcSeat] = []

## 回合的结束状态直接在 eat 里，这里只开个方便读的口子（NetRoom 每 tick 取一次）
var over: bool:
	get:
		return eat.over

var winner: int:
	get:
		return eat.winner

## tick 之间留着上一次的按键：人机那几格由模型自己写
var _press: Array[bool] = []
var _rng := RandomNumberGenerator.new()


func _init(seed_value: int = 1, humans_count: int = 1) -> void:
	humans = clampi(humans_count, 1, Config.SEAT_COUNT)
	_rng.seed = seed_value
	gaze = Gaze.new(seed_value)
	eat = StealEat.new()
	eat.humans = humans
	for i in Config.NPC_GUTS.size():
		npcs.append(NpcSeat.new(Config.NPC_GUTS[i], _rng.randi()))
	for i in Config.SEAT_COUNT:
		_press.append(false)


## 倒数走完才算开局（和本地场景一致：倒数期间不吃、不抓）
func started() -> bool:
	return countdown <= 0.0


func tick(delta: float, press: Array[bool]) -> void:
	if eat.over:
		return
	if countdown > 0.0:
		countdown = maxf(0.0, countdown - delta)
		return
	var d := minf(delta, MAX_DELTA)
	gaze.advance(d)
	for i in npcs.size():
		var seat := humans + i
		if seat >= Config.SEAT_COUNT:
			break
		_press[seat] = npcs[i].decide(d, gaze, seat, (eat.seats[seat] as StealEat.Seat).stun > 0.0)
	for i in humans:
		_press[i] = bool(press[i]) if i < press.size() else false
	eat.tick(d, _press, gaze.watching())


func snapshot() -> Dictionary:
	var seat_states := []
	for seat in eat.seats:
		seat_states.append({
			"bites": seat.bites,
			"fill": seat.fill,
			"caught": seat.caught,
			"stun": seat.stun,
			"out": seat.out,
		})
	return {
		"countdown": countdown,
		"time_left": eat.time_left,
		"over": eat.over,
		"winner": eat.winner,
		"seats": seat_states,
		# left 是给客户端算预警透明度用的（Gaze.alpha）
		"gaze": {
			"phase": gaze.phase,
			"target": gaze.target,
			"left": gaze.time_left,
			"watching": gaze.watching(),
		},
	}


## 这一局某个座位挣了几个币（规则在 StealEat.coins，这里只搬参数）
func coins_for(seat: int) -> int:
	if seat < 0 or seat >= eat.seats.size():
		return 0
	var mine: StealEat.Seat = eat.seats[seat]
	return StealEat.coins(mine.bites, eat.winner == seat, mine.caught)
