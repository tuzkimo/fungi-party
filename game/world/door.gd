class_name ClassroomDoor
extends Node3D

## 森林校门：玩家站进触发区时，DoorPanel 弹出玩法说明与「开始上课」。
## 每帧用区域内的 body 列表判在不在，不缓存进入事件——场景往返后信号连接会旧。

const WOOD := Color(0.34, 0.23, 0.15)
const BOARD := Color(0.16, 0.32, 0.26)
const RING_COLOR := Color(0.95, 0.85, 0.35)

var player_inside := false

var _area: Area3D


func _ready() -> void:
	add_to_group("door")

	var wood := _solid(WOOD)
	_box("PostLeft", Vector3(0.28, 3.0, 0.28), Vector3(-1.1, 1.5, 0.0), wood)
	_box("PostRight", Vector3(0.28, 3.0, 0.28), Vector3(1.1, 1.5, 0.0), wood)
	_box("Lintel", Vector3(2.5, 0.35, 0.35), Vector3(0.0, 3.0, 0.0), wood)
	_box("Sign", Vector3(2.3, 0.6, 0.08), Vector3(0.0, 3.05, 0.22), _solid(BOARD))

	var ring_mesh := CylinderMesh.new()
	ring_mesh.top_radius = 0.9
	ring_mesh.bottom_radius = 0.9
	ring_mesh.height = 0.02
	ring_mesh.radial_segments = 24
	var ring := MeshInstance3D.new()
	ring.name = "DoorRing"
	ring.mesh = ring_mesh
	ring.material_override = _solid(RING_COLOR)
	ring.position = Vector3(0.0, 0.01, 0.0)
	add_child(ring)

	_area = Area3D.new()
	_area.name = "Trigger"
	_area.position = Vector3(0.0, 1.0, 0.0)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.2, 2.0, 1.6)
	shape.shape = box
	_area.add_child(shape)
	add_child(_area)


func _physics_process(_delta: float) -> void:
	player_inside = false
	for body in _area.get_overlapping_bodies():
		if body is Player:
			player_inside = true
			break


func _box(node_name: String, size: Vector3, pos: Vector3, material: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = pos
	node.material_override = material
	add_child(node)


func _solid(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	return material
