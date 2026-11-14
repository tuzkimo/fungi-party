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


func test_clock_text_moved_to_ui_style() -> void:
	check_eq(UIStyle.clock_text(95.4), "1:35", "一分三十五秒")
	check_eq(UIStyle.clock_text(-3.0), "0:00", "负数不显示负号")
	check_eq(HidePanel.clock_text(120.0), "2:00", "捉迷藏那边还照旧能用")
