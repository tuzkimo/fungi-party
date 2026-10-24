extends "res://tests/test_base.gd"


func test_build_creates_parts() -> void:
	var m := MushroomMesh.new()
	m.build()
	check(m.get_child_count() >= 6, "部件数量（实得 %d）" % m.get_child_count())
	m.free()


func test_build_is_repeatable() -> void:
	var m := MushroomMesh.new()
	m.build()
	var first := m.get_child_count()
	m.build()
	check_eq(m.get_child_count(), first, "重建后部件数量不翻倍")
	m.free()


func test_build_is_fast() -> void:
	var m := MushroomMesh.new()
	var started := Time.get_ticks_msec()
	m.build()
	var cost := Time.get_ticks_msec() - started
	check(cost < 50, "生成耗时 %d ms，应 <50ms" % cost)
	m.free()


func test_use_skin_copies_all_fields() -> void:
	var m := MushroomMesh.new()
	m.use_skin(SkinCatalog.by_id("hero"))
	check_eq(m.spot_count, 8, "斑点数量搬过来")
	check_eq(m.parts, ["sword", "cape", "horned_helmet"], "零件清单搬过来")
	m.free()


func test_use_skin_null_resets() -> void:
	var m := MushroomMesh.new()
	m.use_skin(SkinCatalog.by_id("hero"))
	m.use_skin(null)
	check_eq(m.parts.size(), 0, "零件清空")
	check_eq(m.cap_tilt, 0.0, "帽倾斜复位")
	check_eq(m.spot_glow, 0.0, "发光复位")
	check_eq(m.tint_cap, MushroomSkin.new().tint_cap, "配色回默认")
	m.free()


func test_build_with_parts_does_not_crash() -> void:
	var m := MushroomMesh.new()
	m.use_skin(SkinCatalog.by_id("hero"))
	m.build()
	var plain := MushroomMesh.new()
	plain.build()
	check(m.get_child_count() > plain.get_child_count(), "菇勇者比默认多出零件节点")
	m.free()
	plain.free()


func test_unknown_part_only_warns() -> void:
	var m := MushroomMesh.new()
	m.parts.clear()
	m.parts.append("剑")
	m.build()
	check(m.get_child_count() >= 6, "未知零件只告警，基础部件照建")
	m.free()


## 零件不能埋进帽子里：帽子是个椭球，剑身每个采样点都必须在椭球外。
func test_sword_clear_of_cap() -> void:
	var m := MushroomMesh.new()
	m.use_skin(SkinCatalog.by_id("hero"))
	m.build()
	var blade := m.get_node_or_null("SwordBlade") as MeshInstance3D
	check(blade != null, "菇勇者拿着剑")
	if blade == null:
		m.free()
		return
	var cap_y := m.body_height - 0.05
	var half := (blade.mesh as BoxMesh).size.y * 0.5
	var worst := 99.0
	for i in 21:
		var p: Vector3 = blade.transform * Vector3(0.0, (-1.0 + 0.1 * float(i)) * half, 0.0)
		var v := (p.x * p.x + p.z * p.z) / (m.cap_radius * m.cap_radius) \
			+ pow(p.y - cap_y, 2.0) / (m.cap_height * m.cap_height)
		worst = minf(worst, v)
	check(worst >= 1.0, "剑身整段在帽子外面（最深处椭球值 %.3f，<1 就是埋进去了）" % worst)
	m.free()
