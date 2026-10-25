class_name JoinPanel
extends CanvasLayer

## 森林右上角的「＋ 加入」：给二号位选体型和皮肤（皮肤用的是同一份收藏），点「加入」生出来，
## 已加入时变「离队」。二号位的形象不写盘，所以这里只发信号，生长和销毁归 main.gd。

signal join_pressed(body_id: String, skin_id: String)
signal leave_pressed

const BUTTON_SIZE := Vector2(132.0, 48.0)
const COLUMNS := 4

var _toggle: Button
var _panel: PanelContainer
var _bodies: HBoxContainer
var _skins: GridContainer
var _confirm: Button
var _body_id := BodyCatalog.DEFAULT_ID
var _skin_id := ""


func _ready() -> void:
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UIStyle.theme()
	add_child(root)

	_toggle = Button.new()
	_toggle.name = "Join"
	_toggle.text = "＋ 加入"
	_toggle.custom_minimum_size = Vector2(160.0, 64.0)
	_toggle.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_toggle.offset_left = -184.0
	_toggle.offset_right = -24.0
	_toggle.offset_top = 24.0
	_toggle.offset_bottom = 88.0
	_toggle.pressed.connect(_on_toggle)
	UIStyle.style_button(_toggle)
	root.add_child(_toggle)

	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.visible = false
	_panel.anchor_left = 1.0
	_panel.anchor_right = 1.0
	_panel.offset_left = -680.0
	_panel.offset_right = -24.0
	_panel.offset_top = 100.0
	_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_panel.grow_vertical = Control.GROW_DIRECTION_END
	_panel.add_theme_stylebox_override("panel", UIStyle.panel())
	root.add_child(_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	_panel.add_child(box)

	var title := Label.new()
	title.name = "Title"
	title.text = "二号位"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	box.add_child(title)

	_bodies = HBoxContainer.new()
	_bodies.name = "Bodies"
	_bodies.alignment = BoxContainer.ALIGNMENT_CENTER
	_bodies.add_theme_constant_override("separation", 10)
	box.add_child(_bodies)

	_skins = GridContainer.new()
	_skins.name = "Skins"
	_skins.columns = COLUMNS
	_skins.add_theme_constant_override("h_separation", 10)
	_skins.add_theme_constant_override("v_separation", 8)
	box.add_child(_skins)

	_confirm = Button.new()
	_confirm.name = "Confirm"
	_confirm.custom_minimum_size = Vector2(200.0, 56.0)
	_confirm.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_confirm.pressed.connect(_on_confirm)
	UIStyle.style_button(_confirm)
	box.add_child(_confirm)

	sync()


## 外面的状态变了（加入 / 离队 / 换场景回来）就调一次。
func sync() -> void:
	_toggle.text = "2P 已加入" if Party.joined() else "＋ 加入"


func _on_toggle() -> void:
	_panel.visible = not _panel.visible
	if _panel.visible:
		_refresh()


func _refresh() -> void:
	var data := Save.read()
	var owned := data["owned"] as PackedStringArray
	# 二号位加入后沿用上次选的体型；皮肤默认「原色」
	if Party.joined():
		_body_id = str(Party.look(1)["body"])
		_skin_id = str(Party.look(1)["skin"])
	_confirm.text = "离队" if Party.joined() else "加入"

	for child in _bodies.get_children():
		child.queue_free()
	for id in BodyCatalog.ids():
		var button := Button.new()
		button.text = BodyCatalog.display_name(id)
		button.custom_minimum_size = BUTTON_SIZE
		button.disabled = id == _body_id
		button.pressed.connect(_on_pick_body.bind(id))
		UIStyle.style_button(button)
		_bodies.add_child(button)

	for child in _skins.get_children():
		child.queue_free()
	_add_skin("红帽", "")
	for id in owned:
		var skin := SkinCatalog.by_id(str(id))
		if skin != null:
			_add_skin(skin.display_name, skin.id)


func _add_skin(text: String, skin_id: String) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = BUTTON_SIZE
	button.disabled = skin_id == _skin_id
	var skin := SkinCatalog.by_id(skin_id)
	var border := Config.RARITY_COLORS[skin.rarity] if skin != null else Color(0, 0, 0, 0)
	button.pressed.connect(_on_pick_skin.bind(skin_id))
	UIStyle.style_button(button, border)
	_skins.add_child(button)


func _on_pick_body(id: String) -> void:
	_body_id = id
	_refresh()


func _on_pick_skin(id: String) -> void:
	_skin_id = id
	_refresh()


func _on_confirm() -> void:
	_panel.visible = false
	if Party.joined():
		leave_pressed.emit()
	else:
		join_pressed.emit(_body_id, _skin_id)
	sync()
