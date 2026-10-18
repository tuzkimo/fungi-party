class_name MealBowl
extends Node3D

## 吃饭动画里的那碗饭：浮在玩家面前放大出现 → 停一下 → 缩没。不碰存档，演完自己删。

const BOWL_COLOR := Color(0.86, 0.88, 0.92)
const RICE_COLOR := Color(0.99, 0.97, 0.92)
const APPEAR_SECONDS := 0.15
const HOLD_SECONDS := 0.9
const VANISH_SECONDS := 0.15


static func create() -> MealBowl:
	var bowl := MealBowl.new()
	bowl.name = "MealBowl"

	var bowl_mesh := CylinderMesh.new()
	bowl_mesh.top_radius = 0.24
	bowl_mesh.bottom_radius = 0.17
	bowl_mesh.height = 0.18
	bowl_mesh.radial_segments = 16
	bowl.add_child(_part(bowl_mesh, BOWL_COLOR, Vector3(0.0, 0.0, 0.0), Vector3.ONE))

	var rice_mesh := SphereMesh.new()
	rice_mesh.radius = 0.21
	rice_mesh.height = 0.42
	rice_mesh.radial_segments = 16
	rice_mesh.rings = 8
	bowl.add_child(_part(rice_mesh, RICE_COLOR, Vector3(0.0, 0.12, 0.0), Vector3(1.0, 0.55, 1.0)))
	return bowl


static func _part(mesh: Mesh, color: Color, pos: Vector3, scale: Vector3) -> MeshInstance3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = pos
	node.scale = scale
	node.material_override = material
	return node


func play() -> void:
	scale = Vector3.ONE * 0.01
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3.ONE, APPEAR_SECONDS)
	tween.tween_interval(HOLD_SECONDS)
	tween.tween_property(self, "scale", Vector3.ONE * 0.01, VANISH_SECONDS)
	tween.tween_callback(queue_free)
