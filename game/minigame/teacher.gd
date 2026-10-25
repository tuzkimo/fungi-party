class_name Teacher
extends Node3D

## 老师：一只站在讲台墩子上的猫头鹰 + 地面扇形视线锥。
## 只读 Gaze 的 phase/target/alpha，转头在预警那 0.3 秒内转到位。

const YAW_SPEED := 12.0
## 猫头鹰本体只有 0.62 高，放大到比坐着的学生高一点才像个老师
const OWL_SCALE := 2.2
const PERCH_SIZE := Vector3(1.1, 0.45, 1.1)
const FEATHER_COLOR := Color(0.34, 0.32, 0.36)
const PERCH_COLOR := Color(0.45, 0.31, 0.19)
const WARN_COLOR := Color(1.0, 0.85, 0.3)
const WATCH_COLOR := Color(1.0, 0.25, 0.2)

var _cone_material: StandardMaterial3D
var _cone: MeshInstance3D


func _ready() -> void:
	var perch := MeshInstance3D.new()
	perch.name = "Perch"
	var block := BoxMesh.new()
	block.size = PERCH_SIZE
	perch.mesh = block
	var wood := StandardMaterial3D.new()
	wood.albedo_color = PERCH_COLOR
	wood.roughness = 0.95
	perch.material_override = wood
	perch.position.y = PERCH_SIZE.y * 0.5
	add_child(perch)

	var owl := OwlModel.new()
	owl.name = "TeacherOwl"
	owl.body_color = FEATHER_COLOR
	owl.belly_color = FEATHER_COLOR.lightened(0.22)
	owl.scale = Vector3.ONE * OWL_SCALE
	owl.position.y = PERCH_SIZE.y - owl.bottom() * OWL_SCALE
	add_child(owl)
	owl.build()
	_build_cone()


func apply(gaze: Gaze, delta: float) -> void:
	var goal := Gaze.yaw_to(global_position, Config.SEAT_POSITIONS[gaze.target])
	rotation.y = lerp_angle(rotation.y, goal, minf(1.0, YAW_SPEED * delta))

	var alpha := gaze.alpha()
	_cone.visible = alpha > 0.0
	var color := WARN_COLOR if gaze.phase == Gaze.Phase.WARN else WATCH_COLOR
	color.a = alpha
	_cone_material.albedo_color = color


func _build_cone() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := deg_to_rad(Config.GAZE_HALF_ANGLE)
	var segments := 12
	for i in segments:
		var a0 := -half + 2.0 * half * float(i) / float(segments)
		var a1 := -half + 2.0 * half * float(i + 1) / float(segments)
		surface.add_vertex(Vector3.ZERO)
		surface.add_vertex(Vector3(sin(a0), 0.0, cos(a0)) * Config.GAZE_RANGE)
		surface.add_vertex(Vector3(sin(a1), 0.0, cos(a1)) * Config.GAZE_RANGE)
	surface.generate_normals()

	_cone_material = StandardMaterial3D.new()
	_cone_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_cone_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_cone_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cone_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED

	_cone = MeshInstance3D.new()
	_cone.visible = false
	_cone.name = "GazeCone"
	_cone.mesh = surface.commit()
	_cone.material_override = _cone_material
	_cone.position.y = 0.02
	_cone_material.albedo_color = Color(1.0, 1.0, 1.0, 0.0)
	add_child(_cone)
