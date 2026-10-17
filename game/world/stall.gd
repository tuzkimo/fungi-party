class_name Stall
extends Node3D

## 森林摊位：柜台、顶棚、老板和一个触发区。
## 只回答「玩家在不在跟前」，商店浮层每帧来问。

const WOOD := Color(0.42, 0.28, 0.18)
const CLOTH := Color(0.80, 0.36, 0.32)
const TRIGGER_SIZE := Vector3(3.4, 2.0, 3.4)

var player_inside := false


func _ready() -> void:
	add_to_group("stall")

	_box("Counter", Vector3(2.4, 0.9, 0.8), Vector3(0.0, 0.45, 0.0), _solid(WOOD))
	_box("Awning", Vector3(3.0, 0.12, 2.0), Vector3(0.0, 2.3, -0.2), _solid(CLOTH))
	for side in [-1.0, 1.0]:
		for far in [-1.0, 1.0]:
			_box("Post", Vector3(0.08, 2.3, 0.08), Vector3(side * 1.4, 1.15, -0.2 + far * 0.88), _solid(WOOD))

	var boss := MushroomMesh.new()
	boss.name = "ShopBoss"
	boss.tint_cap = Color(0.95, 0.80, 0.30)
	boss.scale = Vector3.ONE * 0.85
	boss.position = Vector3(0.0, 0.0, -0.9)
	add_child(boss)

	var area := Area3D.new()
	area.name = "Trigger"
	area.position = Vector3(0.0, 1.0, 1.0)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = TRIGGER_SIZE
	shape.shape = box
	area.add_child(shape)
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)
	add_child(area)


func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		player_inside = true


func _on_body_exited(body: Node3D) -> void:
	if body is Player:
		player_inside = false


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
