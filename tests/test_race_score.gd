extends TestBase

func _r(finished: bool, time: float, z: float) -> Dictionary:
	return {"finished": finished, "finish_time": time, "z": z}

func test_finished_first_then_progress() -> void:
	var racers := [
		_r(true, 30.0, 220.0),
		_r(false, 0.0, 140.0),
		_r(false, 0.0, 190.0),
		_r(false, 0.0, 60.0),
	]
	var order := RaceScore.ranking(racers)
	check_eq(order, [0, 2, 1, 3], "先按冲线，再按进度")

func test_tie_progress_keeps_lower_index() -> void:
	var racers := [
		_r(false, 0.0, 100.0),
		_r(false, 0.0, 100.0),
		_r(false, 0.0, 50.0),
		_r(false, 0.0, 10.0),
	]
	check_eq(RaceScore.ranking(racers)[0], 0, "并列时下标小的在前")

func test_coins_by_rank() -> void:
	check_eq(RaceScore.coins(0, 0), 70, "第一名满分")
	check_eq(RaceScore.coins(3, 0), 20, "第四名保底")
	check_eq(RaceScore.coins(1, 3), 35, "第二名撞三次")

func test_settle_when_only_one_racer_left() -> void:
	var racers := [_r(true, 30.0, 220.0), _r(true, 34.0, 220.0), _r(true, 36.0, 220.0), _r(false, 0.0, 90.0)]
	check(RaceScore.decided(racers), "三个冲线就结算，不等第四名")
	racers[2] = _r(false, 0.0, 180.0)
	check(not RaceScore.decided(racers), "还剩两个没冲线就不结算")

func test_coins_never_negative() -> void:
	check_eq(RaceScore.coins(3, 99), 0, "撞太多次夹到 0")
