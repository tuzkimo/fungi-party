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
	check(DayNight.sun_energy(0.75) < 0.001, "日落无直射（实得 %.2e）" % DayNight.sun_energy(0.75))


func test_ambient_day_color() -> void:
	check_eq(DayNight.ambient_color(0.5), Color(0.72, 0.78, 0.86), "正午环境光")


func test_ambient_dark_at_midnight() -> void:
	var night := DayNight.ambient_color(0.0)
	check(night.v < 0.3, "午夜环境光很暗（亮度 %.2f）" % night.v)
