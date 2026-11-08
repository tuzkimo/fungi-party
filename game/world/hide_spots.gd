class_name HideSpots
extends RefCounted

## 森林里的藏点：垫脚石、木箱、空心断木、石头洞、大蘑菇。
## 只在客户端生成（同一份 seed → 两边看到的一样），服务器不知道这些几何。
##
## 树是 ForestGen 随机撒的，所以垫脚石不能写死坐标：撒完树以后按配置点找最近的树，
## 把石头摆在「配置点 → 树心」之间、离树心 1 米的地方 —— 跳上石、再跳上树干顶（2.16~2.82 米）
## 就埋进树冠里了（树冠是视觉，树干碰撞体只有 2.4 米高）。

## 石头顶面：配上 JUMP_HEIGHT（1.5）能上到树干顶（最低 2.16 米）
const STONE_TOP := 1.15
const STONE_RADIUS := 0.8
## 木箱两级：0.9 → 1.8，够上屋顶（2.2）、顶棚（2.3）、门楣（2.75）
const CRATE_LOW := 0.9
const CRATE_HIGH := 1.8
const CRATE_SIZE := 1.3
const CRATE_OFFSET := 1.3
const TREE_REACH := 6.0
const STONE_TREE_GAP := 1.05

const BARK := Color(0.36, 0.25, 0.16)
const BARK_DARK := Color(0.24, 0.16, 0.10)
const CRATE := Color(0.58, 0.40, 0.23)
const STONE := Color(0.55, 0.55, 0.58)
const CAP := Color(0.82, 0.36, 0.30)
const STEM := Color(0.92, 0.88, 0.78)


## 这个 kind 每一级台阶的高度（测试和 build 共用一份，别写两次）
static func climb_heights(kind: String) -> Array[float]:
	match kind:
		"stone":
			return [STONE_TOP]
		"crates":
			return [CRATE_LOW, CRATE_HIGH]
	return []


static func spots() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for entry in Config.HIDE_SPOTS:
		out.append(entry["pos"] as Vector3)
	return out


static func build(parent: Node3D, trees: Array[Vector3], rng: RandomNumberGenerator) -> void:
	var root := Node3D.new()
	root.name = "HideSpots"
	parent.add_child(root)
	for entry in Config.HIDE_SPOTS:
		var kind := str(entry.get("kind", ""))
		var spot: Vector3 = entry["pos"]
		var yaw := rng.randf() * TAU
		match kind:
			"stone":
				_stone(root, spot, _nearest_tree(trees, spot))
			"crates":
				_crates(root, spot, entry.get("face", Vector3.FORWARD) as Vector3)
			"log":
				_log(root, spot, yaw)
			"cave":
				_cave(root, spot, yaw)
			"cap":
				_cap(root, spot, yaw)
			_:
				push_error("不认识的藏点：%s" % kind)


static func _nearest_tree(trees: Array[Vector3], spot: Vector3) -> Vector3:
	var best := Vector3.ZERO
	var best_distance := TREE_REACH
	for tree in trees:
		var distance := Vector2(tree.x - spot.x, tree.z - spot.z).length()
		if distance < best_distance:
			best_distance = distance
			best = tree
	return best


## 垫脚石：紧挨着树放，跳上去就能上树干顶
static func _stone(root: Node3D, spot: Vector3, tree: Vector3) -> void:
	var at := spot
	if tree != Vector3.ZERO:
		var away := Vector3(tree.x - spot.x, 0.0, tree.z - spot.z)
		at = tree - away.normalized() * STONE_TREE_GAP
	var body := _body(root, at + Vector3.UP * STONE_TOP * 0.5, 0.0)
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = STONE_RADIUS
	cylinder.height = STONE_TOP
	shape.shape = cylinder
	body.add_child(shape)
	var mesh := CylinderMesh.new()
	mesh.top_radius = STONE_RADIUS
	mesh.bottom_radius = STONE_RADIUS * 1.15
	mesh.height = STONE_TOP
	mesh.radial_segments = 10
	mesh.rings = 1
	_paint(root, mesh, at + Vector3.UP * STONE_TOP * 0.5, Vector3.ZERO, _solid(STONE))


## 木箱两级：矮的在配置点，高的朝建筑挪一步
static func _crates(root: Node3D, spot: Vector3, face: Vector3) -> void:
	var toward := Vector3(face.x, 0.0, face.z).normalized()
	_crate(root, spot + Vector3.UP * CRATE_LOW * 0.5, CRATE_SIZE, CRATE_LOW)
	_crate(root, spot + toward * CRATE_OFFSET + Vector3.UP * CRATE_HIGH * 0.5, CRATE_SIZE, CRATE_HIGH)


static func _crate(root: Node3D, at: Vector3, width: float, height: float) -> void:
	var body := _body(root, at, 0.0)
	_static_box(body, Vector3(width, height, width), Vector3.ZERO)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(width, height, width)
	_paint(root, mesh, at, Vector3.ZERO, _solid(CRATE))


## 倒下的空心树干：一侧敞开，里面站一个人
static func _log(root: Node3D, spot: Vector3, yaw: float) -> void:
	_shelter(root, spot, yaw, Vector3(1.8, 1.9, 4.2), BARK, 0.3)
	# 两头的圆截面：让它看起来是一截树干，而不是一个木头棚子
	for side in [-1.0, 1.0]:
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.95
		mesh.bottom_radius = 0.95
		mesh.height = 0.36
		mesh.radial_segments = 12
		_paint(
			root, mesh,
			_place(spot, Vector3(0.0, 0.95, side * 2.1), yaw),
			Vector3(PI / 2.0, yaw, 0.0), _solid(BARK_DARK)
		)


## 石头洞：三块大石垒的小丘，一侧开口
static func _cave(root: Node3D, spot: Vector3, yaw: float) -> void:
	_shelter(root, spot, yaw, Vector3(2.4, 2.2, 2.6), STONE, 0.4)
	# 石头只堆在背面和顶上：开口朝 +Z，别用球把洞口堵上（球没有碰撞，堵上去人就从石头里穿过去）
	for offset in [Vector3(-1.5, 0.8, -1.2), Vector3(1.5, 0.8, -1.2), Vector3(0.0, 2.7, -0.8)]:
		var mesh := SphereMesh.new()
		mesh.radius = 1.5
		mesh.height = 2.6
		mesh.radial_segments = 10
		mesh.rings = 5
		_paint(
			root, mesh,
			_place(spot, offset, yaw),
			Vector3.ZERO, _solid(STONE)
		)


## 大蘑菇：粗杆 + 3 米伞盖，站杆子背光面，伞盖挡视线不挡人
static func _cap(root: Node3D, spot: Vector3, yaw: float) -> void:
	var body := _body(root, spot + Vector3.UP * 1.0, 0.0)
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 0.5
	cylinder.height = 2.0
	shape.shape = cylinder
	body.add_child(shape)
	var stem := CylinderMesh.new()
	stem.top_radius = 0.45
	stem.bottom_radius = 0.55
	stem.height = 2.0
	stem.radial_segments = 12
	_paint(root, stem, spot + Vector3.UP * 1.0, Vector3.ZERO, _solid(STEM))
	var cap := CylinderMesh.new()
	cap.top_radius = 0.6
	cap.bottom_radius = 1.6
	cap.height = 0.9
	cap.radial_segments = 14
	_paint(root, cap, spot + Vector3.UP * 2.4, Vector3(0.0, yaw, 0.0), _solid(CAP))


## 三面墙 + 一个顶，开口朝 +Z（再按 yaw 转）：断木和石洞共用的形状
static func _shelter(
	root: Node3D, spot: Vector3, yaw: float, inner: Vector3, color: Color, thickness: float
) -> void:
	var body := _body(root, spot, yaw)
	var half_w := inner.x * 0.5
	var half_d := inner.z * 0.5
	var top := inner.y
	_static_box(body, Vector3(inner.x + thickness * 2.0, top, thickness), Vector3(0.0, top * 0.5, -half_d - thickness * 0.5))
	for side in [-1.0, 1.0]:
		_static_box(
			body, Vector3(thickness, top, inner.z),
			Vector3(side * (half_w + thickness * 0.5), top * 0.5, 0.0)
		)
	_static_box(
		body, Vector3(inner.x + thickness * 2.0, thickness, inner.z + thickness * 2.0),
		Vector3(0.0, top + thickness * 0.5, 0.0)
	)
	var material := _solid(color)
	var back := BoxMesh.new()
	back.size = Vector3(inner.x + thickness * 2.0, top, thickness)
	_paint(root, back, _place(spot, Vector3(0.0, top * 0.5, -half_d - thickness * 0.5), yaw), Vector3(0.0, yaw, 0.0), material)
	for side in [-1.0, 1.0]:
		var wall := BoxMesh.new()
		wall.size = Vector3(thickness, top, inner.z)
		_paint(
			root, wall,
			_place(spot, Vector3(side * (half_w + thickness * 0.5), top * 0.5, 0.0), yaw),
			Vector3(0.0, yaw, 0.0), material
		)
	var roof := BoxMesh.new()
	roof.size = Vector3(inner.x + thickness * 2.0, thickness, inner.z + thickness * 2.0)
	_paint(root, roof, _place(spot, Vector3.UP * (top + thickness * 0.5), yaw), Vector3(0.0, yaw, 0.0), material)


## 相对配置点的偏移按 yaw 转一圈：墙和它的 mesh 必须重合
static func _place(spot: Vector3, offset: Vector3, yaw: float) -> Vector3:
	return spot + offset.rotated(Vector3.UP, yaw)


static func _body(root: Node3D, at: Vector3, yaw: float) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = at
	body.rotation.y = yaw
	root.add_child(body)
	return body


static func _static_box(body: StaticBody3D, size: Vector3, offset: Vector3) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = offset
	body.add_child(shape)


static func _paint(
	root: Node3D, mesh: Mesh, at: Vector3, rot: Vector3, material: Material
) -> void:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = at
	node.rotation = rot
	node.material_override = material
	root.add_child(node)


static func _solid(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.95
	return material
