class_name OwlItem
extends Node3D

## 下落中的一样东西：糖（粉球 + 黄糖纸）或者屎（棕球 + 顶尖）。
## 两个造型都常驻，只切 visible——不每颗重建 mesh。
## 位置由外部按模型进度喂：place(起点, 终点, 0..1)。

const CANDY_COLOR := Color(0.96, 0.45, 0.62)
const WRAPPER_COLOR := Color(0.98, 0.84, 0.35)
const POOP_COLOR := Color(0.42, 0.28, 0.16)
const RADIUS := 0.19

var _candy: Node3D
var _poop: Node3D
var _poop_kind := false


func setup() -> void:
	var body := SphereMesh.new()
	body.radius = RADIUS
	body.height = RADIUS * 2.0
	body.radial_segments = 12
	body.rings = 6
	var candy_mat := _solid(CANDY_COLOR)

	_candy = Node3D.new()
	_candy.name = "Candy"
	add_child(_candy)
	_attach(_candy, "Body", body, Vector3.ZERO, candy_mat)

	var wrapper := CylinderMesh.new()
	wrapper.top_radius = 0.10
	wrapper.bottom_radius = 0.10
	wrapper.height = 0.09
	wrapper.radial_segments = 8
	var wrapper_mat := _solid(WRAPPER_COLOR)
	for side in [-1.0, 1.0]:
		var knot := _attach(_candy, "Wrapper", wrapper, Vector3(RADIUS * 0.92 * side, 0.0, 0.0), wrapper_mat)
		knot.rotation_degrees = Vector3(0.0, 0.0, 90.0)

	_poop = Node3D.new()
	_poop.name = "Poop"
	_poop.visible = false
	add_child(_poop)
	var poop_mesh := SphereMesh.new()
	poop_mesh.radius = RADIUS
	poop_mesh.height = RADIUS * 2.0
	poop_mesh.radial_segments = 12
	poop_mesh.rings = 6
	var poop_body := _attach(_poop, "Body", poop_mesh, Vector3.ZERO, _solid(POOP_COLOR))
	poop_body.scale = Vector3(1.0, 0.85, 1.0)

	var tip := CylinderMesh.new()
	tip.top_radius = 0.0
	tip.bottom_radius = 0.09
	tip.height = 0.16
	tip.radial_segments = 8
	_attach(_poop, "Tip", tip, Vector3(0.0, RADIUS * 0.8, 0.0), _solid(POOP_COLOR))


func set_kind(poop: bool) -> void:
	if poop == _poop_kind:
		return
	_poop_kind = poop
	_candy.visible = not poop
	_poop.visible = poop


func place(from: Vector3, to: Vector3, progress: float) -> void:
	position = from.lerp(to, clampf(progress, 0.0, 1.0))


func _attach(parent: Node3D, node_name: String, mesh: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = pos
	node.material_override = mat
	parent.add_child(node)
	return node


func _solid(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	return mat
