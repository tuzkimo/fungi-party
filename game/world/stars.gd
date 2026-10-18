class_name Stars
extends Node3D

## 星星分三组，各自脉动、相位错开 → 整片天一直在闪。
## 逐实例改颜色是每帧 150 次 GDScript 调用，不值得；三组脉冲是 0。

const SEED := 20261019
const TWINKLE_PHASES := [0.0, 2.1, 4.2]
const TWINKLE_MIN := 0.45   # 最暗时还有多亮

@export var daynight_path: NodePath

var _materials: Array[StandardMaterial3D] = []
var _daynight: DayNight
var _elapsed := 0.0


func _ready() -> void:
	_daynight = get_node_or_null(daynight_path) as DayNight
	var per_group := int(ceil(float(Config.STAR_COUNT) / float(Config.STAR_GROUPS)))
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED

	var dot := SphereMesh.new()
	dot.radius = 0.7
	dot.height = 1.4
	dot.radial_segments = 6
	dot.rings = 3

	for g in Config.STAR_GROUPS:
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.disable_fog = true
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = dot
		multimesh.instance_count = per_group

		var node := MultiMeshInstance3D.new()
		node.name = "Group%d" % g
		node.multimesh = multimesh
		node.material_override = material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
		_materials.append(material)

		for i in per_group:
			# 半球上撒点：y 越大越稀，靠近地平线不挤成一圈
			var angle := rng.randf() * TAU
			var height := 0.08 + 0.92 * pow(rng.randf(), 0.7)
			var flat := sqrt(1.0 - height * height)
			var dir := Vector3(cos(angle) * flat, height, sin(angle) * flat)
			var size := rng.randf_range(0.7, 1.4)
			multimesh.set_instance_transform(
				i, Transform3D(Basis().scaled(Vector3.ONE * size), dir * Config.STAR_DISTANCE)
			)


func _process(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null or _daynight == null:
		return
	var t := _daynight.time_of_day
	var fade := DayNight.star_fade(t)
	visible = fade > 0.02
	if not visible:
		return
	_elapsed += delta
	global_position = camera.global_position
	var sky := DayNight.sky_top(t)
	for g in _materials.size():
		var phase: float = TWINKLE_PHASES[g]
		var pulse := TWINKLE_MIN + (1.0 - TWINKLE_MIN) * (0.5 + 0.5 * sin(Config.STAR_TWINKLE_SPEED * _elapsed + phase))
		_materials[g].albedo_color = sky.lerp(Color.WHITE, fade * pulse)
