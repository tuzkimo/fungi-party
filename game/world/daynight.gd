class_name DayNight
extends Node

## 一天 = day_length_seconds 秒。0 午夜、0.25 日出、0.5 正午、0.75 日落。
## 角度与颜色都是纯函数，Node 部分只负责写进灯和环境。

const NIGHT := Color(0.10, 0.12, 0.25)
const DAWN := Color(0.95, 0.62, 0.40)
const DAY := Color(0.72, 0.78, 0.86)
const MAX_SUN_ENERGY := 1.1
const MAX_AMBIENT_ENERGY := 0.55
const MIN_AMBIENT_ENERGY := 0.12

@export var sun_path: NodePath
@export var environment_path: NodePath
@export var time_of_day := 0.35
@export var day_length_seconds := Config.DAY_LENGTH_SECONDS

var _sun: DirectionalLight3D
var _environment: Environment


static func sun_rotation(t: float) -> Vector3:
	return Vector3(deg_to_rad(90.0 - 360.0 * t), deg_to_rad(-30.0), 0.0)


static func sun_energy(t: float) -> float:
	return clampf(sin(PI * clampf((t - 0.25) / 0.5, 0.0, 1.0)), 0.0, 1.0)


static func ambient_color(t: float) -> Color:
	if t < 0.25:
		return NIGHT.lerp(DAWN, smoothstep(0.10, 0.25, t))
	if t < 0.35:
		return DAWN.lerp(DAY, smoothstep(0.25, 0.35, t))
	if t < 0.65:
		return DAY
	if t < 0.75:
		return DAY.lerp(DAWN, smoothstep(0.65, 0.75, t))
	return DAWN.lerp(NIGHT, smoothstep(0.75, 0.90, t))


func _ready() -> void:
	_sun = get_node_or_null(sun_path) as DirectionalLight3D
	var world_environment := get_node_or_null(environment_path) as WorldEnvironment
	if world_environment != null:
		_environment = world_environment.environment
	_apply()


func _process(delta: float) -> void:
	if day_length_seconds <= 0.0:
		return
	time_of_day = fmod(time_of_day + delta / day_length_seconds, 1.0)
	_apply()


func _apply() -> void:
	var energy := DayNight.sun_energy(time_of_day)
	if _sun != null:
		_sun.rotation = DayNight.sun_rotation(time_of_day)
		_sun.light_energy = energy * MAX_SUN_ENERGY
		_sun.visible = energy > 0.01
	if _environment != null:
		_environment.ambient_light_color = DayNight.ambient_color(time_of_day)
		_environment.ambient_light_energy = lerpf(MIN_AMBIENT_ENERGY, MAX_AMBIENT_ENERGY, energy)
