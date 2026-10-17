class_name Gaze
extends RefCounted

## 老师视线状态机：看黑板 (AWAY) → 预警 (WARN) → 盯视 (WATCH)。
## 只算时间与目标座位，不碰节点；转头和光锥由 teacher.gd 读数。

enum Phase { AWAY, WARN, WATCH }

const WARN_ALPHA_MIN := 0.15
const WARN_ALPHA_MAX := 0.5
const WATCH_ALPHA := 0.55
const MAX_STEPS := 8

var phase: int = Phase.AWAY
var target: int = 0
var time_left: float = 0.0

var _rng := RandomNumberGenerator.new()


func _init(seed_value: int = 1) -> void:
	_rng.seed = seed_value
	target = _rng.randi() % Config.SEAT_COUNT
	time_left = _rng.randf_range(Config.GAZE_AWAY_MIN, Config.GAZE_AWAY_MAX)


func advance(delta: float) -> void:
	var remaining := delta
	var steps := 0
	while remaining > 0.0 and steps < MAX_STEPS:
		steps += 1
		if time_left <= remaining:
			remaining -= time_left
			_enter_next()
		else:
			time_left -= remaining
			remaining = 0.0


func watching() -> int:
	return target if phase == Phase.WATCH else -1


func alpha() -> float:
	match phase:
		Phase.WARN:
			return lerpf(WARN_ALPHA_MAX, WARN_ALPHA_MIN, time_left / Config.GAZE_WARN)
		Phase.WATCH:
			return WATCH_ALPHA
		_:
			return 0.0


func _enter_next() -> void:
	match phase:
		Phase.AWAY:
			target = _rng.randi() % Config.SEAT_COUNT
			phase = Phase.WARN
			time_left = Config.GAZE_WARN
		Phase.WARN:
			phase = Phase.WATCH
			time_left = Config.GAZE_WATCH
		_:
			phase = Phase.AWAY
			time_left = _rng.randf_range(Config.GAZE_AWAY_MIN, Config.GAZE_AWAY_MAX)


## 水平面内的扇形判定。yaw 与 yaw_to 同约定：0 朝 +Z。
static func seen(apex: Vector3, yaw: float, point: Vector3, half_angle_deg: float, range_m: float) -> bool:
	var offset := point - apex
	offset.y = 0.0
	if offset.length() > range_m:
		return false
	var angle := absf(wrapf(atan2(offset.x, offset.z) - yaw, -PI, PI))
	return angle <= deg_to_rad(half_angle_deg)


static func yaw_to(apex: Vector3, point: Vector3) -> float:
	return atan2(point.x - apex.x, point.z - apex.z)
