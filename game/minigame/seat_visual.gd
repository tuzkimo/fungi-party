class_name SeatVisual
extends Node3D

## 一个座位：课桌 + 蘑菇 + 头顶进度条 + 「!」标记。
## 只读 StealEat.Seat 的字段，不改规则。

const TINTS := [
	Color(0.90, 0.22, 0.20), Color(0.35, 0.78, 0.80), Color(0.95, 0.80, 0.30), Color(0.65, 0.45, 0.85)
]
const BODY_SCALE := 0.9
const BAR_Y := 2.1
const BAR_WIDTH := 1.0
const BAR_HEIGHT := 0.14
const MARK_Y := 2.4

var index := 0

var _body: MushroomMesh
var _fill: MeshInstance3D
var _fill_mesh: QuadMesh
var _mark: MeshInstance3D
var _bounce := 0.0


func setup(index_value: int) -> void:
	index = index_value
	position = Config.SEAT_POSITIONS[index]
	_build_desk()
	_build_body()
	_build_bar()
	_build_mark()


func apply(seat: StealEat.Seat, eating: bool, delta: float, watched := false) -> void:
	_mark.visible = watched or seat.stun > 0.0 or seat.out

	# billboard 会丢掉节点的非等比缩放，所以改 mesh 宽度而不是 scale.x
	var progress := clampf(float(seat.bites) / float(Config.BITES_TO_WIN), 0.0, 1.0)
	_fill_mesh.size.x = maxf(progress * BAR_WIDTH, 0.001)
	_fill.position.x = -0.5 * BAR_WIDTH * (1.0 - progress)

	if eating:
		_bounce += delta * 12.0
		var squash := sin(_bounce) * 0.12
		_body.scale = Vector3(
			BODY_SCALE * (1.0 - squash * 0.5), BODY_SCALE * (1.0 + squash * 0.5), BODY_SCALE * (1.0 - squash * 0.5)
		)
	else:
		_bounce = 0.0
		_body.scale = _body.scale.lerp(Vector3.ONE * BODY_SCALE, minf(1.0, 10.0 * delta))


func _build_desk() -> void:
	var wood := _solid(Color(0.55, 0.36, 0.22))
	_box("DeskTop", Vector3(1.7, 0.08, 0.85), Vector3(0.0, 0.78, -0.55), wood)
	_box("DeskBody", Vector3(1.4, 0.75, 0.7), Vector3(0.0, 0.4, -0.55), wood)


func _build_body() -> void:
	_body = MushroomMesh.new()
	_body.name = "SeatBody"
	_body.tint_cap = TINTS[index % TINTS.size()]
	_body.scale = Vector3.ONE * BODY_SCALE
	add_child(_body)


func _build_bar() -> void:
	var back := QuadMesh.new()
	back.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	_box_mesh("BarBack", back, Vector3(0.0, BAR_Y, 0.0), _billboard(Color(0.12, 0.12, 0.12)))

	var fill := QuadMesh.new()
	fill.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	_fill_mesh = fill
	_fill = _box_mesh("BarFill", fill, Vector3(0.0, BAR_Y, 0.02), _billboard(Color(0.45, 0.90, 0.40)))


func _build_mark() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(0.28, 0.42)
	var material := _billboard(Color(0.95, 0.15, 0.15))
	material.no_depth_test = true
	_mark = _box_mesh("Mark", quad, Vector3(0.0, MARK_Y, 0.0), material)
	_mark.visible = false


func _box(node_name: String, size: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _box_mesh(node_name, mesh, pos, material)


func _box_mesh(node_name: String, mesh: Mesh, pos: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = pos
	node.material_override = material
	add_child(node)
	return node


func _solid(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	return material


func _billboard(color: Color) -> StandardMaterial3D:
	var material := _solid(color)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	return material
