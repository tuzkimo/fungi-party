class_name DoorPanel
extends CanvasLayer

## 走到校门前才出现的浮层：讲清玩法，点「开始上课」才进教室。
## 和商店一样每帧惰性找 door：场景往返后旧引用都会失效。

var _root: Control
var _start: Button
var _cost_label: Label


func _ready() -> void:
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UIStyle.theme()
	add_child(root)

	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.03, 0.03, 0.04, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)

	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)

	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.custom_minimum_size = Vector2(820.0, 0.0)
	panel.add_theme_stylebox_override("panel", UIStyle.panel())
	center.add_child(panel)
	_root = root

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)

	var title := Label.new()
	title.text = "上课偷吃大赛"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 38)
	box.add_child(title)

	var rules := Label.new()
	rules.text = "老师看黑板时，按住屏幕吃\n老师看过来，马上松手\n被抓 3 次出局；先吃满 20 口的人赢"
	rules.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(rules)

	_cost_label = Label.new()
	_cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_cost_label)

	_start = Button.new()
	_start.text = "开始上课"
	_start.custom_minimum_size = Vector2(240.0, 64.0)
	_start.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_start.pressed.connect(_on_start)
	UIStyle.style_button(_start)
	box.add_child(_start)

	root.visible = false


func _process(_delta: float) -> void:
	var door := get_tree().get_first_node_in_group("door") as ClassroomDoor
	var show_now: bool = door != null and door.player_inside
	_root.visible = show_now
	if show_now:
		_refresh()


func _refresh() -> void:
	var stamina := int(Save.read()["stamina"])
	var can := Day.can_play(stamina, Config.STAMINA_COST_CLASSROOM)
	_start.disabled = not can
	_cost_label.text = Day.entry_label(stamina, Config.STAMINA_COST_CLASSROOM)


func _on_start() -> void:
	get_tree().change_scene_to_file(Config.CLASSROOM_PATH)
