extends TestBase

## 位置合理性只有 `server_main.clamp_step` 一处：一步走太远就夹住，绝不丢掉整条 MOVE。
## 丢掉整条等于「下一条还拿同一份旧坐标比」——从小游戏回森林就永远卡在门口（真机踩过）。

const ServerMain := preload("res://game/net/server_main.gd")

const CAP := 2.4


func test_normal_step_untouched() -> void:
	var spot := ServerMain.clamp_step(Vector3.ZERO, Vector3(1.0, 0.0, 0.5), CAP)
	check_eq(spot, Vector3(1.0, 0.0, 0.5), "正常一步原样收下")


func test_jump_is_clamped_in_the_right_direction() -> void:
	# 校门口 (0,0,-14) → 森林出生点原点：换场景回来就是这一跳
	var spot := ServerMain.clamp_step(Vector3(0.0, 0.0, -14.0), Vector3.ZERO, CAP)
	var moved := spot - Vector3(0.0, 0.0, -14.0)
	check(absf(moved.length() - CAP) < 0.001, "跳 14 米只往前走 2.4 米")
	check_eq(moved.normalized(), Vector3.BACK, "方向朝出生点，不朝别处")
	check(absf(spot.z + 14.0 - CAP) < 0.001, "落在旧的 z 坐标上往原点挪了 2.4 米")


func test_jump_right_after_jump_keeps_moving() -> void:
	# 夹住之后位置确实往前进了一步：下一条 MOVE 会从这个新位置继续夹，几帧就追上了
	var first := ServerMain.clamp_step(Vector3(0.0, 0.0, -14.0), Vector3.ZERO, CAP)
	var second := ServerMain.clamp_step(first, Vector3.ZERO, CAP)
	check(second.z > first.z, "第二条 MOVE 继续靠近，而不是原地不动")
	check(absf(first.distance_to(second) - CAP) < 0.001, "每一步都走满上限")


func test_same_spot_has_no_nan() -> void:
	var spot := ServerMain.clamp_step(Vector3.ONE, Vector3.ONE, CAP)
	check(spot.is_finite(), "原地不动不能算出 NaN")
	check_eq(spot, Vector3.ONE, "原地不动就还是原地")
