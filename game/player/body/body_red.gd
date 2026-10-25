class_name BodyRed
extends MushroomBody

## 红蘑菇：一只胶囊身体、两只扁手、白肚皮和一个十字印。
## 数值就是拆分前 mushroom_mesh.gd 里那套，一个都没动。

const BODY_RADIUS := 0.45
const BELLY := Vector3(0.16, 0.24, 0.06)
const BELLY_POS := Vector3(0.0, 0.62, 0.41)
const CROSS_SIZE := Vector3(0.14, 0.022, 0.022)
const CROSS_POS := Vector3(0.0, 0.30, 0.44)
const HAND_POS := Vector3(0.56, 0.62, 0.02)
const HAND_SCALE := Vector3(0.30, 0.13, 0.42)


func apply_defaults(to: MushroomMesh) -> void:
	to.body_height = 1.40
	to.cap_radius = 0.70
	to.cap_height = 0.46
	to.cap_sharpness = 1.45


func _build_body(_pivot: Node3D) -> void:
	var mat_body := _solid(host.tint_body)
	var outline := _outline()

	var body_y := host.body_height * 0.5
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = BODY_RADIUS
	body_mesh.height = host.body_height
	body_mesh.radial_segments = 16
	body_mesh.rings = 8
	_add_part("Body", body_mesh, mat_body, Vector3(0.0, body_y, 0.0), Vector3.ONE)
	_add_part("BodyOutline", body_mesh, outline, Vector3(0.0, body_y, 0.0), Vector3.ONE)

	var hand_mesh := _sphere(12, 6)
	for side in [-1.0, 1.0]:
		var hand_pos := Vector3(HAND_POS.x * side, HAND_POS.y, HAND_POS.z)
		var label := "HandL" if side < 0.0 else "HandR"
		_add_part(label, hand_mesh, mat_body, hand_pos, HAND_SCALE)
		_add_part(label + "Outline", hand_mesh, outline, hand_pos, HAND_SCALE)

	var mat_white := _solid(Color(0.99, 0.97, 0.94))
	var mat_dark := _solid(Color(0.10, 0.07, 0.07))
	var dot := _sphere(12, 6)
	_add_part("Belly", dot, mat_white, BELLY_POS, BELLY)

	var mark_mesh := BoxMesh.new()
	mark_mesh.size = CROSS_SIZE
	for side in [-1.0, 1.0]:
		var mark := _add_part("BellyCross", mark_mesh, mat_dark, CROSS_POS, Vector3.ONE)
		mark.rotation_degrees.z = 45.0 * side
