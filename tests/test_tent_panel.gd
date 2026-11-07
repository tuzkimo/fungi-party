extends "res://tests/test_base.gd"

## 帐篷里那一行「角色」：每个体型一个按钮，当前那个按不动。


func _collect_buttons(node: Node, out: Array) -> void:
	for child in node.get_children():
		if child is Button:
			out.append(child)
		_collect_buttons(child, out)


## 只挑「角色」那一行的按钮：帐篷里还有睡觉、换衣服这些按钮。
func _character_buttons(panel: TentPanel) -> Array:
	var names: Array = []
	for id in BodyCatalog.ids():
		names.append(BodyCatalog.display_name(id))
	var result: Array = []
	var all: Array = []
	_collect_buttons(panel, all)
	for button in all:
		if names.has(button.text):
			result.append(button)
	return result


## 不进树、手动 _ready()：_process 里那套「走到帐篷口才显示」的逻辑跟这里无关。
func _open_panel() -> TentPanel:
	var panel := TentPanel.new()
	panel._ready()
	return panel


func test_character_row_lists_every_body() -> void:
	var panel := _open_panel()
	panel._build_character_buttons("red")
	var buttons := _character_buttons(panel)
	check_eq(buttons.size(), BodyCatalog.ids().size(), "每个角色一个按钮")
	var texts: Array = []
	for button in buttons:
		texts.append(button.text)
	for id in BodyCatalog.ids():
		check(texts.has(BodyCatalog.display_name(id)), "%s 有按钮" % BodyCatalog.display_name(id))
	panel.free()


func test_current_character_button_is_disabled() -> void:
	var panel := _open_panel()
	panel._build_character_buttons("seafood")
	var buttons := _character_buttons(panel)
	check(buttons.size() > 1, "至少两个角色按钮（实得 %d）" % buttons.size())
	for button in buttons:
		var mine: bool = button.text == BodyCatalog.display_name("seafood")
		check_eq(button.disabled, mine, "%s 的禁用状态" % button.text)
	panel.free()


## 睡觉没有间隔：按钮一直可按；联机写「睡一觉」，单机写「睡到早上」。
## `Save.remote` 是静态的，测完一定要还原，否则后面的用例会以为自己在联机。
func test_sleep_button_is_always_ready() -> void:
	var net := NetClient.new()
	net.data = Save.normalize({"stamina": 3})
	Save.remote = net
	var panel := _open_panel()
	panel._refresh()
	check(panel._sleep.visible, "联机也能睡（回体力）")
	check(not panel._sleep.disabled, "没有间隔，随时能按")
	check_eq(panel._sleep.text, "睡一觉", "联机只是回体力")

	Save.remote = null
	panel._refresh()
	check_eq(panel._sleep.text, "睡到早上", "单机顺带天亮")

	Save.remote = null
	panel.free()
	net.free()


## 二号位加入后，帐篷里选「2P」换的是他那个人的形象（不写盘）。
func test_seat_switch_targets_the_second_player() -> void:
	Party.join("red", "")
	var panel := _open_panel()
	panel._on_pick_seat(1)
	panel._on_pick_character("seafood")
	check_eq(Party.look(1)["body"], "seafood", "二号位换成了海鲜菇")
	panel.free()

	# 新开一块面板看按钮：不在树里的 queue_free 不会真的删，旧按钮还在
	var fresh := _open_panel()
	fresh._on_pick_seat(1)
	for button in _character_buttons(fresh):
		var mine: bool = button.text == BodyCatalog.display_name("seafood")
		check_eq(button.disabled, mine, "二号位当前角色高亮为 %s" % button.text)
	fresh.free()
	Party.leave()
