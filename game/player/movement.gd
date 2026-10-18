class_name Movement

## 纯函数移动数学，方便无头测试。Node 脚本只做编排。

const SQUASH_REFERENCE_SPEED := 10.0
const CHEW_BITE_SECONDS := 0.35
const CHEW_BITES := 3
const CHEW_AMOUNT := 0.12


static func accelerate(current: Vector3, target: Vector3, accel: float, decel: float, delta: float) -> Vector3:
	var rate := accel if target.length() > 0.01 else decel
	return current.move_toward(target, rate * delta)


static func jump_velocity(gravity: float, height: float) -> float:
	return sqrt(2.0 * gravity * height)


static func squash_stretch(vertical_speed: float, max_effect: float) -> Vector3:
	var amount := clampf(absf(vertical_speed) / SQUASH_REFERENCE_SPEED, 0.0, 1.0) * max_effect
	if vertical_speed < 0.0:
		return Vector3(1.0 + amount, 1.0 - amount, 1.0 + amount)
	if vertical_speed > 0.0:
		return Vector3(1.0 - amount, 1.0 + amount, 1.0 - amount)
	return Vector3.ONE


## 吃饭时咬三口：每口 sin 一次「压扁 → 回弹」，咬完（含尾巴的停顿）回到原样。
static func chew_scale(elapsed: float) -> Vector3:
	if elapsed < 0.0 or elapsed > CHEW_BITE_SECONDS * CHEW_BITES:
		return Vector3.ONE
	var phase := fmod(elapsed, CHEW_BITE_SECONDS) / CHEW_BITE_SECONDS
	var k := sin(PI * phase) * CHEW_AMOUNT
	return Vector3(1.0 + k, 1.0 - k, 1.0 + k)
