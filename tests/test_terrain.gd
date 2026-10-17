extends "res://tests/test_base.gd"


func test_flat_inside() -> void:
	check_eq(Terrain.rim_offset(10.0, 55.0, 90.0, 45.0), 0.0, "内部是平地")


func test_rises_at_outer_edge() -> void:
	check(absf(Terrain.rim_offset(90.0, 55.0, 90.0, 45.0) - 45.0) < 0.001, "外缘升到设定高度")


func test_monotonic() -> void:
	var a := Terrain.rim_offset(60.0, 55.0, 90.0, 45.0)
	var b := Terrain.rim_offset(75.0, 55.0, 90.0, 45.0)
	check(b > a, "越往外越高")


func test_steeper_than_walkable() -> void:
	# 45m 内升高 45m，坡度 > floor_max_angle（45°）才走不上去
	var rise := Terrain.rim_offset(90.0, 55.0, 90.0, 45.0) - Terrain.rim_offset(65.0, 55.0, 90.0, 45.0)
	check(rise / 25.0 > 1.0, "坡度大于 45°")
