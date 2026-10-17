class_name MushroomMesh
extends Node3D

## 程序化生成蘑菇角色的全部外观。所有尺寸按「脚底 y=0」排布。
## 外观只在这里改；角色逻辑不引用这里的任何节点。

@export var cap_radius := 0.9
@export var cap_height := 0.55
@export var spot_count := 7
@export var body_height := 1.4
@export var tint_cap := Color(0.90, 0.22, 0.20)
@export var tint_body := Color(0.96, 0.78, 0.62)

const OUTLINE_GROW := 0.018


func _ready() -> void:
	build()


func build() -> void:
	for child in get_children():
		remove_child(child)
		child.free()

	var mat_cap := _solid(tint_cap)
	var mat_body := _solid(tint_body)
	var mat_white := _solid(Color(0.99, 0.97, 0.94))
	var mat_dark := _solid(Color(0.10, 0.07, 0.07))
	var mat_outline := _outline()

	var body_y := body_height * 0.5
	var cap_y := body_height - 0.05

	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.45
	body_mesh.height = body_height
	body_mesh.radial_segments = 16
	body_mesh.rings = 8
	_add_part("Body", body_mesh, mat_body, Vector3(0.0, body_y, 0.0), Vector3.ONE)

	var cap_mesh := SphereMesh.new()
	cap_mesh.radius = cap_radius
	cap_mesh.height = cap_radius * 2.0
	cap_mesh.radial_segments = 32
	cap_mesh.rings = 16
	var cap_scale := Vector3(1.0, cap_height / cap_radius, 1.0)
	_add_part("Cap", cap_mesh, mat_cap, Vector3(0.0, cap_y, 0.0), cap_scale)
	_add_part("CapOutline", cap_mesh, mat_outline, Vector3(0.0, cap_y, 0.0), cap_scale)
	_add_part("BodyOutline", body_mesh, mat_outline, Vector3(0.0, body_y, 0.0), Vector3.ONE)

	var hand_mesh := SphereMesh.new()
	hand_mesh.radius = 1.0
	hand_mesh.height = 2.0
	hand_mesh.radial_segments = 12
	hand_mesh.rings = 6
	for side in [-1.0, 1.0]:
		var hand_pos := Vector3(0.56 * side, 0.62, 0.02)
		var hand_scale := Vector3(0.30, 0.13, 0.42)
		var label := "HandL" if side < 0.0 else "HandR"
		_add_part(label, hand_mesh, mat_body, hand_pos, hand_scale)
		_add_part(label + "Outline", hand_mesh, mat_outline, hand_pos, hand_scale)

	var spot_mesh := SphereMesh.new()
	spot_mesh.radius = 1.0
	spot_mesh.height = 2.0
	spot_mesh.radial_segments = 12
	spot_mesh.rings = 6
	for i in spot_count:
		var angle := TAU * float(i) / float(spot_count) + 0.4
		var spread := 0.22 + 0.6 * float((i * 37) % 100) / 100.0
		var ring := cap_radius * sin(acos(spread)) * 0.92
		var spot_pos := Vector3(
			cos(angle) * ring,
			cap_y + cap_height * spread * 0.98,
			sin(angle) * ring,
		)
		var spot_scale := Vector3.ONE * (0.10 + 0.03 * float(i % 3))
		spot_scale.y *= 0.45
		_add_part("Spot%d" % i, spot_mesh, mat_white, spot_pos, spot_scale)

	var dot_mesh := SphereMesh.new()
	dot_mesh.radius = 1.0
	dot_mesh.height = 2.0
	dot_mesh.radial_segments = 12
	dot_mesh.rings = 6
	for side in [-1.0, 1.0]:
		_add_part(
			"EyeL" if side < 0.0 else "EyeR",
			dot_mesh,
			mat_dark,
			Vector3(0.14 * side, cap_y - 0.10, 0.855),
			Vector3(0.055, 0.055, 0.03),
		)
	_add_part("Mouth", dot_mesh, mat_dark, Vector3(0.0, cap_y - 0.30, 0.78), Vector3(0.13, 0.022, 0.02))

	_add_part("Belly", dot_mesh, mat_white, Vector3(0.0, 0.62, 0.41), Vector3(0.16, 0.24, 0.06))

	var mark_mesh := BoxMesh.new()
	mark_mesh.size = Vector3(0.14, 0.022, 0.022)
	for side in [-1.0, 1.0]:
		var mark := _add_part("BellyCross", mark_mesh, mat_dark, Vector3(0.0, 0.30, 0.44), Vector3.ONE)
		mark.rotation_degrees.z = 45.0 * side


func _add_part(part_name: String, mesh: Mesh, material: Material, pos: Vector3, scl: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = part_name
	node.mesh = mesh
	node.material_override = material
	node.position = pos
	node.scale = scl
	add_child(node)
	return node


func _solid(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	return mat


func _outline() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.09, 0.06, 0.06)
	mat.cull_mode = BaseMaterial3D.CULL_FRONT
	mat.grow = true
	mat.grow_amount = OUTLINE_GROW
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat
