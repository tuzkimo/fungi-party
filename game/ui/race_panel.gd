class_name RacePanel
extends CanvasLayer

## 走到起跑线才出现的浮层：讲清玩法，点「开始比赛」才进赛跑场景。
## 和校门/商店一样每帧惰性找 start_gate：场景往返后旧引用都会失效。

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
	title.text = "森林赛跑"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 38)
	box.add_child(title)

	var rules := Label.new()
	rules.text = "绕开障碍跑到终点\n侧面有动物冲出来，影子先到\n跳能跨矮栏，冲刺要等冷却"
	rules.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(rules)

	_cost_label = Label.new()
	_cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_cost_label)

	_start = Button.new()
	_start.text = "开始比赛"
	_start.custom_minimum_size = Vector2(240.0, 64.0)
	_start.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_start.pressed.connect(_on_start)
	UIStyle.style_button(_start)
	box.add_child(_start)

	root.visible = false


func _process(_delta: float) -> void:
	var gate := get_tree().get_first_node_in_group("start_gate") as StartGate
	var show_now: bool = gate != null and gate.player_inside
	_root.visible = show_now
	if show_now:
		_refresh()


func _refresh() -> void:
	var stamina := int(Save.read()["stamina"])
	var can := Day.can_play(stamina, Config.STAMINA_COST_RACE)
	_start.disabled = not can
	_cost_label.text = Day.entry_label(stamina, Config.STAMINA_COST_RACE)


func _on_start() -> void:
	get_tree().change_scene_to_file(Config.RACE_PATH)
