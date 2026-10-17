class_name Movement

## 纯函数移动数学，方便无头测试。Node 脚本只做编排。

const MAX_STEP_DELTA := 1.0 / 30.0
const SQUASH_REFERENCE_SPEED := 10.0


static func accelerate(current: Vector3, target: Vector3, accel: float, decel: float, delta: float) -> Vector3:
	var dt := minf(delta, MAX_STEP_DELTA)
	var rate := accel if target.length() > 0.01 else decel
	return current.move_toward(target, rate * dt)


static func jump_velocity(gravity: float, height: float) -> float:
	return sqrt(2.0 * gravity * height)


static func squash_stretch(vertical_speed: float, max_effect: float) -> Vector3:
	var amount := clampf(absf(vertical_speed) / SQUASH_REFERENCE_SPEED, 0.0, 1.0) * max_effect
	if vertical_speed < 0.0:
		return Vector3(1.0 + amount, 1.0 - amount, 1.0 + amount)
	if vertical_speed > 0.0:
		return Vector3(1.0 - amount, 1.0 + amount, 1.0 - amount)
	return Vector3.ONE
