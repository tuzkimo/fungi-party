class_name OwlModel
extends Node3D

## 一只蹲着的猫头鹰：身体 + 两只大眼睛 + 喙 + 耳羽 + 翅膀 + 两只小脚。
## 喂食小游戏里树杈上那只和教室里的老师共用；老师只是放大一号、换身羽毛。
## 原点在身体中心，脚底在 bottom()，摆到地面上自己加这个偏移。

const BODY_RADIUS := 0.34
const BODY_HEIGHT := 0.62
const FEET_BELOW := 0.08
const EYE_WHITE := Color.WHITE
const EYE_BLACK := Color(0.08, 0.06, 0.06)
const CLAW_COLOR := Color(0.96, 0.62, 0.22)

## 羽毛和喙的颜色。老师是深灰的（要有点吓人），树上那只是暖棕色。
var body_color := Color(0.55, 0.47, 0.40)
var beak_color := Color(0.96, 0.62, 0.22)
## 肚皮比羽毛亮一点，不然整只鸟一团糊
var belly_color := Color(0.72, 0.65, 0.56)


## 脚底离原点多远：要站在地上就 position.y = -bottom() * scale.y
func bottom() -> float:
	return -BODY_HEIGHT * 0.5 - FEET_BELOW


func build() -> void:
	var body := _sphere(14, 7)
	_attach("Body", body, Vector3.ZERO, _solid(body_color, 0.9), Vector3(BODY_RADIUS, BODY_HEIGHT * 0.5, BODY_RADIUS))
	# 肚皮：正面偏下的浅色块，让身子有前后
	_attach(
		"Belly", _sphere(12, 6), Vector3(0.0, -0.06, 0.18),
		_solid(belly_color, 0.95), Vector3(0.24, 0.24, 0.12),
	)

	# 翅膀：两片压在身侧的扁球
	for side in [-1.0, 1.0]:
		var wing := _attach(
			"Wing", _sphere(10, 6), Vector3(0.30 * side, -0.02, 0.0),
			_solid(body_color.darkened(0.12), 0.95), Vector3(0.10, 0.26, 0.20),
		)
		wing.rotation_degrees.z = -10.0 * side

	var eye := _sphere(10, 5)
	var pupil := _sphere(8, 4)
	for side in [-1.0, 1.0]:
		_attach("Eye", eye, Vector3(0.15 * side, 0.10, 0.27), _solid(EYE_WHITE, 0.6), Vector3.ONE * 0.13)
		_attach("Pupil", pupil, Vector3(0.15 * side, 0.10, 0.36), _solid(EYE_BLACK, 0.5), Vector3.ONE * 0.07)

	var beak := CylinderMesh.new()
	beak.top_radius = 0.0
	beak.bottom_radius = 0.07
	beak.height = 0.16
	beak.radial_segments = 8
	var beak_node := _attach("Beak", beak, Vector3(0.0, -0.02, 0.34), _solid(beak_color, 0.7), Vector3.ONE)
	beak_node.rotation_degrees = Vector3(90.0, 0.0, 0.0)

	# 耳羽：两根斜着的小尖锥，猫头鹰一眼认出来靠它
	for side in [-1.0, 1.0]:
		var ear := _attach("Ear", beak, Vector3(0.19 * side, 0.30, 0.02), _solid(body_color, 0.9), Vector3.ONE)
		ear.rotation_degrees = Vector3(0.0, 0.0, -22.0 * side)

	# 小脚：两只橙色爪子，站在地上/枝上时看得见
	for side in [-1.0, 1.0]:
		_attach(
			"Foot", _sphere(8, 4), Vector3(0.11 * side, -BODY_HEIGHT * 0.5 - 0.03, 0.08),
			_solid(CLAW_COLOR, 0.8), Vector3(0.09, 0.05, 0.12),
		)


func _attach(
	node_name: String, mesh: Mesh, pos: Vector3, mat: Material, scl: Vector3
) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = pos
	node.scale = scl
	node.material_override = mat
	add_child(node)
	return node


func _sphere(radial: int, rings: int) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = radial
	mesh.rings = rings
	return mesh


func _solid(color: Color, roughness: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	return mat
