class_name InvitePanel
extends CanvasLayer

## 森林右上角的「邀请」：列出世界里的人，选一款发邀请；有人邀请我时顶部弹一条接受/拒绝。
## 只负责画和发信号，发 op 归 main.gd（和 JoinPanel 一样）。
## 动态拼的文字只用 ASCII 标点：系统字体不一定有全角 （），真机上是豆腐块。

signal invite_pressed(to: String, kind: String)
signal answer_pressed(from: String, kind: String, accept: bool, role: String)
## 面板底下那个「退出登录」：只发信号，断开和清本机凭据归 main.gd
signal logout_pressed

## 款 → 中文名。不在表里的款不摆出来（服务器上也没有）。
const KIND_NAMES := {
	"classroom": "偷吃",
	"bomb": "传炸弹",
	"owl": "喂猫头鹰",
	"race": "赛跑",
	"hide": "捉迷藏",
}
## 不进右上角面板的款：捉迷藏只能走到跟前发起（否则 50 米外也能邀）
const PANEL_SKIP: Array[String] = ["hide"]
## 服务器拒绝的理由 → 人话（服务器只回 code，`NetOps` / `NetLobby` 那几处）
const ERRORS := {
	"offline": "对方不在线",
	"busy": "已经有一局在开了",
	"kind": "这款还没搬上服务器",
	"self": "不能邀请自己",
	"invite": "这条邀请已经失效",
	"expired": "邀请过期了",
	"room": "房间开不起来",
}

const BUTTON_SIZE := Vector2(240.0, 48.0)

var _root: Control
var _toggle: Button
var _panel: PanelContainer
var _people: VBoxContainer
var _empty: Label
var _status: Label
var _banner: PanelContainer
var _banner_row: HBoxContainer
var _banner_text: Label
var _invite := {}
var _shown: Array[String] = []
var _waiting_for := ""


func _ready() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UIStyle.theme()
	_root.visible = false
	add_child(_root)

	_toggle = Button.new()
	_toggle.name = "Invite"
	_toggle.text = "邀请"
	_toggle.custom_minimum_size = Vector2(160.0, 64.0)
	_toggle.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	# 让开 JoinPanel 的「＋ 加入」（右边那 160 像素）
	_toggle.offset_left = -360.0
	_toggle.offset_right = -200.0
	_toggle.offset_top = 24.0
	_toggle.offset_bottom = 88.0
	_toggle.pressed.connect(_on_toggle)
	UIStyle.style_button(_toggle)
	_root.add_child(_toggle)

	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.visible = false
	_panel.anchor_left = 1.0
	_panel.anchor_right = 1.0
	_panel.offset_left = -460.0
	_panel.offset_right = -24.0
	_panel.offset_top = 100.0
	_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_panel.grow_vertical = Control.GROW_DIRECTION_END
	_panel.add_theme_stylebox_override("panel", UIStyle.panel())
	_root.add_child(_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	_panel.add_child(box)

	var title := Label.new()
	title.text = "邀请谁一起玩"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	box.add_child(title)

	_empty = Label.new()
	_empty.text = "森林里只有你一个人"
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_empty)

	_people = VBoxContainer.new()
	_people.name = "People"
	_people.add_theme_constant_override("separation", 8)
	box.add_child(_people)

	_status = Label.new()
	_status.name = "Status"
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.visible = false
	box.add_child(_status)

	var logout := Button.new()
	logout.name = "Logout"
	logout.text = "退出登录"
	logout.custom_minimum_size = BUTTON_SIZE
	logout.pressed.connect(_on_logout_button)
	UIStyle.style_button(logout)
	box.add_child(logout)

	_banner = PanelContainer.new()
	_banner.name = "Banner"
	_banner.visible = false
	_banner.anchor_left = 0.5
	_banner.anchor_right = 0.5
	_banner.anchor_top = 1.0
	_banner.anchor_bottom = 1.0
	_banner.offset_left = -360.0
	_banner.offset_right = 360.0
	# 压底边中间：顶部右上角是邀请面板，左上角是体力条，底下两条摇杆中间是空的
	_banner.offset_top = -190.0
	_banner.offset_bottom = -110.0
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner.grow_vertical = Control.GROW_DIRECTION_END
	_banner.add_theme_stylebox_override("panel", UIStyle.panel())
	_root.add_child(_banner)

	var row := HBoxContainer.new()
	row.name = "Row"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	_banner.add_child(row)
	_banner_row = row

	_banner_text = Label.new()
	_banner_text.name = "Text"
	row.add_child(_banner_text)

	_rebuild_buttons("")


## 站在 POI 跟前就把右上角让出去（面板一关就自动回来）
func _process(_delta: float) -> void:
	if not _root.visible:
		return
	var blocked := poi_overlay_open(get_tree())
	_toggle.visible = not blocked
	if blocked and _panel.visible:
		_panel.visible = false


## 联机才有：进森林、登录成功、从小游戏回来都要调一次。
func set_online(on: bool) -> void:
	_root.visible = on
	_panel.visible = false
	if not on:
		_hide_banner()


## 世界或邀请变了就调一次（WORLD 每 1/10 秒来一条，所以这里只按「变了」才重建）。
func sync(world: Dictionary, invites: Array) -> void:
	_fill_people(invitable(world))
	_fill_banner(invites)


## 发 op 的结果（体力不够、对方不在线这些）。
func set_status(text: String) -> void:
	_status.text = text
	_status.visible = text != ""


## 有 POI 浮层开着没有：帐篷 / 饭店 / 摊位这些面板就摆在右上角，
## 那对按钮（邀请 / ＋加入）得让开，否则盖住面板的标题和第一行。
static func poi_overlay_open(tree: SceneTree) -> bool:
	for node in tree.get_nodes_in_group("poi_panel"):
		var root := node.get("_root") as Control
		if root != null and root.visible:
			return true
	return false


## 世界里能邀请的人：同屏 2P 在 world 里是「账号|1」，那不是一个账号。
static func invitable(world: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for key in world:
		var name := str(key)
		if name.contains("|"):
			continue
		out.append(name)
	out.sort()
	return out


## 服务器上真在跑的那几款（NetLobby.MODELLED）；不在的中文名表里也不摆。
## 捉迷藏排掉：它得走到跟前发起（`NearPanel`），这里能隔着一整座森林发。
static func kinds() -> Array[String]:
	var out: Array[String] = []
	for kind in NetLobby.MODELLED:
		if PANEL_SKIP.has(kind):
			continue
		if KIND_NAMES.has(kind):
			out.append(str(kind))
	return out


static func kind_name(kind: String) -> String:
	return str(KIND_NAMES.get(kind, kind))


static func invite_text(invite: Dictionary) -> String:
	return "%s 邀请你玩%s" % [
		str(invite.get("from", "?")), kind_name(str(invite.get("kind", "")))
	]


static func error_text(code: String) -> String:
	return str(ERRORS.get(code, code))


func _fill_people(names: Array[String]) -> void:
	if names == _shown:
		return
	_shown = names
	for child in _people.get_children():
		child.free()
	_empty.visible = names.is_empty()
	for name in names:
		for kind in kinds():
			var button := Button.new()
			button.text = "邀请 %s 玩%s" % [name, kind_name(kind)]
			button.custom_minimum_size = BUTTON_SIZE
			button.pressed.connect(_on_invite_button.bind(name, kind))
			UIStyle.style_button(button)
			_people.add_child(button)


func _fill_banner(invites: Array) -> void:
	if invites.is_empty():
		_hide_banner()
		return
	var invite: Dictionary = invites[0]
	if invite == _invite:
		return
	_invite = invite.duplicate()
	_banner_text.text = invite_text(invite)
	_rebuild_buttons(str(invite.get("kind", "")))
	_banner.visible = true


## 横幅上的按钮随款变：捉迷藏多一个「我藏 / 我找」（角色由接受的人自己选）。
func _rebuild_buttons(kind: String) -> void:
	for child in _banner_row.get_children():
		if child != _banner_text:
			child.free()
	if kind == "hide":
		_banner_row.add_child(_banner_button("我藏", true, "hide"))
		_banner_row.add_child(_banner_button("我找", true, "seek"))
		_banner_row.add_child(_banner_button("拒绝", false, ""))
	else:
		_banner_row.add_child(_banner_button("接受", true, ""))
		_banner_row.add_child(_banner_button("拒绝", false, ""))


func _hide_banner() -> void:
	_invite = {}
	_banner.visible = false


func _banner_button(text: String, accept: bool, role: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(150.0, 56.0)
	button.pressed.connect(_on_answer_button.bind(accept, role))
	UIStyle.style_button(button)
	return button


func _on_toggle() -> void:
	_panel.visible = not _panel.visible
	if _panel.visible:
		set_status("")


func _on_invite_button(to: String, kind: String) -> void:
	_waiting_for = to
	invite_pressed.emit(to, kind)


func _on_logout_button() -> void:
	_panel.visible = false
	logout_pressed.emit()


func _on_answer_button(accept: bool, role: String) -> void:
	if _invite.is_empty():
		return
	var from := str(_invite.get("from", ""))
	var kind := str(_invite.get("kind", ""))
	_hide_banner()
	answer_pressed.emit(from, kind, accept, role)


## main.gd 报成功时用得上：等的这个人答应了没。
func waiting_for() -> String:
	return _waiting_for
