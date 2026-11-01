extends TestBase

## 赛跑一局的规则模型：四个座位、倒数、冲线、结算。服务器和本机跑的是同一份。


func test_seats_are_four_with_humans_first() -> void:
	var round := RaceRound.new(7, 2)
	check_eq(round.racers.size(), Config.SEAT_COUNT, "四个跑者")
	check(round.racers[0].human and round.racers[1].human, "0/1 号是真人")
	check(not round.racers[2].human and not round.racers[3].human, "2/3 号是人机")
	check_eq(round.humans, 2, "记着几个真人")


func test_seed_drives_the_track() -> void:
	var a := RaceRound.new(7, 1)
	var b := RaceRound.new(7, 1)
	check_eq(a.field.groups.size(), b.field.groups.size(), "同种子同样的赛道")
	check_eq(a.field.groups[0].gap_x, b.field.groups[0].gap_x, "第一个缝也一样")


func test_countdown_holds_the_start() -> void:
	var round := RaceRound.new(7, 1)
	for i in 60:
		round.tick(1.0 / 60.0)
	check(round.countdown > 0.0, "倒数还没走完")
	check(absf(round.racers[0].z) < 0.001, "倒数期间一步不动")
	for i in 200:
		round.tick(1.0 / 60.0)
	check(round.countdown <= 0.0, "倒数走完")
	check(round.racers[0].z > 1.0, "开跑之后往前走")


func test_input_only_reaches_its_own_seat() -> void:
	var round := RaceRound.new(7, 2)
	round.steer(0, 1.0)
	round.steer(9, 1.0)
	_skip_countdown(round)
	check(round.racers[0].x < 0.0, "0 号在横移")
	check(absf(round.racers[1].x - RaceRound.HUMAN_X[1]) < 0.01, "1 号没被带着动")
	check(absf(round.racers[2].x - RaceRound.RIVAL_X[0]) < 0.01, "人机也不受输入影响")


func test_jump_and_dash_go_through_seat_methods() -> void:
	var round := RaceRound.new(7, 1)
	_skip_countdown(round)
	round.jump(0)
	round.tick(1.0 / 60.0)
	check(round.racers[0].y > 0.0, "跳起来了")
	round.dash(0)
	round.tick(1.0 / 60.0)
	check(round.racers[0].dash_left > 0.0, "冲刺生效")
	check(absf(round.racers[1].dash_left) < 0.001, "人机没吃到冲刺")


func test_finish_time_and_coins() -> void:
	var round := RaceRound.new(7, 1)
	_skip_countdown(round)
	var me := round.racers[0]
	me.z = Config.RACE_TRACK_LENGTH - 0.01
	round.tick(1.0 / 60.0)
	check(me.finished, "越过终点")
	check(me.finish_time > 0.0, "记下完赛时间")
	check_eq(round.winner, 0, "第一名是我")
	check(round.coins_for(0) >= round.coins_for(3), "第一名不比人机少")
	check_eq(round.coins_for(99), 0, "越界座位 0 币")


func test_over_when_the_podium_is_settled() -> void:
	var round := RaceRound.new(7, 1)
	_skip_countdown(round)
	for i in 3:
		round.racers[i].finished = true
		round.racers[i].finish_time = 10.0 + i
	round.tick(1.0 / 60.0)
	check(round.over, "前三名定了就收局，不干等最后一名")


func test_time_limit_ends_the_race() -> void:
	var round := RaceRound.new(7, 1)
	_skip_countdown(round)
	round.elapsed = Config.RACE_TIME_LIMIT
	round.tick(1.0 / 60.0)
	check(round.over, "到硬顶就收")


func test_snapshot_shape() -> void:
	var round := RaceRound.new(7, 2)
	var snap := round.snapshot()
	check(snap.has("countdown") and snap.has("elapsed") and snap.has("over"), "带时钟")
	check_eq((snap["racers"] as Array).size(), Config.SEAT_COUNT, "四个跑者都在快照里")
	var first: Dictionary = (snap["racers"] as Array)[0]
	for key in ["x", "y", "z", "hits", "finished", "finish_time", "dash_cd", "dash_left", "freeze"]:
		check(first.has(key), "快照里带着 %s" % key)


## 倒数按 tick 走完，不靠测试里的 sleep。
func _skip_countdown(round: RaceRound) -> void:
	while round.countdown > 0.0:
		round.tick(0.1)
