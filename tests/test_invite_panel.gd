extends "res://tests/test_base.gd"

## 森林里的邀请浮层：列出谁、按哪一下发什么。


func _open() -> InvitePanel:
	var panel := InvitePanel.new()
	panel._ready()
	return panel


func _all_buttons(node: Node, out: Array) -> void:
	for child in node.get_children():
		if child is Button:
			out.append(child)
		_all_buttons(child, out)


## 只看「谁能邀请」那一列：横幅上的接受/拒绝不算。
func _button(panel: InvitePanel, text: String) -> Button:
	var all: Array = []
	_all_buttons(panel._people, all)
	for b in all:
		if b.text == text:
			return b
	return null


## 横幅上那两个按钮。
func _banner_button(panel: InvitePanel, text: String) -> Button:
	var all: Array = []
	_all_buttons(panel._banner, all)
	for b in all:
		if b.text == text:
			return b
	return null


## 同屏 2P 在 world 里是「账号|1」，不是一个能邀请的账号。
func test_invitable_skips_the_second_player() -> void:
	var names := InvitePanel.invitable({"小红": {}, "阿强|1": {}, "小明": {}})
	check_eq(names, ["小明", "小红"], "只留真账号，按名字排")


## 只有服务器上真在跑的那几款能邀请：其余几款发过去会被拒。
func test_only_modelled_games_are_offered() -> void:
	var kinds := InvitePanel.kinds()
	check(kinds.has("classroom"), "教室能邀请（%s）" % str(kinds))
	check(not kinds.has("race"), "赛跑还在客户端跑，不能邀请")


func test_sync_lists_one_button_per_player_and_game() -> void:
	var panel := _open()
	panel.sync({"小明": {}, "小红": {}, "阿强|1": {}}, [])
	var all: Array = []
	_all_buttons(panel._people, all)
	check_eq(all.size(), 2 * InvitePanel.kinds().size(), "两个人各一款一个按钮")
	check(_button(panel, "邀请 小明 玩偷吃") != null, "小明的按钮在")
	check(_button(panel, "邀请 阿强 玩偷吃") == null, "2P 不单独列")
	panel.free()


func test_pressing_a_button_invites_that_person() -> void:
	var panel := _open()
	var sent := []
	panel.invite_pressed.connect(func(to: String, kind: String) -> void: sent.append([to, kind]))
	panel.sync({"小明": {}}, [])
	var button := _button(panel, "邀请 小明 玩偷吃")
	check(button != null, "按钮在")
	if button != null:
		button.pressed.emit()
	check_eq(sent, [["小明", "classroom"]], "发出邀请")
	panel.free()


func test_empty_forest_says_so() -> void:
	var panel := _open()
	panel.sync({}, [])
	var all: Array = []
	_all_buttons(panel._people, all)
	check_eq(all.size(), 0, "一个人都没有就没有按钮")
	check(panel._empty.visible, "提示「只有你一个人」")
	panel.free()


## 有人邀请我：顶部弹出那条，按「接受」就是 answer(accept=true)。
func test_incoming_invite_banner_and_accept() -> void:
	var panel := _open()
	var answered := []
	panel.answer_pressed.connect(
		func(from: String, kind: String, accept: bool) -> void: answered.append([from, kind, accept])
	)
	panel.sync({}, [{"from": "小明", "kind": "classroom"}])
	check(panel._banner.visible, "横幅弹出来")
	check_eq(panel._banner_text.text, "小明 邀请你玩偷吃", "横幅文字")
	var accept := _banner_button(panel, "接受")
	check(accept != null, "有接受按钮")
	if accept != null:
		accept.pressed.emit()
	check_eq(answered, [["小明", "classroom", true]], "发回接受")
	check(not panel._banner.visible, "按完就收起来")
	panel.free()


func test_decline_answers_no() -> void:
	var panel := _open()
	var answered := []
	panel.answer_pressed.connect(
		func(from: String, kind: String, accept: bool) -> void: answered.append([from, kind, accept])
	)
	panel.sync({}, [{"from": "小红", "kind": "classroom"}])
	var decline := _banner_button(panel, "拒绝")
	check(decline != null, "有拒绝按钮")
	if decline != null:
		decline.pressed.emit()
	check_eq(answered, [["小红", "classroom", false]], "发回拒绝")
	panel.free()


## 邀请没了（过期 / 对方撤了）就收起来。
func test_banner_goes_away_when_the_invite_does() -> void:
	var panel := _open()
	panel.sync({}, [{"from": "小明", "kind": "classroom"}])
	check(panel._banner.visible, "先弹出来")
	panel.sync({}, [])
	check(not panel._banner.visible, "邀请没了就收")
	panel.free()


func test_unknown_kind_falls_back_to_the_id() -> void:
	check_eq(InvitePanel.kind_name("classroom"), "偷吃", "认识的款用中文名")
	check_eq(InvitePanel.kind_name("poker"), "poker", "不认识的直接显示 id")


func test_error_text() -> void:
	check_eq(InvitePanel.error_text("stamina"), "体力不够", "体力不够有中文解释")
	check_eq(InvitePanel.error_text("whatever"), "whatever", "不认识的原样显示")
