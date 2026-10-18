class_name Clouds
extends Node3D

## 低多边形云：10 团压扁球挂在跟随相机的远环上，绕圈就是飘移。
## 颜色和显隐由 DayNight 的纯函数给（见 2026-10-18-v3-sky-design.md 3.2）。

const SEED := 20261018

@export var daynight_path: NodePath

var _material: StandardMaterial3D
var _daynight: DayNight


func _ready() -> void:
	_daynight = get_node_or_null(daynight_path) as DayNight

	_material = StandardMaterial3D.new()
	_material.albedo_color = Color.WHITE
	_material.roughness = 1.0
	_material.disable_fog = true

	var puff := SphereMesh.new()
	puff.radius = 1.0
	puff.height = 2.0
	puff.radial_segments = 12
	puff.rings = 6

	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = puff
	multimesh.instance_count = Config.CLOUD_COUNT * Config.CLOUD_PUFFS

	var node := MultiMeshInstance3D.new()
	node.name = "Puffs"
	node.multimesh = multimesh
	node.material_override = _material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)

	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var i := 0
	for c in Config.CLOUD_COUNT:
		var angle := TAU * float(c) / float(Config.CLOUD_COUNT) + rng.randf_range(-0.25, 0.25)
		var distance := Config.CLOUD_DISTANCE * rng.randf_range(0.8, 1.0)
		var center := Vector3(
			cos(angle) * distance,
			rng.randf_range(Config.CLOUD_HEIGHT_MIN, Config.CLOUD_HEIGHT_MAX),
			sin(angle) * distance
		)
		for p in Config.CLOUD_PUFFS:
			var offset := Vector3(
				rng.randf_range(-16.0, 16.0), rng.randf_range(-4.0, 4.0), rng.randf_range(-12.0, 12.0)
			)
			var size := Vector3(
				rng.randf_range(12.0, 22.0), rng.randf_range(5.0, 9.0), rng.randf_range(10.0, 18.0)
			)
			multimesh.set_instance_transform(i, Transform3D(Basis().scaled(size), center + offset))
			i += 1


func _process(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null or _daynight == null:
		return
	var t := _daynight.time_of_day
	var fade := DayNight.cloud_fade(t)
	visible = fade > 0.02
	if not visible:
		return
	global_position = camera.global_position
	rotation.y += Config.CLOUD_DRIFT * delta
	# 往天空色上混，不靠 alpha：云始终不透明，免掉透明排序的接缝
	var sky := DayNight.sky_horizon(t).lerp(DayNight.sky_top(t), 0.5)
	_material.albedo_color = sky.lerp(DayNight.cloud_color(t), fade)
