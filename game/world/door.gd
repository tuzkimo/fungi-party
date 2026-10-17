class_name ClassroomDoor
extends Node3D

## 森林校门：站在门口 1 秒进教室。用区域内的 body 列表每帧判，
## 不缓存进入事件——场景往返后旧的信号连接会指向已释放的节点。

const HOLD_SECONDS := 1.0
const WOOD := Color(0.34, 0.23, 0.15)
const BOARD := Color(0.16, 0.32, 0.26)
const RING_COLOR := Color(0.95, 0.85, 0.35)

var _area: Area3D
var _ring: MeshInstance3D
var _hold := 0.0


func _ready() -> void:
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
	_ring = MeshInstance3D.new()
	_ring.name = "HoldRing"
	_ring.mesh = ring_mesh
	_ring.material_override = _solid(RING_COLOR)
	_ring.position = Vector3(0.0, 0.01, 0.0)
	_ring.scale = Vector3(0.1, 1.0, 0.1)
	add_child(_ring)

	_area = Area3D.new()
	_area.name = "Trigger"
	_area.position = Vector3(0.0, 1.0, 0.0)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.2, 2.0, 1.6)
	shape.shape = box
	_area.add_child(shape)
	add_child(_area)


func _physics_process(delta: float) -> void:
	var inside := false
	for body in _area.get_overlapping_bodies():
		if body is Player:
			inside = true
			break

	_hold = _hold + delta if inside else 0.0
	if _hold >= HOLD_SECONDS:
		get_tree().change_scene_to_file(Config.CLASSROOM_PATH)
		return

	var progress := 0.1 + 0.9 * minf(_hold / HOLD_SECONDS, 1.0)
	_ring.scale = Vector3(progress, 1.0, progress)


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
