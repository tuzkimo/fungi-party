extends "res://tests/test_base.gd"


func test_deadzone() -> void:
	check_eq(
		TouchControls.joystick_vector(Vector2.ZERO, Vector2(3, 0), 100.0, 10.0),
		Vector2.ZERO,
		"死区内不响应",
	)


func test_clamp_to_unit() -> void:
	var v := TouchControls.joystick_vector(Vector2.ZERO, Vector2(300, 0), 100.0, 10.0)
	check(absf(v.length() - 1.0) < 0.0001, "超出半径夹到 1（实得 %.3f）" % v.length())
	check(v.x > 0.99, "方向保留")


func test_partial() -> void:
	var v := TouchControls.joystick_vector(Vector2.ZERO, Vector2(50, 0), 100.0, 10.0)
	check(v.x > 0.4 and v.x < 0.7, "半程约 0.5（实得 %.3f）" % v.x)


func test_direction_kept() -> void:
	var v := TouchControls.joystick_vector(Vector2.ZERO, Vector2(0, -80), 100.0, 10.0)
	check(v.y < -0.7 and absf(v.x) < 0.001, "向上推得到负 y")
