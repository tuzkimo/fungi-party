extends TestBase

func test_away_length_in_range() -> void:
	for i in 20:
		var g := Gaze.new(i + 1)
		check(
			g.time_left >= Config.GAZE_AWAY_MIN and g.time_left <= Config.GAZE_AWAY_MAX,
			"AWAY 时长落在 2~5 秒 (%f)" % g.time_left
		)

func test_warn_then_watch_then_away() -> void:
	var g := Gaze.new(1)
	g.advance(g.time_left)
	check_eq(g.phase, Gaze.Phase.WARN, "看黑板结束后进入预警")
	check_eq(g.watching(), -1, "预警阶段不算被看到")
	g.advance(Config.GAZE_WARN)
	check_eq(g.phase, Gaze.Phase.WATCH, "预警 0.3 秒后进入盯视")
	check_eq(g.watching(), g.target, "盯视阶段只有目标座位被看到")
	g.advance(Config.GAZE_WATCH)
	check_eq(g.phase, Gaze.Phase.AWAY, "盯完回到看黑板")

func test_target_changes_between_rounds() -> void:
	var g := Gaze.new(5)
	var seen := {}
	for i in 12:
		g.advance(g.time_left)
		seen[g.target] = true
		g.advance(Config.GAZE_WARN + Config.GAZE_WATCH)
	check(seen.size() >= 2, "目标座位不是永远同一个")

func test_seen_cone() -> void:
	var apex := Vector3.ZERO
	check(Gaze.seen(apex, 0.0, Vector3(0, 0, 3), 14.0, 5.5), "正前方 3m 在锥内")
	check(not Gaze.seen(apex, 0.0, Vector3(0, 0, 6), 14.0, 5.5), "超出 5.5m 看不到")
	check(not Gaze.seen(apex, 0.0, Vector3(3, 0, 3), 14.0, 5.5), "45° 偏角看不到")
	check(Gaze.seen(apex, 0.0, Vector3(0.6, 0, 3), 14.0, 5.5), "11° 偏角还在锥内")

func test_alpha_by_phase() -> void:
	var g := Gaze.new(2)
	check_eq(g.alpha(), 0.0, "看黑板时锥不可见")
	g.advance(g.time_left)
	check(g.alpha() > 0.0 and g.alpha() < 0.55, "预警阶段半透明")
	g.advance(Config.GAZE_WARN)
	check(g.alpha() >= 0.5, "盯视阶段最实")

func test_big_delta_crosses_phases_once() -> void:
	var g := Gaze.new(3)
	g.advance(1000.0)
	check(g.phase != Gaze.Phase.WATCH or g.watching() == g.target, "大 delta 不把状态机卡在矛盾状态")

func test_warn_alpha_fades_in() -> void:
	var g := Gaze.new(2)
	g.advance(g.time_left)
	var begin := g.alpha()
	g.advance(Config.GAZE_WARN * 0.5)
	check(begin < 0.2, "预警刚开始很淡（%f）" % begin)
	check(g.alpha() > begin, "越接近盯视越显眼")

func test_cone_reaches_every_seat() -> void:
	for seat in Config.SEAT_POSITIONS:
		var yaw := Gaze.yaw_to(Config.TEACHER_POS, seat)
		check(
			Gaze.seen(Config.TEACHER_POS, yaw, seat, Config.GAZE_HALF_ANGLE, Config.GAZE_RANGE),
			"视线锥必须够到座位 %s，否则视觉在骗人" % seat
		)
