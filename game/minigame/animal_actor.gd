class_name AnimalActor
extends Node3D

## 横穿赛道的小动物：先出一秒地面影子（从它要进场的那一侧），再本体进场。
## 本体是 AnimatableBody3D + hazard 组，玩家和它发生的是真实物理碰撞。

const BEETLE_COLOR := Color(0.42, 0.24, 0.18)
const DUNG_COLOR := Color(0.24, 0.20, 0.17)
const DUNG_BALL_COLOR := Color(0.46, 0.32, 0.18)
const SQUIRREL_COLOR := Color(0.72, 0.44, 0.24)
const BELLY_COLOR := Color(0.90, 0.80, 0.66)
const SHADOW_COLOR := Color(0.05, 0.05, 0.06, 0.45)
const SHADOW_EDGE := 0.7
const BLOCK_SIZE := Vector3(1.3, 1.7, 1.2)
const OFF_STAGE_X := 100.0

var _kind := RaceField.BEETLE
var _side := 1
var _shadow: MeshInstance3D
var _body: AnimatableBody3D


func setup(kind: int, side: int, z: float) -> void:
	_kind = kind
	_side = side
	position = Vector3(0.0, 0.0, z)

	_shadow = MeshInstance3D.new()
	_shadow.name = "Shadow"
	var quad := QuadMesh.new()
	quad.size = Vector2(1.5, 1.2)
	_shadow.mesh = quad
	var shadow_mat := StandardMaterial3D.new()
	shadow_mat.albedo_color = SHADOW_COLOR
	shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_shadow.material_override = shadow_mat
	_shadow.rotation_degrees.x = -90.0
	_shadow.position.y = 0.02
	add_child(_shadow)

	_body = AnimatableBody3D.new()
	_body.name = "Body"
	_body.add_to_group("hazard")
	# 停在赛道外：visible=false 不会关碰撞，留在原点就是一道看不见的墙
	_body.position.x = OFF_STAGE_X
	add_child(_body)

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = BLOCK_SIZE
	shape.shape = box
	shape.position.y = BLOCK_SIZE.y * 0.5
	_body.add_child(shape)

	match _kind:
		RaceField.DUNG:
			_build_dung()
		RaceField.SQUIRREL:
			_build_squirrel()
		_:
			_build_beetle()


## elapsed 从影子出现算起；影子阶段只画影子，本体进场后才跟着走。
func advance(elapsed: float) -> void:
	var warn := Config.RACE_ANIMAL_WARN
	visible = elapsed >= 0.0
	_shadow.visible = elapsed >= 0.0 and elapsed < warn
	_body.visible = elapsed >= warn
	if elapsed < 0.0:
		return
	if elapsed < warn:
		# 影子停在赛道内侧边上，从哪边出现就说明它从哪边来
		var edge := Config.RACE_TRACK_HALF_WIDTH - SHADOW_EDGE
		_shadow.position.x = edge * _side
	else:
		_body.position.x = RaceField.animal_x(_side, elapsed - warn)


func _build_beetle() -> void:
	var shell := _part(_sphere(12, 8), BEETLE_COLOR, Vector3(0.0, 0.55, 0.0), Vector3(0.62, 0.42, 0.5))
	shell.name = "Shell"
	_part(_sphere(8, 6), BELLY_COLOR, Vector3(0.0, 0.72, 0.0), Vector3(0.3, 0.16, 0.24))
	for side in [-1.0, 1.0]:
		var antenna := _part(_cylinder(0.05, 0.7, 6), BEETLE_COLOR, Vector3(0.18 * side, 1.15, -0.1), Vector3.ONE)
		antenna.rotation_degrees.z = 18.0 * side
		for leg in [-1.0, 1.0]:
			_part(_box(Vector3(0.12, 0.4, 0.12)), BEETLE_COLOR, Vector3(0.5 * side, 0.2, 0.28 * leg), Vector3.ONE)


func _build_dung() -> void:
	_part(_sphere(12, 8), DUNG_BALL_COLOR, Vector3(-0.55 * _side, 0.55, 0.0), Vector3(0.55, 0.55, 0.55))
	_part(_sphere(10, 6), DUNG_COLOR, Vector3(0.25 * _side, 0.35, 0.0), Vector3(0.35, 0.3, 0.32))
	for side in [-1.0, 1.0]:
		_part(_box(Vector3(0.1, 0.3, 0.1)), DUNG_COLOR, Vector3(0.3 * _side, 0.15, 0.2 * side), Vector3.ONE)


func _build_squirrel() -> void:
	_part(_capsule(0.3, 0.9, 10, 6), SQUIRREL_COLOR, Vector3(0.0, 0.6, 0.0), Vector3.ONE)
	_part(_sphere(10, 6), SQUIRREL_COLOR, Vector3(0.0, 1.05, 0.0), Vector3(0.26, 0.26, 0.26))
	_part(_sphere(10, 8), SQUIRREL_COLOR, Vector3(0.45 * _side, 1.0, 0.0), Vector3(0.22, 0.4, 0.22))
	_part(_sphere(8, 6), BELLY_COLOR, Vector3(0.0, 0.6, -0.22), Vector3(0.18, 0.3, 0.1))
	_part(_box(Vector3(0.06, 0.06, 0.06)), Color(0.12, 0.10, 0.10), Vector3(0.16, 1.2, -0.16), Vector3.ONE)
	_part(_box(Vector3(0.06, 0.06, 0.06)), Color(0.12, 0.10, 0.10), Vector3(-0.16, 1.2, -0.16), Vector3.ONE)


func _part(mesh: Mesh, color: Color, pos: Vector3, scl: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	node.material_override = material
	node.position = pos
	node.scale = scl
	_body.add_child(node)
	return node


func _sphere(radial: int, rings: int) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = radial
	mesh.rings = rings
	return mesh


func _cylinder(radius: float, height: float, segments: int) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 1
	return mesh


func _capsule(radius: float, height: float, segments: int, rings: int) -> CapsuleMesh:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = rings
	return mesh


func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh
