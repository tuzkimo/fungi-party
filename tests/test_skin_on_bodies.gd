extends "res://tests/test_base.gd"

## 「能戴」= 零件摆在帽子上，不是节点存在。
## 15 顶皮肤 × 2 个体型全量建一遍，检查零件跟着帽子走。

const BODIES := ["red", "seafood"]


func _build(body_id: String, skin_id: String) -> MushroomMesh:
	var m := MushroomMesh.new()
	m.use_body(body_id)
	m.use_skin(SkinCatalog.by_id(skin_id))
	m.build()
	return m


func _node(m: MushroomMesh, part_name: String) -> Node:
	return m.find_child(part_name, true, false)


func test_every_skin_builds_on_every_body() -> void:
	for body_id in BODIES:
		for skin in SkinCatalog.all():
			var m := _build(body_id, skin.id)
			var parts := m.get_child_count()
			check(parts > 5, "%s 戴 %s 建得出来（%d 个顶层节点）" % [body_id, skin.id, parts])
			for part in skin.parts:
				check(m.parts.has(part), "%s 的零件清单搬过来了" % skin.id)
			m.free()


## 零件尺寸跟着帽子走：剑的护手横向偏移、角盔、花在两个体型上
## 除以 cap_radius 之后必须是同一个数。写死绝对值的那次改动会让这条红。
func test_part_geometry_scales_with_cap_radius() -> void:
	var samples := {}
	for body_id in BODIES:
		var m := _build(body_id, "hero")
		var k := m.cap_radius
		var guard := _node(m, "SwordGuard") as MeshInstance3D
		var dome := _node(m, "HelmetDome") as MeshInstance3D
		var pommel := _node(m, "SwordPommel") as MeshInstance3D
		check(guard != null and dome != null and pommel != null, "%s 有剑和角盔" % body_id)
		if guard == null or dome == null or pommel == null:
			m.free()
			return
		samples[body_id] = [
			guard.position.x / k,
			dome.scale.x / k,
			pommel.position.x / k,
			# 剑护手在帽底下方多少（按 k 缩）
			(m.cap_base() - guard.position.y) / k,
		]
		m.free()
	var red: Array = samples["red"]
	var seafood: Array = samples["seafood"]
	var labels := ["护手横向", "角盔半径", "剑首横向", "护手高度"]
	for i in red.size():
		if labels[i] == "护手高度":
			# 纵向是相对帽底的偏移，符号相反但绝对值要一致
			check(absf(absf(red[i]) - absf(seafood[i])) < 0.001, "%s 两头一致" % labels[i])
		else:
			check(absf(float(red[i]) - float(seafood[i])) < 0.001,
				"%s 按 cap_radius 等比（红 %.3f / 海鲜 %.3f）" % [labels[i], red[i], seafood[i]])


## 剑不能埋进帽子：剑身每个采样点都必须离中轴比帽子那一圈更远。
func test_sword_clears_the_cap_on_both_bodies() -> void:
	for body_id in BODIES:
		var m := _build(body_id, "hero")
		var blade := _node(m, "SwordBlade") as MeshInstance3D
		check(blade != null, "%s 拿着剑" % body_id)
		if blade == null:
			m.free()
			continue
		var aabb := blade.mesh.get_aabb()
		var cap_base := m.cap_base()
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
		check(worst > 0.0, "%s 的剑整段在帽子外面（最贴近处差 %.3f）" % [body_id, worst])
		m.free()


## 皇冠、角盔、花要套在帽尖上，帽子一换不能飘在半空。
func test_head_parts_sit_on_the_cap_top() -> void:
	for body_id in BODIES:
		var m := _build(body_id, "king")
		var band := _node(m, "CrownBand") as MeshInstance3D
		check(band != null, "%s 戴着皇冠" % body_id)
		if band != null:
			var gap := band.position.y - m.cap_height * 2.0
			check(gap > -0.20 and gap < 0.10, "%s 的皇冠套在帽尖上（差 %.3f）" % [body_id, gap])
			var radial := sqrt(band.position.x * band.position.x + band.position.z * band.position.z)
			check(radial < 0.5 * m.cap_radius, "%s 的皇冠收在帽顶范围内" % body_id)
		m.free()


## 宽檐是「加大一圈的帽檐」，不能大到自己变成一朵云。
func test_wide_brim_follows_the_cap() -> void:
	for body_id in BODIES:
		var m := _build(body_id, "fly_agaric")
		var brim := _node(m, "Brim") as MeshInstance3D
		check(brim != null, "%s 有宽檐" % body_id)
		if brim != null:
			var ratio := brim.scale.x / m.cap_radius
			check(ratio > 1.0 and ratio < 1.25, "%s 的宽檐只比帽子大一点（%.2f 倍）" % [body_id, ratio])
		m.free()


## 披风是背后一片弧面：换高个子也得挂在背后，不能变成正面一条帘子。
func test_cape_hangs_on_the_back_for_both_bodies() -> void:
	for body_id in BODIES:
		var m := _build(body_id, "hero")
		var cape := _node(m, "Cape") as MeshInstance3D
		check(cape != null, "%s 有披风" % body_id)
		if cape == null:
			m.free()
			continue
		var arrays := (cape.mesh as ArrayMesh).surface_get_arrays(0)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var front := 0
		var top := -99.0
		var bottom := 99.0
		for v in verts:
			if v.z > 0.1:
				front += 1
			top = maxf(top, v.y)
			bottom = minf(bottom, v.y)
		check_eq(front, 0, "%s 的披风不绕到胸前" % body_id)
		# 从帽底附近挂下去，长度别超过腿
		check(top > m.cap_base() - 0.15 and top < m.top(), "%s 的披风顶在脖子附近" % body_id)
		check(bottom > 0.0 and bottom < m.cap_base(), "%s 的披风没拖到地里" % body_id)
		m.free()
