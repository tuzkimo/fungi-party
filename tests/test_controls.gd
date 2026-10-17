extends "res://tests/test_base.gd"


func test_actions_registered() -> void:
	Controls.ensure()
	for action in ["move_left", "move_right", "move_forward", "move_back", "jump", "run", "orbit"]:
		check(InputMap.has_action(action), "动作 %s 已注册" % action)


func test_ensure_is_idempotent() -> void:
	Controls.ensure()
	Controls.ensure()
	var events := InputMap.action_get_events("jump")
	check_eq(events.size(), 1, "重复调用不重复绑定")
