class_name Restaurant
extends Node3D

## 森林饭店：方盒子 + 斜屋顶 + 招牌，门朝 -Z（朝出生点）。
## 跟帐篷一眼分得开：帐篷是布、人字棚；这里是墙、屋顶、招牌。

const WALL := Color(0.93, 0.86, 0.72)
const ROOF := Color(0.66, 0.32, 0.26)
const WOOD := Color(0.42, 0.28, 0.18)
const BOWL := Color(0.96, 0.96, 0.94)
const ROOF_ANGLE := deg_to_rad(25.0)
const TRIGGER_SIZE := Vector3(3.4, 2.0, 3.4)

var player_inside := false

var _area: Area3D


func _ready() -> void:
	add_to_group("restaurant")

	var wall := _solid(WALL)
	_box("WallBack", Vector3(4.4, 2.2, 0.2), Vector3(0.0, 1.1, 1.9), wall)
	for side in [-1.0, 1.0]:
		_box("WallSide", Vector3(0.2, 2.2, 4.0), Vector3(side * 2.1, 1.1, 0.0), wall)
	# 正面留门洞：两块墙板之间空 1.2 米，上面补一条门楣
	for side in [-1.0, 1.0]:
		_box("WallFront", Vector3(1.6, 2.2, 0.2), Vector3(side * 1.4, 1.1, -1.9), wall)
	_box("Lintel", Vector3(1.2, 0.5, 0.2), Vector3(0.0, 1.95, -1.9), wall)

	# 两块斜顶拼成人字，脊线沿 Z
	_box("RoofRight", Vector3(2.6, 0.14, 4.6), Vector3(1.15, 2.75, 0.0), _solid(ROOF), Vector3(0.0, 0.0, -ROOF_ANGLE))
	_box("RoofLeft", Vector3(2.6, 0.14, 4.6), Vector3(-1.15, 2.75, 0.0), _solid(ROOF), Vector3(0.0, 0.0, ROOF_ANGLE))

	# 招牌：门上一块板，板上一个碗
	_box("Sign", Vector3(1.8, 0.7, 0.1), Vector3(0.0, 2.9, -2.05), _solid(WOOD))
	var bowl_mesh := SphereMesh.new()
	bowl_mesh.radius = 0.3
	bowl_mesh.height = 0.3
	bowl_mesh.radial_segments = 16
	bowl_mesh.rings = 8
	var sign_bowl := MeshInstance3D.new()
	sign_bowl.name = "SignBowl"
	sign_bowl.mesh = bowl_mesh
	sign_bowl.position = Vector3(0.0, 2.9, -2.2)
	sign_bowl.scale = Vector3(1.0, 0.5, 1.0)
	sign_bowl.material_override = _solid(BOWL)
	add_child(sign_bowl)

	# 整栋房子的碰撞：相机射线拦得住，玩家也进不去（本来就不做室内）
	var shell := StaticBody3D.new()
	shell.name = "Shell"
	add_child(shell)
	var shell_shape := CollisionShape3D.new()
	var shell_box := BoxShape3D.new()
	shell_box.size = Vector3(4.4, 2.9, 4.0)
	shell_shape.shape = shell_box
	shell_shape.position = Vector3(0.0, 1.45, 0.0)
	shell.add_child(shell_shape)

	_area = Area3D.new()
	_area.name = "Trigger"
	_area.position = Vector3(0.0, 1.0, -3.2)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = TRIGGER_SIZE
	shape.shape = box
	_area.add_child(shape)
	add_child(_area)


func _physics_process(_delta: float) -> void:
	player_inside = false
	for body in _area.get_overlapping_bodies():
		if body is Player:
			player_inside = true
			break


func _box(node_name: String, size: Vector3, pos: Vector3, material: Material, rot: Vector3 = Vector3.ZERO) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = pos
	node.rotation = rot
	node.material_override = material
	add_child(node)


func _solid(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	return material
