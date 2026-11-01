extends TestBase

## 教室的服务器侧规则模型：倒数 → 视线推进 → 人机决策 → 回合 tick。
## tick 顺序照抄 game/minigame/classroom.gd 的 _process，别在这里重新排。
## 全局规则：StealEat 每 tick 最多认 1/30 秒，所以这里也按 1/60 步进。

const STEP := 1.0 / 60.0


func _press() -> Array[bool]:
	var out: Array[bool] = []
	for i in Config.SEAT_COUNT:
		out.append(false)
	return out


func _press_seat(seat: int) -> Array[bool]:
	var out := _press()
	out[seat] = true
	return out


func _advance(round: ClassroomRound, seconds: float, press: Array[bool]) -> void:
	var steps := int(ceil(seconds / STEP))
	for i in steps:
		round.tick(STEP, press)


## 让视线在接下来一段时间里一直看黑板，测「吃」的时候不受打扰。
func _look_away(round: ClassroomRound) -> void:
	round.gaze.phase = Gaze.Phase.AWAY
	round.gaze.time_left = 999.0


func test_countdown_holds_the_round() -> void:
	var round := ClassroomRound.new(7, 1)
	_advance(round, 2.0, _press())
	check(round.countdown > 0.0, "倒数还没走完")
	check_eq(round.eat.time_left, Config.ROUND_SECONDS, "倒数期间回合时间不走")
	check_eq(round.snapshot()["countdown"], round.countdown, "快照里的倒数和模型一致")
	_advance(round, 1.5, _press())
	check_eq(round.countdown, 0.0, "3 秒后开始")
	check(round.eat.time_left < Config.ROUND_SECONDS, "开始之后回合时间才走")


func test_press_earns_a_bite() -> void:
	var round := ClassroomRound.new(7, 1)
	_advance(round, 3.0, _press())
	_look_away(round)
	_advance(round, Config.BITE_SECONDS + 0.2, _press_seat(0))
	check_eq(round.eat.seats[0].bites, 1, "按住吃满一口")
	_advance(round, 0.5, _press())
	check_eq(round.eat.seats[0].fill, 0.0, "松手进度条清空")


func test_watched_seat_gets_caught_and_must_release() -> void:
	var round := ClassroomRound.new(7, 1)
	_advance(round, 3.0, _press())
	round.gaze.phase = Gaze.Phase.WATCH
	round.gaze.target = 0
	round.gaze.time_left = 999.0
	_advance(round, Config.CATCH_GRACE + 0.2, _press_seat(0))
	check_eq(round.eat.seats[0].caught, 1, "被盯着还吃就被抓")
	check(round.eat.seats[0].stun > 0.0, "抓了要罚站")
	check_eq(round.eat.seats[0].bites, 0, "被抓这一口白吃")


func test_deterministic_with_the_same_seed() -> void:
	var a := ClassroomRound.new(42, 2)
	var b := ClassroomRound.new(42, 2)
	for i in 600:
		a.tick(STEP, _press())
		b.tick(STEP, _press())
	check_eq(a.snapshot(), b.snapshot(), "同一个种子跑出同一局")
	var c := ClassroomRound.new(43, 2)
	for i in 600:
		c.tick(STEP, _press())
	check(a.snapshot() != c.snapshot(), "换种子视线就不一样")


func test_npcs_act_on_their_own() -> void:
	var round := ClassroomRound.new(11, 1)
	_advance(round, 20.0, _press())
	var moved := false
	for i in range(1, Config.SEAT_COUNT):
		var seat: StealEat.Seat = round.eat.seats[i]
		moved = moved or seat.bites > 0 or seat.caught > 0
	check(moved, "人机会自己吃（或者被抓）")


func test_win_on_bites() -> void:
	var round := ClassroomRound.new(7, 1)
	_advance(round, 3.0, _press())
	_look_away(round)
	round.eat.seats[0].bites = Config.BITES_TO_WIN - 1
	_advance(round, Config.BITE_SECONDS + 0.2, _press_seat(0))
	check(round.over, "吃满就结束")
	check_eq(round.winner, 0, "吃满的那个赢")
	check_eq(round.snapshot()["over"], true, "快照说结束了")


func test_timeout_picks_the_best_seat() -> void:
	var round := ClassroomRound.new(7, 1)
	_advance(round, 3.0, _press())
	_look_away(round)
	round.eat.seats[2].bites = 5
	round.eat.time_left = 0.1
	_advance(round, 0.2, _press())
	check(round.over, "时间到就结束")
	check_eq(round.winner, 2, "口数最多的赢")


func test_snapshot_fields() -> void:
	var state := ClassroomRound.new(7, 1).snapshot()
	for key in ["countdown", "time_left", "over", "winner", "seats", "gaze"]:
		check(state.has(key), "快照有 %s" % key)
	var seat: Dictionary = (state["seats"] as Array)[0]
	for key in ["bites", "fill", "caught", "stun", "out"]:
		check(seat.has(key), "座位快照有 %s" % key)
	var gaze: Dictionary = state["gaze"]
	for key in ["phase", "target", "left", "watching"]:
		check(gaze.has(key), "视线快照有 %s" % key)
	check_eq((state["seats"] as Array).size(), Config.SEAT_COUNT, "四个座位都在快照里")


func test_coins_follow_the_rule() -> void:
	var round := ClassroomRound.new(7, 1)
	round.eat.seats[0].bites = 3
	round.eat.seats[0].caught = 1
	check_eq(round.coins_for(0), Config.COIN_BASE + Config.COIN_PER_BITE * 3 - Config.COIN_PER_CATCH, "没赢：底薪 + 每口 - 被抓")
	round.eat.winner = 0
	check_eq(
		round.coins_for(0),
		Config.COIN_BASE + Config.COIN_PER_BITE * 3 - Config.COIN_PER_CATCH + Config.COIN_WIN_BONUS,
		"赢了再加奖金"
	)
	check_eq(round.coins_for(9), 0, "没有那个座位就是 0 币")
