class_name DayNight
extends Node

## 0 午夜、0.25 日出、0.5 正午、0.75 日落。时间由森林侧的 DayLoop 每帧写入。
## 角度与颜色都是纯函数，Node 部分只负责写进灯和环境。

const NIGHT := Color(0.42, 0.48, 0.62)
const DAWN := Color(0.95, 0.62, 0.40)
const DAY := Color(0.72, 0.78, 0.86)
const MAX_SUN_ENERGY := 1.1
const MAX_AMBIENT_ENERGY := 0.55
const MIN_AMBIENT_ENERGY := 0.38
const SUN_NOON := Color(1.0, 0.98, 0.92)
const SUN_DAWN := Color(1.0, 0.62, 0.35)
const SKY_DAY_TOP := Color(0.33, 0.5, 0.78)
const SKY_DAY_HORIZON := Color(0.78, 0.85, 0.92)
const SKY_NIGHT_TOP := Color(0.06, 0.08, 0.18)
const SKY_NIGHT_HORIZON := Color(0.20, 0.24, 0.36)

@export var sun_path: NodePath
@export var environment_path: NodePath
@export var time_of_day := 0.35

var _sun: DirectionalLight3D
var _environment: Environment
var _sky: ProceduralSkyMaterial


static func sun_rotation(t: float) -> Vector3:
	return Vector3(deg_to_rad(90.0 - 360.0 * t), deg_to_rad(-30.0), 0.0)


## 从地面指向太阳的单位向量：+Z 侧升起、正午头顶、-Z 侧落下。
## 直接用 sun_rotation 的基，不另定一套角度。
static func sun_dir(t: float) -> Vector3:
	return Basis.from_euler(sun_rotation(t)).z.normalized()


## 月亮在天色上的刻度：永远比太阳晚半圈。
static func moon_dir_t(t: float) -> float:
	return fmod(t + 0.5, 1.0)


static func moon_dir(t: float) -> Vector3:
	return sun_dir(moon_dir_t(t))


## 落到地平线以下就不画了，太阳月亮天然互斥。
static func body_visible(dir: Vector3) -> bool:
	return dir.y > Config.SKY_BODY_MIN_ELEVATION


static func sun_energy(t: float) -> float:
	return clampf(sin(PI * clampf((t - 0.25) / 0.5, 0.0, 1.0)), 0.0, 1.0)


static func ambient_energy(sun: float) -> float:
	return lerpf(MIN_AMBIENT_ENERGY, MAX_AMBIENT_ENERGY, sun)


static func sun_color(t: float) -> Color:
	# 日出日落偏橙，正午接近白
	var warmth := clampf(1.0 - sun_energy(t), 0.0, 1.0)
	return SUN_NOON.lerp(SUN_DAWN, warmth)


static func sky_top(t: float) -> Color:
	return SKY_NIGHT_TOP.lerp(SKY_DAY_TOP, smoothstep(0.20, 0.40, t) if t < 0.5 else smoothstep(0.80, 0.60, t))


static func sky_horizon(t: float) -> Color:
	var day := SKY_NIGHT_HORIZON.lerp(SKY_DAY_HORIZON, smoothstep(0.20, 0.35, t))
	if t >= 0.5:
		day = SKY_NIGHT_HORIZON.lerp(SKY_DAY_HORIZON, smoothstep(0.80, 0.65, t))
	return day.lerp(SUN_DAWN, 0.25 * (1.0 - sun_energy(t)))


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
		if _environment != null and _environment.sky != null:
			_sky = _environment.sky.sky_material as ProceduralSkyMaterial
	apply()


## 外部改完 time_of_day 之后调它，把天色写进灯和环境。
func apply() -> void:
	var energy := DayNight.sun_energy(time_of_day)
	if _sun != null:
		_sun.rotation = DayNight.sun_rotation(time_of_day)
		_sun.light_energy = energy * MAX_SUN_ENERGY
		_sun.light_color = DayNight.sun_color(time_of_day)
		_sun.visible = energy > 0.01
	if _environment != null:
		_environment.ambient_light_color = DayNight.ambient_color(time_of_day)
		_environment.ambient_light_energy = DayNight.ambient_energy(energy)
		_environment.fog_light_color = DayNight.sky_horizon(time_of_day)
	if _sky != null:
		_sky.sky_top_color = DayNight.sky_top(time_of_day)
		_sky.sky_horizon_color = DayNight.sky_horizon(time_of_day)
