class_name OwlTree
extends Node3D

## 森林里的猫头鹰树：一棵比别的树大两号的树，树杈上蹲着一只猫头鹰。
## 只回答「玩家在不在树下」，OwlPanel 每帧来问（场景往返后旧引用会失效，所以不缓存）。
## 写法与 StartGate / BombRing 一致。

const TRUNK_COLOR := Color(0.36, 0.25, 0.16)
const CANOPY_COLOR := Color(0.20, 0.42, 0.24)
const BODY_COLOR := Color(0.55, 0.47, 0.40)
const BEAK_COLOR := Color(0.96, 0.62, 0.22)
const GRASS_COLOR := Color(0.55, 0.68, 0.42)
const TRUNK_HEIGHT := 4.2
const OWL_Y := 3.5
const OWL_Z := 0.45

var player_inside := false

var _area: Area3D


func _ready() -> void:
	add_to_group("owl_tree")
	_build_tree()
	_build_owl()
	_build_ring()

	_area = Area3D.new()
	_area.name = "Trigger"
	_area.position = Vector3(0.0, 1.0, 0.0)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3.4, 2.0, 3.4)
	shape.shape = box
	_area.add_child(shape)
	add_child(_area)


func _physics_process(_delta: float) -> void:
	player_inside = false
	for body in _area.get_overlapping_bodies():
		if body is Player:
			player_inside = true
			break


func _build_tree() -> void:
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.34
	trunk.bottom_radius = 0.52
	trunk.height = TRUNK_HEIGHT
	trunk.radial_segments = 10
	_sphere_or_cylinder("Trunk", trunk, Vector3(0.0, TRUNK_HEIGHT * 0.5, 0.0), _solid(TRUNK_COLOR))

	var canopy := SphereMesh.new()
	canopy.radius = 1.0
	canopy.height = 2.0
	canopy.radial_segments = 12
	canopy.rings = 6
	var canopy_mat := _solid(CANOPY_COLOR)
	_sphere_or_cylinder("CanopyTop", canopy, Vector3(0.0, 5.2, 0.0), canopy_mat, 1.7)
	_sphere_or_cylinder("CanopyLeft", canopy, Vector3(-1.2, 4.5, 0.3), canopy_mat, 1.25)
	_sphere_or_cylinder("CanopyRight", canopy, Vector3(1.2, 4.6, -0.2), canopy_mat, 1.3)


## 横枝 + 猫头鹰：鸟朝 +Z（正对玩家走过来的方向）。
func _build_owl() -> void:
	var branch := CylinderMesh.new()
	branch.top_radius = 0.08
	branch.bottom_radius = 0.09
	branch.height = 1.8
	branch.radial_segments = 8
	var branch_node := _mesh("Branch", branch, Vector3(0.0, OWL_Y - 0.18, 0.2), _solid(TRUNK_COLOR))
	branch_node.rotation_degrees = Vector3(0.0, 0.0, 90.0)
	add_child(branch_node)

	var owl := Node3D.new()
	owl.name = "Owl"
	owl.position = Vector3(0.0, OWL_Y, OWL_Z)
	add_child(owl)

	var body := SphereMesh.new()
	body.radius = 0.34
	body.height = 0.62
	body.radial_segments = 14
	body.rings = 7
	_attach(owl, "Body", body, Vector3.ZERO, _solid(BODY_COLOR))

	var eye := SphereMesh.new()
	eye.radius = 0.13
	eye.height = 0.26
	eye.radial_segments = 10
	eye.rings = 5
	var pupil := SphereMesh.new()
	pupil.radius = 0.07
	pupil.height = 0.14
	pupil.radial_segments = 8
	pupil.rings = 4
	for side in [-1.0, 1.0]:
		_attach(owl, "Eye", eye, Vector3(0.15 * side, 0.10, 0.27), _solid(Color.WHITE))
		_attach(owl, "Pupil", pupil, Vector3(0.15 * side, 0.10, 0.36), _solid(Color(0.08, 0.06, 0.06)))

	var beak := CylinderMesh.new()
	beak.top_radius = 0.0
	beak.bottom_radius = 0.07
	beak.height = 0.16
	beak.radial_segments = 8
	var beak_node := _attach(owl, "Beak", beak, Vector3(0.0, -0.02, 0.34), _solid(BEAK_COLOR))
	beak_node.rotation_degrees = Vector3(90.0, 0.0, 0.0)

	# 两撮耳羽：锥体斜着插在头顶两侧
	for side in [-1.0, 1.0]:
		var ear := _attach(owl, "Ear", beak, Vector3(0.19 * side, 0.30, 0.02), _solid(BODY_COLOR))
		ear.rotation_degrees = Vector3(0.0, 0.0, -22.0 * side)


func _build_ring() -> void:
	var ring_mesh := CylinderMesh.new()
	ring_mesh.top_radius = 1.9
	ring_mesh.bottom_radius = 1.9
	ring_mesh.height = 0.02
	ring_mesh.radial_segments = 24
	_sphere_or_cylinder("GroundRing", ring_mesh, Vector3(0.0, 0.01, 0.0), _solid(GRASS_COLOR))


func _attach(parent: Node3D, node_name: String, mesh: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var node := _mesh(node_name, mesh, pos, mat)
	parent.add_child(node)
	return node


func _mesh(node_name: String, mesh: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = pos
	node.material_override = mat
	return node


## 同一份 mesh 当球用（scale 给半径倍数）或当圆柱用（scale 1）。
func _sphere_or_cylinder(
	node_name: String, mesh: Mesh, pos: Vector3, mat: Material, scale_factor := 1.0
) -> void:
	var node := _mesh(node_name, mesh, pos, mat)
	node.scale = Vector3.ONE * scale_factor
	add_child(node)


func _solid(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	return material
