extends "res://tests/test_base.gd"

const PITCH_MIN := CamRig.PITCH_MIN
const PITCH_MAX := CamRig.PITCH_MAX


func test_pitch_clamped_at_bottom() -> void:
	var r := CamRig.orbit(Vector3(-0.5, 0.0, 0.0), Vector2(0, 10000), 0.01, PITCH_MIN, PITCH_MAX)
	check(absf(r.x - PITCH_MIN) < 0.001, "俯角下限（实得 %.4f）" % r.x)


func test_pitch_clamped_at_top() -> void:
	var r := CamRig.orbit(Vector3(-0.5, 0.0, 0.0), Vector2(0, -10000), 0.01, PITCH_MIN, PITCH_MAX)
	check(absf(r.x - PITCH_MAX) < 0.001, "俯角上限（实得 %.4f）" % r.x)


func test_yaw_accumulates() -> void:
	var r := CamRig.orbit(Vector3(-0.5, 0.0, 0.0), Vector2(100, 0), 0.01, PITCH_MIN, PITCH_MAX)
	check(absf(r.y + 1.0) < 0.001, "横向拖动改变偏航（实得 %.4f）" % r.y)


func test_arm_length_minimum() -> void:
	check_eq(CamRig.clamp_arm_length(0.3, 1.2), 1.2, "贴脸时拉回最短距离")
	check_eq(CamRig.clamp_arm_length(4.0, 1.2), 4.0, "正常距离不变")


func test_can_look_up_at_the_sky() -> void:
	check(CamRig.PITCH_MAX > 0.3, "俯仰上限能抬到天上看（实得 %.3f）" % CamRig.PITCH_MAX)
