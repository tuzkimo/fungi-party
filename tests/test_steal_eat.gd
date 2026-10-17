extends TestBase

const HOLD := [true, false, false, false]
const IDLE := [false, false, false, false]

func _feed(r: StealEat, press: Array, watched: int, seconds: float, step := 1.0 / 60.0) -> void:
	# step 必须 ≤ 1/30，否则 tick 内部的 delta 夹取会让实际推进的时间小于循环计数的时间
	var t := 0.0
	while t < seconds:
		r.tick(step, press, watched)
		t += step

func test_hold_one_bite() -> void:
	var r := StealEat.new(4)
	_feed(r, HOLD, -1, Config.BITE_SECONDS + 0.05)
	check_eq(r.seats[0].bites, 1, "按住 1.6 秒吃满一口")

func test_release_resets_fill() -> void:
	var r := StealEat.new(4)
	_feed(r, HOLD, -1, 1.0)
	_feed(r, IDLE, -1, 0.1)
	check_eq(r.seats[0].bites, 0, "没吃满就松手不加口数")
	check(absf(r.seats[0].fill) < 0.0001, "松手口内进度清零")

func test_catch_needs_grace() -> void:
	var r := StealEat.new(4)
	_feed(r, HOLD, 0, Config.CATCH_GRACE * 0.5)
	check_eq(r.seats[0].caught, 0, "宽限内不算被抓")
	_feed(r, HOLD, 0, 0.06)
	check_eq(r.seats[0].caught, 1, "被看到超过 0.1 秒被抓")
	check(absf(r.seats[0].stun - Config.STUN_SECONDS) < 0.0001, "罚站 3 秒")
	check(absf(r.seats[0].fill) < 0.0001, "被抓打断这一口")

func test_unwatched_never_caught() -> void:
	var r := StealEat.new(4)
	_feed(r, HOLD, 1, 5.0)
	check_eq(r.seats[0].caught, 0, "老师盯着别人时随便吃")

func test_stun_blocks_eating() -> void:
	var r := StealEat.new(4)
	_feed(r, HOLD, 0, 0.2)
	_feed(r, HOLD, -1, 1.0)
	check_eq(r.seats[0].bites, 0, "罚站期间按住也不吃")

func test_catch_requires_release() -> void:
	var r := StealEat.new(4)
	_feed(r, HOLD, 0, 0.2)
	check_eq(r.seats[0].caught, 1, "第一次被抓")
	_feed(r, HOLD, 0, Config.STUN_SECONDS + 1.0)
	check_eq(r.seats[0].caught, 1, "罚站结束后一直按着不会连环被抓")
	_feed(r, IDLE, 0, 0.1)
	_feed(r, HOLD, 0, 0.3)
	check_eq(r.seats[0].caught, 2, "松手再按才会重新被抓")

func test_three_catches_out() -> void:
	var r := StealEat.new(4)
	for i in Config.MAX_CAUGHT:
		_feed(r, HOLD, 0, 0.2)
		_feed(r, IDLE, 0, Config.STUN_SECONDS + 0.1)
	check(r.seats[0].out, "被抓 3 次出局")
	_feed(r, HOLD, -1, 5.0)
	check_eq(r.seats[0].bites, 0, "出局后吃不了")

func test_win_at_n_bites() -> void:
	var r := StealEat.new(4)
	r.seats[0].bites = Config.BITES_TO_WIN - 1
	r.seats[0].fill = Config.BITE_SECONDS - 0.05
	_feed(r, HOLD, -1, 0.1)
	check(r.over, "吃满 N 口立刻结束")
	check_eq(r.winner, 0, "先吃满的赢")

func test_clock_winner_by_progress() -> void:
	var r := StealEat.new(4)
	r.seats[1].bites = 5
	r.seats[2].bites = 3
	r.time_left = 0.05
	_feed(r, IDLE, -1, 0.2)
	check(r.over, "时间到结束")
	check_eq(r.winner, 1, "进度最高者赢")

func test_tie_break_fewer_catches_then_player() -> void:
	var r := StealEat.new(4)
	r.seats[0].bites = 5
	r.seats[1].bites = 5
	r.seats[1].caught = 2
	check_eq(r.decide_winner(), 0, "同口数比少被抓")

func test_big_delta_clamped() -> void:
	var r := StealEat.new(4)
	r.tick(0.5, HOLD, -1)
	check_eq(r.seats[0].bites, 0, "0.5 秒的 delta 不会瞬间吃完一口")
	check(absf(r.seats[0].fill - 1.0 / 30.0) < 0.0001, "单帧只推进 1/30 秒")

func test_coins_formula() -> void:
	check_eq(StealEat.coins(20, true, 0), 110, "满分一局")
	check_eq(StealEat.coins(12, false, 1), 41, "典型一局")
	check_eq(StealEat.coins(0, false, 3), 0, "扣成负数夹到 0")

func test_player_out_ends_round() -> void:
	var r := StealEat.new(4)
	r.seats[0].caught = Config.MAX_CAUGHT
	r.seats[0].out = true
	_feed(r, IDLE, -1, 0.1)
	check(r.over, "玩家出局后回合立刻结束，不留几十秒干等的空转")
