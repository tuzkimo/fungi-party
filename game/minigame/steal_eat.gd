class_name StealEat
extends RefCounted

## 回合规则：一口要按住吃满，被看到超过宽限就罚站，吃满 N 口或时间到定胜负。
## 纯模型，不碰节点；classroom.gd 把它的返回值画成弹动和面板。

const MAX_DELTA := 1.0 / 30.0


class Seat extends RefCounted:
	var bites := 0
	var fill := 0.0
	var caught := 0
	var stun := 0.0
	var sight := 0.0
	var needs_release := false
	var out := false


var seats: Array = []
var time_left := Config.ROUND_SECONDS
var over := false
var winner := -1
## 前 humans 个座位是人在玩（同屏双人 = 2），其余是人机。
var humans := 1


func _init(count: int = Config.SEAT_COUNT) -> void:
	for i in count:
		seats.append(Seat.new())


func tick(delta: float, press: Array, watched: int) -> Dictionary:
	var chomped: Array[bool] = []
	var caught_now: Array[bool] = []
	for i in seats.size():
		chomped.append(false)
		caught_now.append(false)
	if over:
		return {"chomped": chomped, "caught": caught_now, "over": over, "winner": winner}

	var d := minf(delta, MAX_DELTA)
	time_left -= d

	for i in seats.size():
		var seat: Seat = seats[i]
		seat.stun = maxf(0.0, seat.stun - d)
		if not press[i]:
			seat.needs_release = false
		var eating: bool = press[i] and seat.stun <= 0.0 and not seat.needs_release and not seat.out
		if not eating:
			seat.fill = 0.0
			seat.sight = 0.0
			continue
		seat.fill += d
		seat.sight = seat.sight + d if watched == i else 0.0
		if seat.sight > Config.CATCH_GRACE:
			seat.caught += 1
			seat.stun = Config.STUN_SECONDS
			seat.fill = 0.0
			seat.sight = 0.0
			seat.needs_release = true
			caught_now[i] = true
			if seat.caught >= Config.MAX_CAUGHT:
				seat.out = true
		elif seat.fill >= Config.BITE_SECONDS:
			seat.fill -= Config.BITE_SECONDS
			seat.bites += 1
			chomped[i] = true
			if seat.bites >= Config.BITES_TO_WIN:
				over = true
				winner = i

	if not over and all_humans_out():
		over = true
		winner = decide_winner()
	if not over and time_left <= 0.0:
		over = true
		winner = decide_winner()

	return {"chomped": chomped, "caught": caught_now, "over": over, "winner": winner}


## 全场的人都出局才结束：一个人被罚满三次不该把另一个人的局也收掉。
func all_humans_out() -> bool:
	for i in humans:
		if not (seats[i] as Seat).out:
			return false
	return true


func decide_winner() -> int:
	var best := -1
	for i in seats.size():
		if best < 0:
			best = i
			continue
		var a: Seat = seats[i]
		var b: Seat = seats[best]
		if a.bites > b.bites or (a.bites == b.bites and a.caught < b.caught):
			best = i
	return best


static func coins(bites: int, is_winner: bool, caught: int) -> int:
	var total := Config.COIN_BASE + Config.COIN_PER_BITE * bites + (-Config.COIN_PER_CATCH * caught)
	if is_winner:
		total += Config.COIN_WIN_BONUS
	return maxi(0, total)
