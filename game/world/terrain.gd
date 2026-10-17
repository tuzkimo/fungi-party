class_name Terrain
extends Node3D

## 地形：中心一块平地，外圈抬起成陡坡当天然边界。
## 坡度必须大于 World 的 floor_max_angle（45°），否则角色能爬出去。

@export var size := 180.0
@export var flat_radius := 55.0
@export var rim_height := 45.0
@export var subdivisions := 48


static func rim_offset(distance: float, flat: float, outer: float, height: float) -> float:
	# 线性而不是二次：二次曲线起点坡度是 0，角色能顺着爬高几米才撞墙。
	return clampf((distance - flat) / (outer - flat), 0.0, 1.0) * height


func _ready() -> void:
	build()


func build() -> void:
	for child in get_children():
		remove_child(child)
		child.free()

	var plane := PlaneMesh.new()
	plane.size = Vector2(size, size)
	plane.subdivide_width = subdivisions
	plane.subdivide_depth = subdivisions
	var arrays := plane.get_mesh_arrays()

	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var outer := size * 0.5
	var noise := FastNoiseLite.new()
	noise.seed = 7
	noise.frequency = 0.03
	for i in verts.size():
		var p := verts[i]
		var distance := Vector2(p.x, p.z).length()
		var base := Terrain.rim_offset(distance, flat_radius, outer, rim_height)
		p.y = base + noise.get_noise_2d(p.x, p.z) * minf(1.0, base * 0.15 + 0.15)
		verts[i] = p
	arrays[Mesh.ARRAY_VERTEX] = verts

	var surface := SurfaceTool.new()
	surface.create_from_arrays(arrays, Mesh.PRIMITIVE_TRIANGLES)
	surface.generate_normals()
	var mesh: ArrayMesh = surface.commit()

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.30, 0.48, 0.26)
	material.roughness = 0.95

	var visual := MeshInstance3D.new()
	visual.name = "GroundMesh"
	visual.mesh = mesh
	visual.material_override = material
	add_child(visual)

	var body := StaticBody3D.new()
	body.name = "GroundBody"
	var shape := CollisionShape3D.new()
	shape.shape = mesh.create_trimesh_shape()
	body.add_child(shape)
	add_child(body)
