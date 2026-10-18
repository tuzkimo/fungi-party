class_name BombVisual
extends Node3D

## 炸弹本体：黑球 + 引信 + 三档火花。只管画，位置由外部每帧喂。
## 三档在三个独立维度上同时变（火花颜色 / 脉动速度 / 点光亮度），手机小屏也分得开。

const BODY_RADIUS := 0.40
const HOLD_HEIGHT := 0.45
const ARC_HEIGHT := 1.2
const SPARK_COLORS := [
	Color(1.0, 0.55, 0.16),
	Color(1.0, 0.93, 0.62),
	Color(1.0, 1.0, 1.0),
]
const SPARK_ENERGY := [1.3, 2.0, 3.2]
const LIGHT_ENERGY := [0.7, 1.5, 2.6]
const FUSE_TILT := Vector3(12.0, 0.0, 18.0)

var _body_mat: StandardMaterial3D
var _spark_mat: StandardMaterial3D
var _sparks: Array[MeshInstance3D] = []
var _light: OmniLight3D
var _danger := 0.0
var _tier := 0
var _phase := 0.0
var _flying := false
var _flight_t := 0.0
var _flight_seconds := 0.0
var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _ctrl := Vector3.ZERO


func setup() -> void:
	var ball := SphereMesh.new()
	ball.radius = BODY_RADIUS
	ball.height = BODY_RADIUS * 2.0
	ball.radial_segments = 16
	ball.rings = 8
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = ball
	_body_mat = StandardMaterial3D.new()
	_body_mat.albedo_color = Color(0.09, 0.08, 0.09)
	_body_mat.roughness = 0.45
	_body_mat.emission_enabled = true
	_body_mat.emission = Color(1.0, 0.22, 0.08)
	_body_mat.emission_energy_multiplier = 0.0
	body.material_override = _body_mat
	add_child(body)

	var fuse_mesh := CylinderMesh.new()
	fuse_mesh.top_radius = 0.035
	fuse_mesh.bottom_radius = 0.05
	fuse_mesh.height = 0.36
	fuse_mesh.radial_segments = 8
	var fuse := MeshInstance3D.new()
	fuse.name = "Fuse"
	fuse.mesh = fuse_mesh
	var fuse_mat := StandardMaterial3D.new()
	fuse_mat.albedo_color = Color(0.28, 0.22, 0.16)
	fuse_mat.roughness = 0.95
	fuse.material_override = fuse_mat
	fuse.position = Vector3(0.0, BODY_RADIUS + 0.16, 0.0)
	fuse.rotation_degrees = FUSE_TILT
	add_child(fuse)

	var spark_mesh := SphereMesh.new()
	spark_mesh.radius = 1.0
	spark_mesh.height = 2.0
	spark_mesh.radial_segments = 12
	spark_mesh.rings = 6
	_spark_mat = StandardMaterial3D.new()
	_spark_mat.albedo_color = SPARK_COLORS[0]
	_spark_mat.emission_enabled = true
	_spark_mat.emission = SPARK_COLORS[0]
	_spark_mat.emission_energy_multiplier = SPARK_ENERGY[0]
	_spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for i in 4:
		var spark := MeshInstance3D.new()
		spark.name = "Spark%d" % i
		spark.mesh = spark_mesh
		spark.material_override = _spark_mat
		spark.position = Vector3(0.10, BODY_RADIUS + 0.34, 0.04) + Vector3(
			cos(TAU * float(i) / 4.0) * 0.06, 0.04 * float(i), sin(TAU * float(i) / 4.0) * 0.06
		)
		spark.scale = Vector3.ONE * 0.09
		add_child(spark)
		_sparks.append(spark)

	_light = OmniLight3D.new()
	_light.name = "SparkLight"
	_light.light_color = SPARK_COLORS[0]
	_light.light_energy = LIGHT_ENERGY[0]
	_light.omni_range = 3.0
	_light.position = Vector3(0.0, BODY_RADIUS + 0.34, 0.0)
	add_child(_light)


## 贴在持有人头顶；每帧调用。
func hold(pos: Vector3) -> void:
	_flying = false
	visible = true
	position = pos + Vector3(0.0, HOLD_HEIGHT, 0.0)


func start_flight(from: Vector3, to: Vector3, seconds: float) -> void:
	visible = true
	_flying = true
	_from = from
	_to = to
	_ctrl = (from + to) * 0.5 + Vector3(0.0, ARC_HEIGHT, 0.0)
	_flight_seconds = maxf(seconds, 0.01)
	_flight_t = 0.0
	position = from


## 返回 true 表示飞行刚在这一帧结束。
func advance(delta: float) -> bool:
	if not _flying:
		return false
	_flight_t += delta
	var k := clampf(_flight_t / _flight_seconds, 0.0, 1.0)
	position = _bezier(k)
	rotation.y += delta * 12.0
	if k < 1.0:
		return false
	_flying = false
	return true


## tier 0/1/2 驱动火花颜色、脉动速度、点光亮度；danger 越高整颗球越红。
func set_danger(danger: float, tier: int) -> void:
	_danger = clampf(danger, 0.0, 1.0)
	_tier = clampi(tier, 0, 2)
	var color: Color = SPARK_COLORS[_tier]
	_spark_mat.albedo_color = color
	_spark_mat.emission = color
	_spark_mat.emission_energy_multiplier = float(SPARK_ENERGY[_tier]) * (0.75 + 0.25 * _danger)
	_light.light_color = color
	_light.light_energy = float(LIGHT_ENERGY[_tier]) * (0.6 + 0.4 * _danger)
	_body_mat.emission_energy_multiplier = _danger * 0.9


func hide_bomb() -> void:
	visible = false
	_flying = false


func _process(delta: float) -> void:
	if not visible:
		return
	_phase += delta * (5.0 + 7.0 * float(_tier)) * (0.7 + 0.6 * _danger)
	for i in _sparks.size():
		var wave := 0.5 + 0.5 * sin(_phase * (1.0 + 0.15 * float(i)) + float(i))
		_sparks[i].scale = Vector3.ONE * (0.08 + 0.10 * wave * (1.0 + 0.3 * float(_tier)))


func _bezier(k: float) -> Vector3:
	var inv := 1.0 - k
	return _from * (inv * inv) + _ctrl * (2.0 * inv * k) + _to * (k * k)
