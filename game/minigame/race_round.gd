class_name RaceRound
extends RefCounted

## 赛跑一局的规则模型：赛道 + 四个跑者 + 倒数 + 冲线判定 + 币。
## 服务器和本机跑的是同一份（本机自己 tick，服务器把快照发下来）。
## 全局规矩：真人占 0..humans-1，人机从 humans 往后。

const COUNTDOWN := 3.0
const RIVAL_STYLES: Array[int] = [
	RaceRacer.Style.STEADY, RaceRacer.Style.HUGGER, RaceRacer.Style.DASHER
]
const RIVAL_X := [-2.5, 0.0, 2.5]
const RIVAL_Z_STEP := 0.6
## 双人时两个人各站一条道，别叠在一起
const HUMAN_X := [-1.6, 1.6]

var humans := 1
var field: RaceField
var racers: Array[RaceRacer] = []
var countdown := COUNTDOWN
var elapsed := 0.0
var over := false
var winner := -1


func _init(seed_value: int = 1, humans_count: int = 1) -> void:
	humans = clampi(humans_count, 1, Config.SEAT_COUNT)
	field = RaceField.new(seed_value)
	for seat in Config.SEAT_COUNT:
		var racer: RaceRacer
		if seat < humans:
			racer = RaceRacer.new(RaceRacer.Style.STEADY, seed_value + seat)
			racer.human = true
			racer.x = 0.0 if humans == 1 else HUMAN_X[mini(seat, HUMAN_X.size() - 1)]
		else:
			var rival := seat - humans
			racer = RaceRacer.new(RIVAL_STYLES[rival], seed_value + seat * 13)
			racer.x = RIVAL_X[rival]
			racer.z = RIVAL_Z_STEP * float(rival + 1)
		racers.append(racer)


func started() -> bool:
	return countdown <= 0.0


## 输入：横移按着就一直生效，跳跃和冲刺是「点一下」——一收到就交给模型，不等下一个 tick。
func steer(seat: int, move_x: float) -> void:
	if _playing(seat):
		racers[seat].steer = clampf(move_x, -1.0, 1.0)


func jump(seat: int) -> void:
	if _playing(seat):
		racers[seat].want_jump = true


func dash(seat: int) -> void:
	if _playing(seat):
		racers[seat].want_dash = true


func tick(delta: float) -> void:
	if over:
		return
	if countdown > 0.0:
		countdown = maxf(0.0, countdown - delta)
		return
	var d := minf(delta, RaceRacer.MAX_DELTA)
	elapsed += d
	for racer in racers:
		racer.advance(d, field, elapsed)
	winner = RaceScore.ranking(racers)[0]
	over = _decided()


## 前三名定了就不用干等最后一名；到硬顶也收（有人卡住时不许一局挂到天荒地老）。
## 两个真人时改成「等两个人都跑完」：一个人先冲线就把另一个判成未完赛，20 体力白花。
func _decided() -> bool:
	if elapsed >= Config.RACE_TIME_LIMIT:
		return true
	if humans > 1:
		for seat in humans:
			if not racers[seat].finished:
				return false
		return true
	return RaceScore.decided(racers)


func snapshot() -> Dictionary:
	var states := []
	for racer in racers:
		states.append({
			"x": racer.x,
			"y": racer.y,
			"z": racer.z,
			"steer": racer.steer,
			"hits": racer.hits,
			"finished": racer.finished,
			"finish_time": racer.finish_time,
			"dash_left": racer.dash_left,
			"dash_cd": racer.dash_cd,
			"freeze": racer.freeze,
		})
	return {
		"countdown": countdown,
		"elapsed": elapsed,
		"over": over,
		"winner": winner,
		"racers": states,
	}


## 这一局某个座位挣了几个币（名次 + 撞的惩罚都在 RaceScore）
func coins_for(seat: int) -> int:
	if seat < 0 or seat >= racers.size():
		return 0
	return RaceScore.coins(RaceScore.ranking(racers).find(seat), racers[seat].hits)


func _playing(seat: int) -> bool:
	return not over and seat >= 0 and seat < racers.size() and racers[seat].human
