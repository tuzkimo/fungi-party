class_name Movement

## 纯函数移动数学，方便无头测试。Node 脚本只做编排。

const SQUASH_REFERENCE_SPEED := 10.0
const CHEW_BITE_SECONDS := 0.35
const CHEW_BITES := 3
const CHEW_AMOUNT := 0.12
## 扔出去那一下：后仰蓄力 → 前甩 → 回正，作用在 `_visual.rotation.x`
const THROW_ANIM_SECONDS := 0.35
const THROW_LEAN := 0.5
## 被打中：左右晃 + 一记压扁
const HIT_ANIM_SECONDS := 0.45
const HIT_WOBBLE := 0.3
const HIT_SQUASH := 0.16


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


## 扔粑粑的起手：一条衰减的正弦 —— 先往后（蓄力）、过零（甩出去）、再回正。
## 两端都是 0，玩家中途停下也不会突然弹回去。返回 `_visual.rotation.x` 的角度。
static func throw_lean(elapsed: float) -> float:
	if elapsed < 0.0 or elapsed >= THROW_ANIM_SECONDS:
		return 0.0
	var k := elapsed / THROW_ANIM_SECONDS
	return -THROW_LEAN * sin(TAU * k) * (1.0 - k)


## 被打中那一下的左右晃：两端归零的衰减正弦，晃两圈半。
static func hit_wobble(elapsed: float) -> float:
	if elapsed < 0.0 or elapsed >= HIT_ANIM_SECONDS:
		return 0.0
	var k := elapsed / HIT_ANIM_SECONDS
	return HIT_WOBBLE * sin(TAU * 2.5 * k) * (1.0 - k)


## 被打中那一下的压扁：先压后弹，两端回到 1。
static func hit_squash(elapsed: float) -> Vector3:
	if elapsed < 0.0 or elapsed >= HIT_ANIM_SECONDS:
		return Vector3.ONE
	var k := sin(PI * elapsed / HIT_ANIM_SECONDS) * HIT_SQUASH
	return Vector3(1.0 + k, 1.0 - k, 1.0 + k)


## 吃饭时咬三口：每口 sin 一次「压扁 → 回弹」，咬完（含尾巴的停顿）回到原样。
static func chew_scale(elapsed: float) -> Vector3:
	if elapsed < 0.0 or elapsed > CHEW_BITE_SECONDS * CHEW_BITES:
		return Vector3.ONE
	var phase := fmod(elapsed, CHEW_BITE_SECONDS) / CHEW_BITE_SECONDS
	var k := sin(PI * phase) * CHEW_AMOUNT
	return Vector3(1.0 + k, 1.0 - k, 1.0 + k)
