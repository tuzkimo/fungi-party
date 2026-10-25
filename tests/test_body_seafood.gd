extends "res://tests/test_base.gd"

## 海鲜菇：细长杆 + 小帽 + 四根黑棍 + 腮红，没有肚皮和十字印。
## 比例按 refs/海鲜菇角色设计图.png（图高按 2.1 米算）。


func _node(m: MushroomMesh, part_name: String) -> Node:
	return m.find_child(part_name, true, false)


func _seafood() -> MushroomMesh:
	var m := MushroomMesh.new()
	m.use_body("seafood")
	m.build()
	return m


func test_has_its_own_parts() -> void:
	var m := _seafood()
	for part_name in [
		"Stalk", "Cap", "EyeL", "EyeR", "Mouth0", "Mouth4",
		"ArmL", "ArmR", "LegL", "LegR", "CheekL", "CheekR", "Gills",
	]:
		check(_node(m, part_name) != null, "%s 在" % part_name)
	m.free()


func test_has_no_red_mushroom_parts() -> void:
	var m := _seafood()
	check(_node(m, "Belly") == null, "没有白肚皮")
	check(_node(m, "BellyCross") == null, "没有十字印")
	check(_node(m, "Body") == null, "身体不叫 Body（那是红蘑菇的胶囊）")
	m.free()


func test_is_tall_and_thin() -> void:
	var m := _seafood()
	check(absf(m.top() - 2.10) < 0.05, "帽尖约 2.1 米（实得 %.2f）" % m.top())
	check(m.cap_radius < 0.5, "帽子比红蘑菇小一圈（%.2f）" % m.cap_radius)
	check(m.top() / (m.cap_radius * 2.0) > 2.0, "高宽比是夸张的细长")
	m.free()


## 脚要踩在 y=0 上：整体悬空或者陷进地里都会一眼看出来。
func test_feet_reach_the_ground() -> void:
	var m := _seafood()
	var lowest := 99.0
	for part_name in ["LegL", "LegR"]:
		var node := _node(m, part_name) as MeshInstance3D
		if node == null:
			continue
		var aabb := node.mesh.get_aabb()
		# 胶囊沿 +Y 生成后被转了一个角度，把八个角都投一遍取最低
		for corner in [
			Vector3(aabb.position.x, aabb.position.y, aabb.position.z),
			Vector3(aabb.end.x, aabb.position.y, aabb.position.z),
			Vector3(aabb.position.x, aabb.end.y, aabb.position.z),
			Vector3(aabb.end.x, aabb.end.y, aabb.position.z),
			Vector3(aabb.position.x, aabb.position.y, aabb.end.z),
			Vector3(aabb.end.x, aabb.position.y, aabb.end.z),
			Vector3(aabb.position.x, aabb.end.y, aabb.end.z),
			Vector3(aabb.end.x, aabb.end.y, aabb.end.z),
		]:
			lowest = minf(lowest, (node.transform * corner).y)
	check(absf(lowest) < 0.08, "脚底贴着地面（最低点 %.3f）" % lowest)
	m.free()


func test_skin_tints_the_stalk_and_cap() -> void:
	var m := MushroomMesh.new()
	var hero := SkinCatalog.by_id("hero")
	m.use_body("seafood")
	m.use_skin(hero)
	m.build()
	check_eq(m.tint_cap, hero.tint_cap, "帽色跟皮肤")
	var stalk := _node(m, "Stalk") as MeshInstance3D
	check(stalk != null and stalk.material_override.albedo_color == hero.tint_body, "杆色跟皮肤")
	m.free()


## 换回红蘑菇要把尺寸和部件都换回来，不能留着海鲜菇的杆。
func test_switching_back_restores_red() -> void:
	var m := MushroomMesh.new()
	m.use_body("seafood")
	m.build()
	m.use_body("red")
	m.build()
	check(absf(m.body_height - 1.40) < 0.001, "身高回 1.4（实得 %.2f）" % m.body_height)
	check(absf(m.cap_radius - 0.70) < 0.001, "帽半径回 0.70")
	check(_node(m, "Belly") != null, "白肚皮回来了")
	check(_node(m, "Stalk") == null, "细杆没了")
	m.free()
