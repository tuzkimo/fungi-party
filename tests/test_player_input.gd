extends "res://tests/test_base.gd"


func test_input_follows_camera_yaw() -> void:
	var dir := Player.resolve_direction(Vector2(0, -1), PI / 2.0)
	check(absf(dir.x + 1.0) < 0.001, "视角转 90° 后「上」朝世界 -X（实得 %.2f）" % dir.x)


func test_input_without_rotation_is_straight_forward() -> void:
	var dir := Player.resolve_direction(Vector2(0, -1), 0.0)
	check(dir.z < -0.99, "视角朝前时「上」就是 -Z")


func test_diagonal_is_normalized() -> void:
	var dir := Player.resolve_direction(Vector2(1, -1), 0.0)
	check(absf(dir.length() - 1.0) < 0.001, "斜向不超速（实得 %.3f）" % dir.length())
