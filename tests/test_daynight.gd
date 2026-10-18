extends "res://tests/test_base.gd"


func test_sun_overhead_at_noon() -> void:
	check(absf(DayNight.sun_rotation(0.5).x + PI / 2.0) < 0.001, "正午直射向下")


func test_sun_at_horizon_at_sunrise() -> void:
	check(absf(DayNight.sun_rotation(0.25).x) < 0.001, "日出在水平线")


func test_sun_energy_peaks_at_noon() -> void:
	check(absf(DayNight.sun_energy(0.5) - 1.0) < 0.001, "正午最亮")
	check(DayNight.sun_energy(0.25) < 0.001, "日出无直射")
	check(DayNight.sun_energy(0.0) < 0.001, "午夜无直射")
	# sin(PI) 是 1.2e-16，不是精确 0，所以用容差
	check(DayNight.sun_energy(0.75) < 0.001, "日落无直射（实得 %.6f）" % DayNight.sun_energy(0.75))


func test_ambient_day_color() -> void:
	check_eq(DayNight.ambient_color(0.5), Color(0.72, 0.78, 0.86), "正午环境光")


func test_ambient_dimmer_at_midnight() -> void:
	# 夜里要暗，但不能暗到看不见（另有 test_night_ambient_is_bright_enough_to_see 管下限）
	var night := DayNight.ambient_color(0.0)
	check(night.v < DayNight.ambient_color(0.5).v, "午夜比正午暗（%.2f）" % night.v)
	check(night.b > night.r, "夜色偏蓝")


func test_night_is_visible() -> void:
	# 夜里不能黑到走不动路：环境光能量有下限
	check(DayNight.ambient_energy(0.0) >= 0.3, "夜里有保底环境光（实得 %.2f）" % DayNight.ambient_energy(0.0))


func test_sun_color_warms_toward_dawn() -> void:
	var noon := DayNight.sun_color(0.5)
	check(noon.r > 0.9 and noon.b > 0.8, "正午接近白光")
	var dawn := DayNight.sun_color(0.27)
	check(dawn.r > dawn.b + 0.2, "日出偏橙（r %.2f b %.2f）" % [dawn.r, dawn.b])


func test_night_ambient_is_bright_enough_to_see() -> void:
	# 只看能量不够：颜色本身很暗时乘积照样是黑的
	var effective := DayNight.ambient_color(0.0).v * DayNight.ambient_energy(0.0)
	check(effective > 0.18, "夜间实际环境亮度（实得 %.3f）" % effective)


func test_sun_rises_in_plus_z_and_sets_in_minus_z() -> void:
	var rise := DayNight.sun_dir(0.25)
	check(absf(rise.y) < 0.01, "日出贴着地平线（实得 %.3f）" % rise.y)
	check(rise.z > 0.5, "日出在 +Z 那侧（实得 %.3f）" % rise.z)
	var set := DayNight.sun_dir(0.75)
	check(absf(set.y) < 0.01, "日落贴着地平线")
	check(set.z < -0.5, "日落在 -Z 那侧（实得 %.3f）" % set.z)


func test_sun_overhead_at_noon_direction() -> void:
	var noon := DayNight.sun_dir(0.5)
	check(noon.y > 0.99, "正午在头顶（实得 %.3f）" % noon.y)


func test_moon_is_opposite_and_complementary() -> void:
	var t := 0.3
	check(DayNight.moon_dir(t).is_equal_approx(-DayNight.sun_dir(t)), "月亮永远在太阳对面")
	check(DayNight.body_visible(DayNight.sun_dir(0.5)), "白天看得见太阳")
	check(not DayNight.body_visible(DayNight.moon_dir(0.5)), "白天看不见月亮")
	check(DayNight.body_visible(DayNight.moon_dir(0.0)), "夜里看得见月亮")
	check(not DayNight.body_visible(DayNight.sun_dir(0.0)), "夜里看不见太阳")
