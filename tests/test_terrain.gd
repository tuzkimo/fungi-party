extends "res://tests/test_base.gd"


func test_flat_inside() -> void:
	check_eq(Terrain.rim_offset(10.0, 55.0, 90.0, 45.0), 0.0, "内部是平地")


func test_rises_at_outer_edge() -> void:
	check(absf(Terrain.rim_offset(90.0, 55.0, 90.0, 45.0) - 45.0) < 0.001, "外缘升到设定高度")


func test_steep_everywhere() -> void:
	# 边界整圈都必须是走不上去的坡（>45°），不能只有平均坡度够
	var steepest_ok := true
	var worst := 99.0
	var d := 55.0
	while d < 89.0:
		var slope := (Terrain.rim_offset(d + 1.0, 55.0, 90.0, 45.0) - Terrain.rim_offset(d, 55.0, 90.0, 45.0))
		worst = minf(worst, slope)
		steepest_ok = steepest_ok and slope > 1.0
		d += 1.0
	check(steepest_ok, "每一段坡度都 >45°（最缓 %.2f）" % worst)
