class_name OwlActor
extends Node3D

## 座位上的一个蘑菇：会开合的嘴、张嘴时头后仰、吃到糖弹一下、出局后低头变灰。
## 只管画，状态由外部每帧喂（mouths[i] 的 score / open / out）。

const STEM_COLOR := Color(0.92, 0.87, 0.78)
const MOUTH_CLOSED_COLOR := Color(0.25, 0.15, 0.15)
const MOUTH_OPEN_COLOR := Color(0.95, 0.52, 0.58)
const DOT_COLOR := Color(0.98, 0.96, 0.90)
## 脸都贴在菌盖前面：出局时整只蘑菇前倾，五官再往里缩就会被菌盖吞掉
const MOUTH_POINT := Vector3(0.0, 0.55, 0.66)
const LEAN_OPEN := -0.16
const LEAN_OUT := 0.30
const LEAN_SPEED := 12.0
const POP_SECONDS := 0.18
const POP_SCALE := 0.18
const OUT_FADE := 0.45

var _cap_mat: StandardMaterial3D
var _cap_color := Color.WHITE
var _closed_mesh: MeshInstance3D
var _open_mesh: MeshInstance3D
var _out := false
var _score := -1
var _pop := 0.0


func setup(cap_color: Color, is_player: bool) -> void:
	_cap_color = cap_color

	var stem_mesh := CylinderMesh.new()
	stem_mesh.top_radius = 0.26
	stem_mesh.bottom_radius = 0.32
	stem_mesh.height = 0.55
	stem_mesh.radial_segments = 12
	var stem := _solid(STEM_COLOR, 0.9)
	_place("Stem", stem_mesh, Vector3(0.0, 0.275, 0.0), stem)

	var cap_mesh := SphereMesh.new()
	cap_mesh.radius = 1.0
	cap_mesh.height = 2.0
	cap_mesh.radial_segments = 14
	cap_mesh.rings = 7
	_cap_mat = _solid(cap_color, 0.85)
	var cap := _place("Cap", cap_mesh, Vector3(0.0, 0.72, 0.0), _cap_mat)
	cap.scale = Vector3(0.66, 0.42, 0.66)

	var dot_mesh := SphereMesh.new()
	dot_mesh.radius = 0.09
	dot_mesh.height = 0.18
	dot_mesh.radial_segments = 8
	dot_mesh.rings = 4
	var dot := _solid(DOT_COLOR, 0.8)
	_place("Dot0", dot_mesh, Vector3(-0.24, 0.92, 0.22), dot)
	_place("Dot1", dot_mesh, Vector3(0.26, 0.95, 0.10), dot)
	_place("Dot2", dot_mesh, Vector3(0.02, 0.88, -0.26), dot)

	var eye_mesh := SphereMesh.new()
	eye_mesh.radius = 0.10
	eye_mesh.height = 0.20
	eye_mesh.radial_segments = 8
	eye_mesh.rings = 4
	var pupil_mesh := SphereMesh.new()
	pupil_mesh.radius = 0.05
	pupil_mesh.height = 0.10
	pupil_mesh.radial_segments = 8
	pupil_mesh.rings = 4
	var white := _solid(Color.WHITE, 0.6)
	var black := _solid(Color(0.08, 0.06, 0.06), 0.5)
	for side in [-1.0, 1.0]:
		_place("Eye", eye_mesh, Vector3(0.17 * side, 0.62, 0.60), white)
		_place("Pupil", pupil_mesh, Vector3(0.17 * side, 0.62, 0.67), black)

	# 嘴：闭嘴是一条缝，张嘴是露出来的粉色口腔。两张都常驻，切 visible，
	# 手机小屏上「自己现在张没张嘴」必须一眼看得出。
	var closed_mesh := BoxMesh.new()
	closed_mesh.size = Vector3(0.44, 0.10, 0.10)
	_closed_mesh = _place("MouthClosed", closed_mesh, Vector3(0.0, 0.55, 0.60), _solid(MOUTH_CLOSED_COLOR, 0.9))

	var open_mesh := SphereMesh.new()
	open_mesh.radius = 1.0
	open_mesh.height = 2.0
	open_mesh.radial_segments = 10
	open_mesh.rings = 5
	_open_mesh = _place("MouthOpen", open_mesh, Vector3(0.0, 0.55, 0.62), _solid(MOUTH_OPEN_COLOR, 0.8))
	_open_mesh.scale = Vector3(0.23, 0.20, 0.13)
	_open_mesh.visible = false

	if is_player:
		# 玩家那一朵多一圈地面光圈，四个人里一眼找到自己
		var ring_mesh := CylinderMesh.new()
		ring_mesh.top_radius = 0.52
		ring_mesh.bottom_radius = 0.52
		ring_mesh.height = 0.02
		ring_mesh.radial_segments = 20
		_place("Ring", ring_mesh, Vector3(0.0, 0.011, 0.0), _solid(Color(0.98, 0.92, 0.55), 0.7))


func apply(score: int, open: bool, out: bool, delta: float) -> void:
	if _score >= 0 and score > _score:
		_pop = POP_SECONDS
	_score = score

	_open_mesh.visible = open and not out
	_closed_mesh.visible = not _open_mesh.visible

	if out != _out:
		_out = out
		_cap_mat.albedo_color = _cap_color.darkened(OUT_FADE) if out else _cap_color

	var target := LEAN_OUT if out else (LEAN_OPEN if open else 0.0)
	rotation.x = lerpf(rotation.x, target, minf(1.0, delta * LEAN_SPEED))
	_pop = maxf(0.0, _pop - delta)
	scale = Vector3.ONE * (1.0 + POP_SCALE * _pop / POP_SECONDS)


func mouth_point() -> Vector3:
	return to_global(MOUTH_POINT)


func _place(node_name: String, mesh: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = pos
	node.material_override = mat
	add_child(node)
	return node


func _solid(color: Color, roughness: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	return mat
