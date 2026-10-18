class_name Tent
extends Node3D

## 森林帐篷：两片斜布 + 两根杆 + 卷起来的门帘，里面一张床。开口朝 +Z。
## 只回答「玩家在不在门口」，浮层每帧来问；床的位置给 DayLoop 睡觉用。

const CLOTH := Color(0.84, 0.68, 0.42)
const TRIM := Color(0.72, 0.52, 0.30)
const WOOD := Color(0.42, 0.28, 0.18)
const QUILT := Color(0.36, 0.50, 0.72)
const SHEET := Color(0.94, 0.91, 0.84)
const ROOF_ANGLE := deg_to_rad(30.0)
const TRIGGER_SIZE := Vector3(3.0, 2.0, 3.0)

var player_inside := false

var _area: Area3D


func _ready() -> void:
	add_to_group("tent")

	# 两片斜布：中心各偏 1.3 米、抬到 1.55，绕 Z 轴 ±30° 拼成一个人字棚
	_box("ClothRight", Vector3(3.0, 0.08, 3.4), Vector3(1.3, 1.55, 0.0), _solid(CLOTH), Vector3(0.0, 0.0, -ROOF_ANGLE))
	_box("ClothLeft", Vector3(3.0, 0.08, 3.4), Vector3(-1.3, 1.55, 0.0), _solid(CLOTH), Vector3(0.0, 0.0, ROOF_ANGLE))
	_box("Ridge", Vector3(0.12, 0.12, 3.5), Vector3(0.0, 2.32, 0.0), _solid(TRIM))
	# 两根杆撑在前后脊线下
	_box("PoleFront", Vector3(0.1, 2.3, 0.1), Vector3(0.0, 1.15, 1.62), _solid(WOOD))
	_box("PoleBack", Vector3(0.1, 2.3, 0.1), Vector3(0.0, 1.15, -1.62), _solid(WOOD))

	# 掀上去的卷帘：一根压细的横杆挂在正面左半边
	var roll := CylinderMesh.new()
	roll.top_radius = 0.14
	roll.bottom_radius = 0.14
	roll.height = 1.3
	roll.radial_segments = 12
	var roll_node := MeshInstance3D.new()
	roll_node.name = "DoorRoll"
	roll_node.mesh = roll
	roll_node.position = Vector3(-0.6, 1.75, 1.6)
	roll_node.rotation = Vector3(0.0, 0.0, PI / 2.0)
	roll_node.material_override = _solid(TRIM)
	add_child(roll_node)

	_build_bed()

	_area = Area3D.new()
	_area.name = "Trigger"
	_area.position = Vector3(0.0, 1.0, 2.2)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = TRIGGER_SIZE
	shape.shape = box
	_area.add_child(shape)
	add_child(_area)


## 床的位置：DayLoop 把玩家插值到这里躺下。
func bed_global_position() -> Vector3:
	return $Bed.global_position


func _build_bed() -> void:
	var bed := Node3D.new()
	bed.name = "Bed"
	bed.position = Vector3(0.0, 0.0, -0.7)
	add_child(bed)

	_box_on(bed, "Board", Vector3(1.4, 0.2, 2.2), Vector3(0.0, 0.3, 0.0), _solid(WOOD))
	_box_on(bed, "Quilt", Vector3(1.3, 0.16, 1.4), Vector3(0.0, 0.45, 0.3), _solid(QUILT))

	var pillow_mesh := SphereMesh.new()
	pillow_mesh.radius = 0.36
	pillow_mesh.height = 0.72
	pillow_mesh.radial_segments = 16
	pillow_mesh.rings = 8
	var pillow := MeshInstance3D.new()
	pillow.name = "Pillow"
	pillow.mesh = pillow_mesh
	pillow.position = Vector3(0.0, 0.48, -0.78)
	pillow.scale = Vector3(1.0, 0.4, 0.7)
	pillow.material_override = _solid(SHEET)
	bed.add_child(pillow)


func _physics_process(_delta: float) -> void:
	player_inside = false
	for body in _area.get_overlapping_bodies():
		if body is Player:
			player_inside = true
			break


func _box(node_name: String, size: Vector3, pos: Vector3, material: Material, rot: Vector3 = Vector3.ZERO) -> void:
	_box_on(self, node_name, size, pos, material, rot)


func _box_on(parent: Node3D, node_name: String, size: Vector3, pos: Vector3, material: Material, rot: Vector3 = Vector3.ZERO) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = pos
	node.rotation = rot
	node.material_override = material
	parent.add_child(node)


func _solid(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	return material
