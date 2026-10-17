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


func test_safe_insets_zero_when_full_screen() -> void:
	var insets := TouchControls.safe_insets(Vector2i(2400, 1080), Rect2i(0, 0, 2400, 1080), Vector2(1600, 720))
	check_eq(insets, Vector2.ZERO, "无安全区时零内缩")


func test_safe_insets_scaled_to_viewport() -> void:
	# 屏幕 2400 宽、两侧各让 60，viewport 1600 宽 → 每侧 40
	var insets := TouchControls.safe_insets(Vector2i(2400, 1080), Rect2i(60, 0, 2280, 1080), Vector2(1600, 720))
	check(absf(insets.x - 40.0) < 0.01, "左侧内缩（实得 %.2f）" % insets.x)
	check(absf(insets.y - 40.0) < 0.01, "右侧内缩（实得 %.2f）" % insets.y)
