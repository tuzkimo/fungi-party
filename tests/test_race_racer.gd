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

func test_finished_stays_finished() -> void:
	# 冲线后 race.gd 仍然每帧调 advance，完赛时间不能被后一帧覆盖
	var r := RaceRacer.new(RaceRacer.Style.STEADY, 3)
	var f := RaceField.new(3)
	r.z = Config.RACE_TRACK_LENGTH - 0.05
	r.advance(1.0 / 60.0, f, 2.0)
	check(r.finished, "先冲线")
	var z := r.z
	r.advance(1.0 / 60.0, f, 9.0)
	check(absf(r.finish_time - 2.0) < 0.001, "完赛时间不被后续帧改写（实得 %f）" % r.finish_time)
	check(absf(r.z - z) < 0.001, "冲线后不再前进")

func test_big_delta_clamped() -> void:
	var r := RaceRacer.new(RaceRacer.Style.STEADY, 3)
	var f := RaceField.new(3)
	r.advance(1.0, f, 0.0)
	check(r.z < 0.5, "0.3 秒以上的 delta 不会瞬间冲出去（实得 %f）" % r.z)

## ---- 真人那一套（纯模型，和人机共用赛道与撞击判定）----

func _human(seed_value: int = 1) -> RaceRacer:
	var r := RaceRacer.new(RaceRacer.Style.STEADY, seed_value)
	r.human = true
	return r

func test_human_runs_forward_on_its_own() -> void:
	# A 案：摇杆只管左右，前进是自动的
	var r := _human()
	var f := RaceField.new(1)
	for i in 60:
		r.advance(1.0 / 60.0, f, i / 60.0)
	check(r.z > 5.0 and r.z < 7.0, "一秒约跑 6 米（实得 %f）" % r.z)

func test_human_steers_toward_screen_side() -> void:
	var r := _human()
	r.steer = 1.0
	r.advance(1.0 / 60.0, RaceField.new(1), 0.0)
	check(r.x < 0.0, "摇杆右推 = 屏幕右 = -x（实得 %f）" % r.x)

func test_human_never_leaves_the_track() -> void:
	var r := _human()
	var f := RaceField.new(1)
	r.steer = 5.0
	for i in 120:
		r.advance(1.0 / 60.0, f, i / 60.0)
	check(absf(r.x) <= Config.RACE_TRACK_HALF_WIDTH, "横移不出赛道（x=%f）" % r.x)

func test_jumping_clears_a_low_hurdle_only() -> void:
	var f := RaceField.new(4)
	var low: RaceField.Group = f.groups[0]
	low.kind = RaceField.LOW
	var r := _human(4)
	r.z = low.z - 0.5
	r.x = low.gap_x + low.gap_width * 0.5 + 1.5
	r.y = 1.0
	r.advance(1.0 / 60.0, f, 0.0)
	check_eq(r.hits, 0, "跳着跨过矮栏")

	var tall := _human(4)
	tall.z = low.z - 0.5
	tall.x = r.x
	tall.y = 1.0
	low.kind = RaceField.TALL
	tall.advance(1.0 / 60.0, f, 0.0)
	check_eq(tall.hits, 1, "高栏跳不过去")

func test_jump_rises_and_lands() -> void:
	var r := _human()
	var f := RaceField.new(1)
	r.want_jump = true
	r.advance(1.0 / 60.0, f, 0.0)
	check(r.y > 0.0, "按跳就离地（y=%f）" % r.y)
	var top := 0.0
	for i in 120:
		r.advance(1.0 / 60.0, f, i / 60.0)
		top = maxf(top, r.y)
	check(top > 1.0, "跳得到 1.5 米高附近（实得 %f）" % top)
	check(absf(r.y) < 0.001, "落回地面")

## 撞了还能横着挪：否则被弹回 1.5 米、硬直 0.6 秒后又正撞同一个障碍，出不来。
func test_steering_works_while_frozen() -> void:
	var r := _human()
	r.freeze = 0.3
	r.steer = 1.0
	var z := r.z
	r.advance(0.1, RaceField.new(1), 0.0)
	check(absf(r.z - z) < 0.001, "硬直期间不前进")
	check(r.x < -0.1, "但能横着挪（x=%f）" % r.x)

## 松果是矮东西：跳起来能过去（旧物理版也跳得过去）。
func test_jumping_clears_a_pinecone() -> void:
	var f := RaceField.new(7)
	var crossing: RaceField.Crossing = f.crossings[0]
	crossing.kind = RaceField.SQUIRREL
	# 松鼠丢下松果后已经走开（不然撞的是松鼠本人）
	var elapsed := crossing.time + Config.RACE_ANIMAL_WARN + 3.2
	var leaping := _human()
	leaping.z = crossing.z
	leaping.y = 1.0
	leaping.advance(1.0 / 60.0, f, elapsed)
	check_eq(leaping.hits, 0, "跳着越过松果")

	var grounded := _human()
	grounded.z = crossing.z
	grounded.advance(1.0 / 60.0, f, elapsed)
	check_eq(grounded.hits, 1, "没跳就撞上松果")

func test_dash_bursts_then_cools_down() -> void:
	var r := _human()
	var f := RaceField.new(1)
	r.want_dash = true
	r.advance(1.0 / 60.0, f, 0.0)
	check(r.dash_left > 0.0, "冲刺开始了")
	check(r.dash_cd > 0.0, "冲刺进冷却")
	var z0 := r.z
	for i in 18:
		r.advance(1.0 / 60.0, f, i / 60.0)
	check(r.z - z0 > 18.0 / 60.0 * Config.RACE_BASE_SPEED, "冲刺期间跑得更快")
	r.want_dash = true
	r.advance(1.0 / 60.0, f, 0.0)
	check(r.dash_left <= 0.0, "冷却期间再按没用")

func test_hit_grounds_the_player() -> void:
	var f := RaceField.new(4)
	var g: RaceField.Group = f.groups[0]
	g.kind = RaceField.TALL
	var r := _human(4)
	r.z = g.z - 0.5
	r.x = g.gap_x + g.gap_width * 0.5 + 1.5
	r.y = 1.0
	r.vy = 2.0
	r.advance(1.0 / 60.0, f, 0.0)
	check_eq(r.hits, 1, "撞上高栏")
	check(absf(r.y) < 0.001, "撞了就落地（y=%f）" % r.y)
	check(r.dash_left <= 0.0, "撞了冲刺作废")

func _sim(style: int, from_z: float, seconds: float) -> Dictionary:
	var r := RaceRacer.new(style, 9)
	var f := RaceField.new(9)
	r.z = from_z
	var t := 0.0
	while t < seconds and not r.finished:
		r.advance(1.0 / 60.0, f, t)
		t += 1.0 / 60.0
	return {"hits": r.hits, "z": r.z}
