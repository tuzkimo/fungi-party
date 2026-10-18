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


func test_scatter_keeps_pois_clear() -> void:
	var pois: Array[Vector3] = [Config.TENT_POS, Config.RESTAURANT_POS]
	var plain := ForestGen.scatter_positions(_rng(), 240, 52.0, 6.0)
	var spots := ForestGen.scatter_positions(_rng(), 240, 52.0, 6.0, pois)
	check_eq(spots.size(), 240, "树的数量不变")

	var closest := 999.0
	for s in spots:
		for p in pois:
			closest = minf(closest, Vector2(s.x - p.x, s.z - p.z).length())
	check(closest >= ForestGen.POI_CLEARANCE, "POI 跟前不长树（最近的树 %.2f 米）" % closest)

	# 只把挡路的树推出去，别的树保持原位，整片森林不重排
	var moved := 0
	var moved_only_offenders := true
	for i in plain.size():
		if plain[i] == spots[i]:
			continue
		moved += 1
		var offending := false
		for p in pois:
			if Vector2(plain[i].x - p.x, plain[i].z - p.z).length() < ForestGen.POI_CLEARANCE:
				offending = true
		moved_only_offenders = moved_only_offenders and offending
	check(moved > 0, "确实推走了挡路的树（%d 棵）" % moved)
	check(moved_only_offenders, "没挡路的树一棵都没动")


func _rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	return rng
