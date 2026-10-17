class_name DoorPanel
extends CanvasLayer

## 走到校门前才出现的浮层：讲清玩法，点「开始上课」才进教室。
## 和商店一样每帧惰性找 door：场景往返后旧引用都会失效。

var _panel: Panel


func _ready() -> void:
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UIStyle.theme()
	add_child(root)

	_panel = Panel.new()
	_panel.name = "Panel"
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = -400.0
	_panel.offset_right = 400.0
	_panel.offset_top = -360.0
	_panel.offset_bottom = -60.0
	_panel.visible = false
	_panel.add_theme_stylebox_override("panel", UIStyle.panel())
	root.add_child(_panel)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	_panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)

	var title := Label.new()
	title.text = "上课偷吃大赛"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 38)
	box.add_child(title)

	var rules := Label.new()
	rules.text = "老师看黑板时，按住屏幕吃\n老师看过来，马上松手\n被抓 3 次出局；先吃满 20 口的人赢"
	rules.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(rules)

	var start := Button.new()
	start.text = "开始上课"
	start.custom_minimum_size = Vector2(240.0, 64.0)
	start.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	start.pressed.connect(_on_start)
	UIStyle.style_button(start)
	box.add_child(start)


func _process(_delta: float) -> void:
	var door := get_tree().get_first_node_in_group("door") as ClassroomDoor
	_panel.visible = door != null and door.player_inside


func _on_start() -> void:
	get_tree().change_scene_to_file(Config.CLASSROOM_PATH)
