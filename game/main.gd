extends Node3D

## 森林（主场景）没有暂停面板：返回键维持「直接退出游戏」的老行为。
## 赛跑场景自己处理返回键（弹暂停面板），所以全局关掉了 quit_on_go_back。

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		get_tree().quit()
