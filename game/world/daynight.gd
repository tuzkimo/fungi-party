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
## 天色关键帧：t 与两条颜色曲线一一对应。玩家实际只看到 0.28 ~ 0.86 这一段
## （满体力是 0.28，见底压到 0.86），所以表只铺到这里。
const SKY_KEYS_T: Array[float] = [0.28, 0.36, 0.50, 0.68, 0.78, 0.80, 0.84, 0.86]
const SKY_TOP_KEYS: Array[Color] = [
	Color(0.58, 0.62, 0.84), Color(0.29, 0.55, 0.83), Color(0.18, 0.43, 0.78),
	Color(0.24, 0.44, 0.71), Color(0.42, 0.42, 0.66), Color(0.27, 0.25, 0.48),
	Color(0.10, 0.11, 0.24), Color(0.04, 0.06, 0.14),
]
const SKY_HORIZON_KEYS: Array[Color] = [
	Color(1.0, 0.73, 0.54), Color(0.81, 0.89, 0.96), Color(0.86, 0.92, 0.97),
	Color(0.95, 0.85, 0.75), Color(1.0, 0.65, 0.42), Color(1.0, 0.43, 0.24),
	Color(0.42, 0.24, 0.31), Color(0.11, 0.15, 0.26),
]
const CLOUD_WHITE := Color(1.0, 1.0, 1.0)
const CLOUD_WARM := Color(1.0, 0.78, 0.62)

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
	return _ramp(t, SKY_TOP_KEYS)


static func sky_horizon(t: float) -> Color:
	return _ramp(t, SKY_HORIZON_KEYS)


## 云看不看得见：天黑就没了，朝霞和晚霞都还在。
static func cloud_fade(t: float) -> float:
	return 1.0 - smoothstep(0.76, 0.84, t)


## 云的颜色：太阳越低越暖（朝霞和晚霞里的云才是暖的）。
static func cloud_color(t: float) -> Color:
	return CLOUD_WHITE.lerp(CLOUD_WARM, clampf(1.0 - sun_energy(t), 0.0, 1.0) * 0.8)


## 星星：0.78 起淡入，天黑透才满。
static func star_fade(t: float) -> float:
	return smoothstep(0.78, 0.855, t)


## 关键帧插值：t 落在表外取两端。
static func _ramp(t: float, keys: Array[Color]) -> Color:
	if t <= SKY_KEYS_T[0]:
		return keys[0]
	for i in range(1, SKY_KEYS_T.size()):
		if t <= SKY_KEYS_T[i]:
			var k: float = (t - SKY_KEYS_T[i - 1]) / (SKY_KEYS_T[i] - SKY_KEYS_T[i - 1])
			return keys[i - 1].lerp(keys[i], k)
	return keys[keys.size() - 1]


static func ambient_color(t: float) -> Color:
	if t < 0.25:
		return NIGHT.lerp(DAWN, smoothstep(0.10, 0.25, t))
	if t < 0.36:
		return DAWN.lerp(DAY, smoothstep(0.22, 0.36, t))
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
