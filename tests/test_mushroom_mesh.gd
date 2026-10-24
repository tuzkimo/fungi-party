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


## 零件不能埋进帽子里：剑身每个采样点都必须离中轴比帽子那一圈更远。
func test_sword_clear_of_cap() -> void:
	var m := MushroomMesh.new()
	m.use_skin(SkinCatalog.by_id("hero"))
	m.build()
	var blade := m.get_node_or_null("SwordBlade") as MeshInstance3D
	check(blade != null, "菇勇者拿着剑")
	if blade == null:
		m.free()
		return
	var aabb := blade.mesh.get_aabb()
	var cap_base := m.body_height - 0.05 - m.cap_height
	var worst := 99.0
	for i in 21:
		var t := -0.5 + float(i) / 20.0
		for side in [-0.5, 0.0, 0.5]:
			var local := Vector3(aabb.size.x * side, t * aabb.size.y, aabb.size.z * side)
			var p: Vector3 = blade.transform * local
			var y_norm := (p.y - cap_base) / (m.cap_height * 2.0)
			if y_norm < 0.0 or y_norm > 1.0:
				continue
			var radial := sqrt(p.x * p.x + p.z * p.z)
			worst = minf(worst, radial - m.cap_radius_at(y_norm))
	check(worst > 0.0, "剑身整段在帽子外面（最贴近处差 %.3f）" % worst)
	m.free()


## 帽子是圆角三角，不是圆顶：往上收得比球快，最宽落在底部。
func test_cap_is_rounded_triangle() -> void:
	var m := MushroomMesh.new()
	m.build()
	var low := m.cap_radius_at(0.25)
	check(m.cap_radius_at(0.02) > 0.98 * m.cap_radius, "最宽在帽子底部")
	check(m.cap_radius_at(0.90) < 0.30 * m.cap_radius, "接近顶尖时已经很窄（三角，不是圆顶）")
	check(m.cap_radius_at(0.75) < 0.60 * low, "侧边收得快，不是球面鼓出来")
	check(m.cap_radius_at(0.98) > 0.0, "顶尖是圆角不是尖刺")
	check(m.cap_radius_at(0.75) < m.cap_radius_at(0.50), "往上单调收窄")
	m.free()


## 旋转体的绕序写反了就会整颗里朝外：法线全部指向中轴、帽子从外面看不见。
func test_cap_normals_point_out() -> void:
	var m := MushroomMesh.new()
	m.build()
	var mesh := m.get_node("Cap").mesh as ArrayMesh
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var inward := 0
	var zero := 0
	for i in verts.size():
		if norms[i].length() < 0.01:
			zero += 1
			continue
		var radial := Vector3(verts[i].x, 0.0, verts[i].z)
		if radial.length() > 0.01 and norms[i].dot(radial.normalized()) < 0.0:
			inward += 1
	check_eq(zero, 0, "没有零长度法线")
	check(inward == 0, "法线全部朝外（朝内的有 %d 个）" % inward)
	m.free()


## 脸要贴在帽面上：帽子轮廓一改，写死的坐标就会浮空或者陷进去。
func test_face_sits_on_cap() -> void:
	var m := MushroomMesh.new()
	m.build()
	for part_name in ["EyeL", "EyeR", "Mouth0", "Mouth2", "Mouth4"]:
		var node := m.get_node_or_null(part_name) as MeshInstance3D
		check(node != null, "%s 在" % part_name)
		if node == null:
			continue
		var p := node.position
		var radial := sqrt(p.x * p.x + p.z * p.z)
		var surface := m.cap_radius_at((p.y - m.cap_base()) / (m.cap_height * 2.0))
		check(absf(radial - surface) < 0.08, "%s 贴着帽面（离面 %.3f）" % [part_name, radial - surface])
	m.free()


## 斑点是均匀绕一圈撒的，正脸那块必须留白，否则会盖住眼睛。
func test_spots_avoid_the_face() -> void:
	var m := MushroomMesh.new()
	m.build()
	var blocked := 0
	for child in m.get_children():
		if not child.name.begins_with("Spot"):
			continue
		var node := child as MeshInstance3D
		var p := node.position
		var y_norm := (p.y - m.cap_base()) / (m.cap_height * 2.0)
		var facing := absf(wrapf(atan2(p.z, p.x) - PI * 0.5, -PI, PI))
		if facing < 0.6 and y_norm > 0.15 and y_norm < 0.50:
			blocked += 1
	check_eq(blocked, 0, "正脸没有斑点（有 %d 个）" % blocked)
	m.free()


## 头顶的零件（冠、角盔、花）要跟着帽尖走，帽子大小一改不能飘在空中。
func test_head_parts_follow_cap_top() -> void:
	var m := MushroomMesh.new()
	m.use_skin(SkinCatalog.by_id("king"))
	m.build()
	var band := m.get_node_or_null("CrownBand") as MeshInstance3D
	check(band != null, "菌王戴着皇冠")
	if band != null:
		var gap := band.position.y - m.cap_top()
		check(gap > -0.20 and gap < 0.10, "皇冠套在帽尖上（差 %.3f）" % gap)
	m.free()


## 剑不能整根埋在拳头里，否则看起来像手里伸出一根刺。
func test_sword_guard_clears_the_hand() -> void:
	var m := MushroomMesh.new()
	m.use_skin(SkinCatalog.by_id("hero"))
	m.build()
	var guard := m.get_node_or_null("SwordGuard") as MeshInstance3D
	var hand := m.get_node_or_null("HandR") as MeshInstance3D
	check(guard != null and hand != null, "有右手也有护手")
	if guard == null or hand == null:
		m.free()
		return
	# 手是半径 1 的球缩放出来的，所以 scale.y 就是半高
	var hand_top := hand.position.y + hand.scale.y
	check(guard.position.y > hand_top, "护手露在拳头上方（%.2f > %.2f）" % [guard.position.y, hand_top])
	check(guard.position.x < hand.position.x + hand.scale.x, "护手还在手这一侧，没飘出去")
	m.free()


## 披风是背后一片弧面，绕成整圈从后面看就像裙子。
func test_cape_covers_only_the_back() -> void:
	var m := MushroomMesh.new()
	m.use_skin(SkinCatalog.by_id("hero"))
	m.build()
	var cape := m.get_node_or_null("Cape") as MeshInstance3D
	check(cape != null, "菇勇者有披风")
	if cape == null:
		m.free()
		return
	var arrays := (cape.mesh as ArrayMesh).surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var front := 0
	for v in verts:
		if v.z > 0.1:
			front += 1
	check_eq(front, 0, "披风不绕到胸前（正面有 %d 个顶点）" % front)
	check(verts.size() > 0, "披风有面")
	m.free()
