extends TestBase

func test_runs_forward() -> void:
	var r := RaceRacer.new(RaceRacer.Style.STEADY, 1)
	var f := RaceField.new(1)
	for i in 60:
		r.advance(1.0 / 60.0, f, i / 60.0)
	check(r.z > 5.0 and r.z < 7.0, "一秒约跑 6 米（实得 %f）" % r.z)

func test_stays_on_track() -> void:
	var r := RaceRacer.new(RaceRacer.Style.HUGGER, 2)
	var f := RaceField.new(2)
	for i in 600:
		r.advance(1.0 / 60.0, f, i / 60.0)
		check(absf(r.x) <= Config.RACE_TRACK_HALF_WIDTH, "不出赛道（x=%f）" % r.x)

func test_hits_and_freezes() -> void:
	var f := RaceField.new(4)
	var g: RaceField.Group = f.groups[0]
	var r := RaceRacer.new(RaceRacer.Style.STEADY, 4)
	r.z = g.z - 1.0
	r.x = g.gap_x + g.gap_width * 0.5 + 1.5   # 故意站在墙里
	r.advance(1.0 / 60.0, f, 0.0)
	check_eq(r.hits, 1, "撞上障碍记一次")
	check(r.z < g.z - 1.0, "撞了往后退")
	check(r.freeze > 0.0, "撞了有硬直")

func test_freezes_block_movement() -> void:
	var f := RaceField.new(4)
	var r := RaceRacer.new(RaceRacer.Style.STEADY, 4)
	r.freeze = 0.3
	var z := r.z
	r.advance(0.1, f, 0.0)
	check(absf(r.z - z) < 0.001, "硬直期间不前进")

func test_personalities_differ() -> void:
	var steady := _sim(RaceRacer.Style.STEADY, 0.0, 40.0)
	var hugger := _sim(RaceRacer.Style.HUGGER, 0.0, 40.0)
	var dasher := _sim(RaceRacer.Style.DASHER, 0.0, 40.0)
	check(hugger["hits"] > steady["hits"], "贴边的撞得更多（%d vs %d）" % [hugger["hits"], steady["hits"]])
	check(dasher["z"] > steady["z"], "冲动型跑得更远（%f vs %f）" % [dasher["z"], steady["z"]])

func test_finish_detected() -> void:
	var r := RaceRacer.new(RaceRacer.Style.STEADY, 3)
	var f := RaceField.new(3)
	r.z = Config.RACE_TRACK_LENGTH - 0.5
	var t := 0.0
	for i in 30:
		r.advance(1.0 / 60.0, f, t)
		t += 1.0 / 60.0
	check(r.finished, "越过终点即完赛")
	check(r.finish_time > 0.0, "记下完赛时间")

func test_big_delta_clamped() -> void:
	var r := RaceRacer.new(RaceRacer.Style.STEADY, 3)
	var f := RaceField.new(3)
	r.advance(1.0, f, 0.0)
	check(r.z < 0.5, "0.3 秒以上的 delta 不会瞬间冲出去（实得 %f）" % r.z)

func _sim(style: int, from_z: float, seconds: float) -> Dictionary:
	var r := RaceRacer.new(style, 9)
	var f := RaceField.new(9)
	r.z = from_z
	var t := 0.0
	while t < seconds and not r.finished:
		r.advance(1.0 / 60.0, f, t)
		t += 1.0 / 60.0
	return {"hits": r.hits, "z": r.z}
