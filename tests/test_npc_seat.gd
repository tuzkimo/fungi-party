extends TestBase

func _gaze(seat: int, phase: int) -> Gaze:
	var g := Gaze.new(3)
	g.phase = phase
	g.target = seat
	g.time_left = 99.0
	return g

func test_mostly_releases_before_danger_line() -> void:
	var safe := 0
	for seed_value in range(1, 11):
		if _time_to_release(Config.NPC_GUTS[0], seed_value) <= Config.GAZE_WARN + Config.CATCH_GRACE:
			safe += 1
	check(safe >= 8, "怂的人 10 次里至少 8 次在危险线前松手（偶尔手滑才对），实得 %d" % safe)

func test_ignores_other_seats() -> void:
	var g := _gaze(2, Gaze.Phase.WATCH)
	var npc := NpcSeat.new(Config.NPC_GUTS[2], 4)
	var pressed := false
	for i in 10:
		pressed = npc.decide(0.05, g, 1, false)
	check(pressed, "老师盯别人时自己一直在吃")

func test_guts_trade_more_delay() -> void:
	check(_avg_release(Config.NPC_GUTS[2]) > _avg_release(Config.NPC_GUTS[0]), "胆量越大平均越晚松手")

func _avg_release(guts: float) -> float:
	var sum := 0.0
	for seed_value in range(1, 11):
		sum += _time_to_release(guts, seed_value)
	return sum / 10.0

func _time_to_release(guts: float, seed_value: int) -> float:
	var g := _gaze(1, Gaze.Phase.WARN)
	var npc := NpcSeat.new(guts, seed_value)
	var t := 0.0
	while t < 2.0:
		g.phase = Gaze.Phase.WARN if t < Config.GAZE_WARN else Gaze.Phase.WATCH
		if not npc.decide(0.05, g, 1, false):
			return t
		t += 0.05
	return 2.0

func test_seeds_desync() -> void:
	var times := {}
	for seed_value in range(1, 9):
		times[_time_to_release(0.35, seed_value)] = true
	check(times.size() >= 2, "八次里至少两种松手时刻，不是一根木头")

func test_stunned_never_presses() -> void:
	var g := _gaze(1, Gaze.Phase.AWAY)
	var npc := NpcSeat.new(0.5, 9)
	check(not npc.decide(0.05, g, 1, true), "罚站时不按")

func test_rest_gap_after_release() -> void:
	var g := _gaze(1, Gaze.Phase.WATCH)
	var npc := NpcSeat.new(0.15, 5)
	var t := 0.0
	while t < 2.0 and npc.decide(0.05, g, 1, false):
		t += 0.05
	check(t < 2.0, "被盯久了总会松手")
	g.target = 0                     # 视线移走
	check(not npc.decide(0.01, g, 1, false), "刚松手会缓一下才重新开吃")
