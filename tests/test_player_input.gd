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


func test_follow_direction_points_at_target() -> void:
	var dir := Player.follow_direction(Vector3.ZERO, Vector3(0, 0, 3), 0.5)
	check(dir.z > 0.99, "朝目标走")
	check(absf(dir.y) < 0.001, "跟随只看地面方向")


func test_follow_stops_when_close_enough() -> void:
	var dir := Player.follow_direction(Vector3.ZERO, Vector3(0.2, 0, 0), 0.5)
	check_eq(dir, Vector3.ZERO, "贴住目标就停，不抖")


func test_follow_point_sits_behind_the_leader() -> void:
	# 朝 -Z 走的人，背后是 +Z
	var point := Player.follow_point(Vector3(1, 0, 2), Basis.IDENTITY, 1.7)
	check(absf(point.z - 3.7) < 0.001, "目标点在身后（实得 z=%.2f）" % point.z)
	check(absf(point.x - 1.0) < 0.001, "横向跟着 leader")


func test_follow_point_can_shift_to_the_side() -> void:
	# 侧移 1 米：正后方会挡住相机射线，所以默认往侧面让开
	var point := Player.follow_point(Vector3.ZERO, Basis.IDENTITY, 1.7, 1.0)
	check(absf(point.x - 1.0) < 0.001, "往侧面让开（实得 x=%.2f）" % point.x)
	check(absf(point.z - 1.7) < 0.001, "背后的距离不变")


## 森林里抢方向盘：领队没推、另一个人推了才换人（两人都推时不动，免得来回跳）。
func test_lead_swaps_only_when_the_lead_is_idle() -> void:
	check(Player.should_swap(false, true), "领队停手、另一个人推了 = 换人")
	check(not Player.should_swap(true, true), "两个人都推的时候不换")
	check(not Player.should_swap(false, false), "都没推不换")
	check(not Player.should_swap(true, false), "领队自己在推不换")
