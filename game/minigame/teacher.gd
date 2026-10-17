class_name Teacher
extends Node3D

## 老师：一朵放大 1.5 倍的蘑菇 + 地面扇形视线锥。
## 只读 Gaze 的 phase/target/alpha，转头在预警那 0.3 秒内转到位。

const YAW_SPEED := 12.0
const BODY_SCALE := 1.5
const WARN_COLOR := Color(1.0, 0.85, 0.3)
const WATCH_COLOR := Color(1.0, 0.25, 0.2)

var _cone_material: StandardMaterial3D
var _cone: MeshInstance3D


func _ready() -> void:
	var body := MushroomMesh.new()
	body.name = "TeacherBody"
	body.tint_cap = Color(0.34, 0.32, 0.36)
	body.tint_body = Color(0.58, 0.55, 0.52)
	body.scale = Vector3.ONE * BODY_SCALE
	add_child(body)
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
