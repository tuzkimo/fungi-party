extends "res://tests/test_base.gd"


func test_accelerate_no_overshoot() -> void:
	var v := Movement.accelerate(Vector3.ZERO, Vector3(10, 0, 0), 20.0, 25.0, 0.016)
	check(v.x <= 10.0001, "不超调（实得 %.3f）" % v.x)
	check(v.x > 0.0, "朝目标移动")


func test_accelerate_big_delta_clamped() -> void:
	var v := Movement.accelerate(Vector3.ZERO, Vector3(10, 0, 0), 20.0, 25.0, 0.5)
	check(v.length() <= 20.0 / 30.0 + 0.0001, "大 delta 单帧步长上限（实得 %.3f）" % v.length())


func test_accelerate_decelerates_to_zero() -> void:
	var v := Movement.accelerate(Vector3(5, 0, 0), Vector3.ZERO, 20.0, 25.0, 0.016)
	check(v.length() > 0.0 and v.length() < 5.0, "松手后减速")


func test_jump_velocity() -> void:
	check(absf(Movement.jump_velocity(24.0, 1.5) - sqrt(72.0)) < 0.0001, "跳跃初速度")


func test_squash_stretch() -> void:
	check_eq(Movement.squash_stretch(0.0, 0.2), Vector3.ONE, "静止不变形")
	var down := Movement.squash_stretch(-10.0, 0.2)
	check(down.y < 1.0 and down.x > 1.0, "下落压扁")
	var up := Movement.squash_stretch(10.0, 0.2)
	check(up.y > 1.0 and up.x < 1.0, "上升拉长")
