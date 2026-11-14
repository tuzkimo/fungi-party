extends TestBase

## 扔粑粑的 HUD 文案和朝向：按错一个字符真机上就是豆腐块。

func test_top_text() -> void:
	var text := PoopGame.top_text(0, 2, 118.0)
	check(text.contains("0/3"), "我的命中数 0/3")
	check(text.contains("2/3"), "对方的命中数")
	check(text.contains("1:58"), "剩余时间 1:58")
	check(not text.contains("（"), "动态文案不用全角括号")


func test_result_text() -> void:
	check_eq(PoopGame.result_text(5), "你赢了 +5 蘑菇币", "赢")
	check_eq(PoopGame.result_text(-5), "你输了 5 蘑菇币", "输")
	check_eq(PoopGame.result_text(0), "这一局没算钱", "没结账")


func test_aim_dir_is_the_camera_forward() -> void:
	check(PoopGame.aim_dir(Basis.IDENTITY).is_equal_approx(Vector3.FORWARD), "默认朝 -Z")
	var turned := Basis(Vector3.UP, PI * 0.5)
	check(PoopGame.aim_dir(turned).is_equal_approx(Vector3.LEFT), "转半圈朝 -X")
	check(absf(PoopGame.aim_dir(turned).length() - 1.0) < 0.001, "是单位向量")


## 和 FPS 一样：低头就往斜下扔、抬头就往斜上扔。准星画的就是这条线（`PoopGame._aim_point`），
## 想打平飞就得把镜头放平。
func test_aim_dir_follows_the_camera_pitch() -> void:
	var down := PoopGame.aim_dir(Basis(Vector3.RIGHT, -0.5))
	check(down.y < -0.4, "低头往下扔（实得 %f）" % down.y)
	var up := PoopGame.aim_dir(Basis(Vector3.RIGHT, 0.4))
	check(up.y > 0.3, "抬头往上扔（实得 %f）" % up.y)
	check(absf(up.length() - 1.0) < 0.001, "是单位向量")
	check(absf(PoopGame.aim_dir(Basis(Vector3.UP, PI * 0.5) * Basis(Vector3.RIGHT, 0.4)).y - up.y) < 0.001, "俯仰不受偏航影响")


## 「扔」键单人时贴在动作键的右上：两个圆的挖取圈不能叠，否则按扔会变成按跳。
func test_throw_center_clears_the_action_key() -> void:
	var action := Vector2(
		TouchControls.EDGE_MARGIN + TouchControls.STICK_RADIUS,
		TouchControls.EDGE_MARGIN + TouchControls.ACTION_RADIUS
	)
	# 单人的圆心是相对右下角的，翻成同一套坐标再比
	var center := -PoopPanel.throw_center(false)
	var gap := center.distance_to(action) - TouchControls.ACTION_RADIUS * (1.0 + TouchControls.GRAB_FACTOR)
	check(gap > 0.0, "离动作键的挖取圈还有 %f 像素" % gap)
	check(center.y > action.y and center.x < action.x, "在动作键的右上")


func test_throw_center_duo_keeps_the_bottom_middle() -> void:
	var center := PoopPanel.throw_center(true)
	check(absf(center.x) < 1.0, "双人不偏左右（屏幕底正中）")
	check(center.y < 0.0, "在屏幕底之上")


func test_clock_text_moved_to_ui_style() -> void:
	check_eq(UIStyle.clock_text(95.4), "1:35", "一分三十五秒")
	check_eq(UIStyle.clock_text(-3.0), "0:00", "负数不显示负号")
	check_eq(HidePanel.clock_text(120.0), "2:00", "捉迷藏那边还照旧能用")
