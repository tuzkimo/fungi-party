class_name ForestGen
extends Node3D

## 树和石头：同一份 mesh 用 MultiMesh 批量画，树坑用共享形状的碰撞体铺。

@export var radius := 52.0
@export var tree_count := 240
@export var rock_count := 40
@export var seed_value := 1
@export var clear_radius := 6.0

const TRUNK_TRIS_SEGMENTS := 6
## POI 跟前的净空：树长进帐篷/饭店里比空地难看
const POI_CLEARANCE := 3.5


static func scatter_positions(
	rng: RandomNumberGenerator, count: int, radius: float, clear: float,
	keep_out: Array[Vector3] = []
) -> Array[Vector3]:
	var result: Array[Vector3] = []
	for i in count:
		var angle := rng.randf() * TAU
		var distance := sqrt(rng.randf()) * radius
		if distance < clear:
			distance = clear + (radius - clear) * rng.randf() * 0.1
		result.append(_push_out(Vector3(cos(angle) * distance, 0.0, sin(angle) * distance), keep_out))
	return result


## 只把挡路的推出去，别的树保持原位：整片森林不重排。
static func _push_out(spot: Vector3, keep_out: Array[Vector3]) -> Vector3:
	for poi in keep_out:
		var offset := spot - poi
		offset.y = 0.0
		if offset.length() >= POI_CLEARANCE:
			continue
		spot = poi + (offset.normalized() if offset.length() > 0.01 else Vector3.RIGHT) * POI_CLEARANCE
	return spot


func _ready() -> void:
	generate()


func generate() -> void:
	for child in get_children():
		remove_child(child)
		child.free()

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var spots := ForestGen.scatter_positions(rng, tree_count, radius, clear_radius, Config.POI_SPOTS)

	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.16
	trunk_mesh.bottom_radius = 0.26
	trunk_mesh.height = 2.2
	trunk_mesh.radial_segments = TRUNK_TRIS_SEGMENTS
	trunk_mesh.rings = 1

	var canopy_mesh := SphereMesh.new()
	canopy_mesh.radius = 1.15
	canopy_mesh.height = 2.0
	canopy_mesh.radial_segments = 8
	canopy_mesh.rings = 4

	var trunk_mm := _multimesh("Trunks", trunk_mesh, tree_count, rng)
	var canopy_mm := _multimesh("Canopies", canopy_mesh, tree_count * 2, rng)

	var collision := StaticBody3D.new()
	collision.name = "TreeBodies"
	var trunk_shape := CylinderShape3D.new()
	trunk_shape.radius = 0.34
	trunk_shape.height = 2.4
	add_child(collision)

	var index := 0
	var canopy_index := 0
	for spot in spots:
		var scale_factor := rng.randf_range(0.8, 1.35)
		var yaw := rng.randf() * TAU
		var basis := Basis(Vector3.UP, yaw).scaled(Vector3(scale_factor, scale_factor, scale_factor))
		trunk_mm.set_instance_transform(index, Transform3D(basis, spot + Vector3.UP * 1.1 * scale_factor))
		trunk_mm.set_instance_color(index, _tint(rng, Color(0.28, 0.19, 0.12), 0.06))

		canopy_mm.set_instance_transform(
			canopy_index, Transform3D(basis, spot + Vector3.UP * 2.9 * scale_factor)
		)
		canopy_mm.set_instance_color(canopy_index, _tint(rng, Color(0.15, 0.32, 0.16), 0.08))
		var upper := basis.scaled(Vector3(0.72, 0.72, 0.72))
		canopy_mm.set_instance_transform(
			canopy_index + 1, Transform3D(upper, spot + Vector3.UP * 3.9 * scale_factor)
		)
		canopy_mm.set_instance_color(canopy_index + 1, _tint(rng, Color(0.19, 0.38, 0.19), 0.08))

		var shape := CollisionShape3D.new()
		shape.shape = trunk_shape
		shape.position = spot + Vector3.UP * 1.2 * scale_factor
		collision.add_child(shape)

		index += 1
		canopy_index += 2

	_build_rocks(rng)


func _build_rocks(rng: RandomNumberGenerator) -> void:
	var rock_mesh := SphereMesh.new()
	rock_mesh.radius = 0.6
	rock_mesh.height = 0.9
	rock_mesh.radial_segments = 8
	rock_mesh.rings = 4

	var spots := ForestGen.scatter_positions(rng, rock_count, radius, clear_radius, Config.POI_SPOTS)
	var rocks := _multimesh("Rocks", rock_mesh, rock_count, rng)
	for i in spots.size():
		var scale_factor := rng.randf_range(0.5, 1.6)
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(
			Vector3(scale_factor, scale_factor * 0.7, scale_factor)
		)
		rocks.set_instance_transform(i, Transform3D(basis, spots[i] + Vector3.UP * 0.15))
		rocks.set_instance_color(i, _tint(rng, Color(0.55, 0.55, 0.57), 0.08))

		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = 0.55 * scale_factor
		shape.shape = sphere
		shape.position = spots[i] + Vector3.UP * 0.15
		body.add_child(shape)
		add_child(body)


func _multimesh(node_name: String, mesh: Mesh, count: int, _rng: RandomNumberGenerator) -> MultiMesh:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = mesh
	multimesh.instance_count = count
	var node := MultiMeshInstance3D.new()
	node.name = node_name
	node.multimesh = multimesh
	node.material_override = _vegetation_material()
	add_child(node)
	return multimesh


func _vegetation_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.95
	return material


func _tint(rng: RandomNumberGenerator, base: Color, spread: float) -> Color:
	var shift := rng.randf_range(-spread, spread)
	return Color(
		clampf(base.r + shift, 0.0, 1.0),
		clampf(base.g + shift, 0.0, 1.0),
		clampf(base.b + shift, 0.0, 1.0),
	)
