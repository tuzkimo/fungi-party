extends TestBase

## 森林里那层捉迷藏驱动：谁被锁、谁降速、我是不是找的人。
## 都是纯函数 —— 场景里那部分只负责把结果写到 Player / NameTag 上。

func _session(seeker: int) -> Dictionary:
	return {"kind": "hide", "game": {"phase": "countdown", "seeker": seeker}}


func test_is_seeker() -> void:
	check_eq(HideGame.is_seeker(_session(1), 1), true, "我的座位是找的人")
	check_eq(HideGame.is_seeker(_session(1), 0), false, "不是")
	check_eq(HideGame.is_seeker({}, 0), false, "没有这一局就不算")


func test_lock_and_speed() -> void:
	check_eq(HideGame.locked("countdown", true), true, "找的人在倒数时被锁")
	check_eq(HideGame.locked("countdown", false), false, "藏的人满速去藏")
	check_eq(HideGame.locked("seeking", true), false, "找的人解锁")
	check_eq(HideGame.locked("over", true), false, "收了局一定要解锁")
	check_eq(HideGame.speed_scale("seeking", true), Config.HIDE_HIDER_SPEED, "找的阶段藏的人降速")
	check_eq(HideGame.speed_scale("countdown", true), 1.0, "倒数阶段不降速")
	check_eq(HideGame.speed_scale("over", true), 1.0, "收了局恢复满速")


func test_hint_and_result_text() -> void:
	check_eq(HideGame.hint_text("countdown", true), "别偷看", "找的人在倒数里别看")
	check_eq(HideGame.hint_text("seeking", false), "藏好，别动", "藏的人提示")
	check_eq(HideGame.result_text(5), "你赢了 +5 蘑菇币", "赢了")
	check_eq(HideGame.result_text(-5), "你输了 5 蘑菇币", "输了")
	check_eq(HideGame.result_text(0), "这一局没算钱", "没结账")
