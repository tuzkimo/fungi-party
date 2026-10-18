extends TestBase

func test_same_seed_same_course() -> void:
	var a := RaceField.new(7)
	var b := RaceField.new(7)
	check_eq(a.groups.size(), b.groups.size(), "同一种子组数相同")
	for i in a.groups.size():
		check(absf(a.groups[i].z - b.groups[i].z) < 0.001, "同一种子位置相同")

func test_different_seed_different_course() -> void:
	var a := RaceField.new(7)
	var b := RaceField.new(8)
	var diff := false
	for i in mini(a.groups.size(), b.groups.size()):
		if absf(a.groups[i].z - b.groups[i].z) > 0.001 or a.groups[i].kind != b.groups[i].kind:
			diff = true
	check(diff, "换种子应当换地图")

func test_group_spacing_and_bounds() -> void:
	var f := RaceField.new(3)
	check(f.groups.size() >= 8, "220m 的赛道至少 8 组障碍（实得 %d）" % f.groups.size())
	for i in f.groups.size():
		check(f.groups[i].z < Config.RACE_TRACK_LENGTH - 15.0, "每组都离终点留 15m")
		if i == 0:
			continue
		var gap: float = f.groups[i].z - f.groups[i - 1].z
		check(gap >= Config.RACE_GROUP_MIN_GAP - 0.001 and gap <= Config.RACE_GROUP_MAX_GAP + 0.001,
			"组间距 12~18m（实得 %f）" % gap)

func test_gap_inside_track() -> void:
	var f := RaceField.new(11)
	for g in f.groups:
		check(absf(g.gap_x) + g.gap_width * 0.5 <= Config.RACE_TRACK_HALF_WIDTH - 0.3, "缝整条落在赛道内")
		check(g.gap_width >= 2.4, "缝至少 2.4m 宽，人能过去（实得 %f）" % g.gap_width)

func test_kind_ratio() -> void:
	var tall := 0
	var low := 0
	for seed_value in range(1, 41):
		for g in RaceField.new(seed_value).groups:
			tall += 1 if g.kind == RaceField.TALL else 0
			low += 1 if g.kind == RaceField.LOW else 0
	var ratio := float(tall) / float(tall + low)
	check(ratio > 0.6 and ratio < 0.8, "高障碍约占七成（实得 %.2f）" % ratio)

func test_crossings_clear_of_groups() -> void:
	var f := RaceField.new(5)
	check_eq(f.crossings.size(), Config.RACE_ANIMAL_COUNT, "每局六只动物")
	var last := 0.0
	for c in f.crossings:
		check(c.time > last, "出场时刻递增")
		last = c.time
		check(c.side == -1 or c.side == 1, "从一侧进")
		for g in f.groups:
			check(absf(c.z - g.z) >= Config.RACE_ANIMAL_CLEAR, "动物横穿处离障碍组至少 8m（实得 %f）" % absf(c.z - g.z))

func test_animal_x_walks_in_stops_leaves() -> void:
	# 侧面进场 → 停在中间 → 从另一侧离开
	var mid := RaceField.animal_x(1, 1.4 + 0.6)
	check(absf(mid) < 0.001, "进场 1.4 秒后停在赛道中间")
	check(RaceField.animal_x(1, 0.0) > 6.0, "开始时在赛道外")
	check(RaceField.animal_x(1, 4.0) < -6.0, "最后从另一侧离开")
	check(RaceField.animal_x(-1, 0.0) < -6.0, "side=-1 从左进")
