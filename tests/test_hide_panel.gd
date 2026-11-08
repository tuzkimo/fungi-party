extends TestBase

## 捉迷藏的浮层：黑屏倒数、剩余时间、捉到 / 放弃、结算文字。
## 这里只测能算错的那几行（时间格式），画面靠真机看。

func test_clock_text() -> void:
	check_eq(HidePanel.clock_text(95.4), "1:35", "一分三十五秒")
	check_eq(HidePanel.clock_text(0.0), "0:00", "归零")
	check_eq(HidePanel.clock_text(-3.0), "0:00", "负数不显示负号")
	check_eq(HidePanel.clock_text(120.0), "2:00", "整两分")
