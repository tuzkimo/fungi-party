class_name OwlArena
extends Node3D

## 喂食场地：草地圆盘 + 一棵大树 + 树杈上的猫头鹰 + 光。只管画，不管规则。

const GROUND_RADIUS := 9.0
const GROUND_COLOR := Color(0.34, 0.50, 0.28)
## 树干压暗：屎是棕的，两者撞色的话飞到树前那半秒就看不清
const TRUNK_COLOR := Color(0.26, 0.18, 0.11)
const CANOPY_COLOR := Color(0.19, 0.40, 0.23)
const BODY_COLOR := Color(0.55, 0.47, 0.40)
const BEAK_COLOR := Color(0.96, 0.62, 0.22)
const SKY_COLOR := Color(0.52, 0.68, 0.80)
const TREE_POS := Vector3(0.0, 0.0, -5.6)
const OWL_Y := 3.30
const OWL_Z := -4.60
## 猫头鹰放大一点：手机上它得看清是只鸟，不然只是一团灰
const OWL_SCALE := 1.35
## 下落物的起点：猫头鹰喙前面一点
const BEAK_POINT := Vector3(0.0, 3.12, -4.28)


func build() -> void:
	_build_environment()
	_build_ground()
	_build_tree()
	_build_owl()


func owl_point() -> Vector3:
	return BEAK_POINT


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = SKY_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.58, 0.48)
	env.ambient_light_energy = 0.9
	var node := WorldEnvironment.new()
	node.name = "Environment"
	node.environment = env
	add_child(node)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-52.0, -34.0, 0.0)
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 24.0
	add_child(sun)


func _build_ground() -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = GROUND_RADIUS
	mesh.bottom_radius = GROUND_RADIUS
	mesh.height = 0.2
	mesh.radial_segments = 24
	mesh.rings = 1
	var disc := MeshInstance3D.new()
	disc.name = "Ground"
	disc.mesh = mesh
	disc.position = Vector3(0.0, -0.1, 0.0)
	disc.material_override = _solid(GROUND_COLOR, 0.95)
	add_child(disc)


func _build_tree() -> void:
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.4
	trunk_mesh.bottom_radius = 0.6
	trunk_mesh.height = 5.0
	trunk_mesh.radial_segments = 10
	_place("Trunk", trunk_mesh, TREE_POS + Vector3(0.0, 2.5, 0.0), _solid(TRUNK_COLOR, 0.95))

	var canopy := SphereMesh.new()
	canopy.radius = 1.0
	canopy.height = 2.0
	canopy.radial_segments = 12
	canopy.rings = 6
	var canopy_mat := _solid(CANOPY_COLOR, 0.9)
	_place("CanopyTop", canopy, TREE_POS + Vector3(0.0, 5.2, 0.0), canopy_mat, 1.7)
	_place("CanopyLeft", canopy, TREE_POS + Vector3(-1.1, 4.6, 0.2), canopy_mat, 1.2)
	_place("CanopyRight", canopy, TREE_POS + Vector3(1.1, 4.7, -0.2), canopy_mat, 1.25)

	var branch_mesh := CylinderMesh.new()
	branch_mesh.top_radius = 0.08
	branch_mesh.bottom_radius = 0.09
	branch_mesh.height = 1.8
	branch_mesh.radial_segments = 8
	var branch := _place("Branch", branch_mesh, Vector3(0.0, OWL_Y - 0.22, OWL_Z), _solid(TRUNK_COLOR, 0.95))
	branch.rotation_degrees = Vector3(0.0, 0.0, 90.0)
	branch.position = Vector3(0.0, OWL_Y - 0.22, OWL_Z + 0.2)


## 猫头鹰朝 +Z（正对镜头），玩家看得见它的脸。
func _build_owl() -> void:
	var owl := Node3D.new()
	owl.name = "Owl"
	owl.position = Vector3(0.0, OWL_Y, OWL_Z)
	owl.scale = Vector3.ONE * OWL_SCALE
	add_child(owl)

	var body := SphereMesh.new()
	body.radius = 0.34
	body.height = 0.62
	body.radial_segments = 14
	body.rings = 7
	_attach(owl, "Body", body, Vector3.ZERO, _solid(BODY_COLOR, 0.9))

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
	var white := _solid(Color.WHITE, 0.6)
	var black := _solid(Color(0.08, 0.06, 0.06), 0.5)
	for side in [-1.0, 1.0]:
		_attach(owl, "Eye", eye, Vector3(0.15 * side, 0.10, 0.27), white)
		_attach(owl, "Pupil", pupil, Vector3(0.15 * side, 0.10, 0.36), black)

	var beak := CylinderMesh.new()
	beak.top_radius = 0.0
	beak.bottom_radius = 0.07
	beak.height = 0.16
	beak.radial_segments = 8
	var beak_mat := _solid(BEAK_COLOR, 0.7)
	var beak_node := _attach(owl, "Beak", beak, Vector3(0.0, -0.02, 0.34), beak_mat)
	beak_node.rotation_degrees = Vector3(90.0, 0.0, 0.0)

	for side in [-1.0, 1.0]:
		var ear := _attach(owl, "Ear", beak, Vector3(0.19 * side, 0.30, 0.02), _solid(BODY_COLOR, 0.9))
		ear.rotation_degrees = Vector3(0.0, 0.0, -22.0 * side)


func _place(
	node_name: String, mesh: Mesh, pos: Vector3, mat: Material, scale_factor := 1.0
) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = pos
	node.scale = Vector3.ONE * scale_factor
	node.material_override = mat
	add_child(node)
	return node


func _attach(parent: Node3D, node_name: String, mesh: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = pos
	node.material_override = mat
	parent.add_child(node)
	return node


func _solid(color: Color, roughness: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	return mat
