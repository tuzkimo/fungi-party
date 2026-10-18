class_name StartGate
extends Node3D

## 森林起跑线：两道柱子 + 门楣 + 地面白线。只回答「玩家在不在起跑线前」，
## RacePanel 每帧来问（场景往返后旧引用会失效，所以不缓存）。

const POST_COLOR := Color(0.10, 0.36, 0.28)
const FLAG_COLOR := Color(0.86, 0.30, 0.26)
const LINE_COLOR := Color(0.96, 0.96, 0.92)

var player_inside := false

var _area: Area3D


func _ready() -> void:
	add_to_group("start_gate")

	var post := _solid(POST_COLOR)
	_box("PostLeft", Vector3(0.24, 2.6, 0.24), Vector3(-1.2, 1.3, 0.0), post)
	_box("PostRight", Vector3(0.24, 2.6, 0.24), Vector3(1.2, 1.3, 0.0), post)
	_box("Lintel", Vector3(2.7, 0.3, 0.32), Vector3(0.0, 2.6, 0.0), _solid(FLAG_COLOR))
	_box("Line", Vector3(2.2, 0.02, 0.4), Vector3(0.0, 0.01, 0.9), _solid(LINE_COLOR))

	_area = Area3D.new()
	_area.name = "Trigger"
	_area.position = Vector3(0.0, 1.0, 0.4)
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
