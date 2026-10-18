class_name BombUI
extends CanvasLayer

## 传炸弹 HUD：左右两个大投掷键、屏幕四边泛红、倒数、结算与暂停面板。
## 布局照赛跑：process_mode ALWAYS 让暂停面板还能点。

signal again_pressed
signal forest_pressed
signal quit_pressed
signal throw_pressed(side: int)

const BUTTON_RADIUS := 76.0
const BUTTON_INSET := 150.0
## 屏幕泛红：danger 超过这个值才开始泛，到 1 时最浓。
const EDGE_MIN := 0.35
const EDGE_ALPHA := 0.55
const EDGE_THICK := 24.0
const EDGE_COLOR := Color(0.86, 0.12, 0.10)

var _countdown: Label
var _edges: Array[ColorRect] = []
var _left: DashButton
var _right: DashButton
var _result: ColorRect
var _title: Label
var _detail: Label
var _rows: Label
var _pause: ColorRect


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UIStyle.theme()
	add_child(root)

	_build_edges(root)
	_build_buttons(root)
	_build_countdown(root)
	_build_result(root)
	_build_pause(root)


func _build_edges(root: Control) -> void:
	var presets := [
		Control.PRESET_TOP_WIDE, Control.PRESET_BOTTOM_WIDE,
		Control.PRESET_LEFT_WIDE, Control.PRESET_RIGHT_WIDE,
	]
	for i in presets.size():
		var edge := ColorRect.new()
		edge.name = "Edge%d" % i
		edge.color = Color(EDGE_COLOR.r, EDGE_COLOR.g, EDGE_COLOR.b, 0.0)
		edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		edge.set_anchors_preset(presets[i])
		match i:
			0:
				edge.offset_bottom = EDGE_THICK
			1:
				edge.offset_top = -EDGE_THICK
			2:
				edge.offset_right = EDGE_THICK
			3:
				edge.offset_left = -EDGE_THICK
		root.add_child(edge)
		_edges.append(edge)


func _build_buttons(root: Control) -> void:
	_left = _throw_button("ThrowLeft", true)
	_left.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_place(_left, Vector2(BUTTON_INSET, -BUTTON_INSET))
	_left.pressed.connect(func() -> void: throw_pressed.emit(-1))
	root.add_child(_left)

	_right = _throw_button("ThrowRight", false)
	_right.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_place(_right, Vector2(-BUTTON_INSET, -BUTTON_INSET))
	_right.pressed.connect(func() -> void: throw_pressed.emit(1))
	root.add_child(_right)


func _throw_button(node_name: String, mirrored: bool) -> DashButton:
	var button := DashButton.new()
	button.name = node_name
	button.radius = BUTTON_RADIUS
	button.mirror = mirrored
	return button


func _place(button: DashButton, center: Vector2) -> void:
	button.offset_left = center.x - button.radius
	button.offset_right = center.x + button.radius
	button.offset_top = center.y - button.radius
	button.offset_bottom = center.y + button.radius


func _build_countdown(root: Control) -> void:
	_countdown = Label.new()
	_countdown.name = "Countdown"
	_countdown.set_anchors_preset(Control.PRESET_FULL_RECT)
	_countdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_countdown.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_countdown.add_theme_font_size_override("font_size", 120)
	_countdown.visible = false
	root.add_child(_countdown)


func _build_result(root: Control) -> void:
	_result = ColorRect.new()
	_result.name = "Result"
	_result.color = Color(0.05, 0.04, 0.06, 0.93)
	_result.set_anchors_preset(Control.PRESET_FULL_RECT)
	_result.visible = false
	root.add_child(_result)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_result.add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	center.add_child(box)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)

	_rows = Label.new()
	_rows.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rows.add_theme_font_size_override("font_size", 24)
	box.add_child(_rows)

	_detail = Label.new()
	_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_detail)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 32)
	box.add_child(row)

	var again := _button("再来一局", 200.0)
	again.pressed.connect(func() -> void: again_pressed.emit())
	row.add_child(again)

	var forest := _button("回森林", 200.0)
	forest.pressed.connect(func() -> void: forest_pressed.emit())
	row.add_child(forest)


func _build_pause(root: Control) -> void:
	_pause = ColorRect.new()
	_pause.name = "Pause"
	_pause.color = Color(0.05, 0.04, 0.06, 0.88)
	_pause.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause.visible = false
	root.add_child(_pause)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause.add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 22)
	center.add_child(box)

	var title := Label.new()
	title.text = "要退出吗"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 38)
	box.add_child(title)

	var hint := Label.new()
	hint.text = "再按一次返回键继续"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)

	var restart := _button("重新开始", 320.0)
	restart.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	restart.pressed.connect(func() -> void: again_pressed.emit())
	box.add_child(restart)

	var forest := _button("回森林", 320.0)
	forest.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	forest.pressed.connect(func() -> void: forest_pressed.emit())
	box.add_child(forest)

	var quit := _button("退出游戏", 320.0)
	quit.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	quit.pressed.connect(func() -> void: quit_pressed.emit())
	box.add_child(quit)


func _button(text: String, width: float) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(width, 64.0)
	UIStyle.style_button(button)
	return button


## 倒数期间把两个投掷键关掉：新一局开场时的残留触摸/复用事件一律点不动，
## 只有倒数结束后新按下的手指才算数。
func set_armed(value: bool) -> void:
	_set_armed(value)


func show_countdown(text: String) -> void:
	_countdown.text = text
	_countdown.visible = true


func hide_countdown() -> void:
	_countdown.visible = false


## 屏幕四边泛红：danger 越高越浓。
func set_danger(danger: float) -> void:
	var alpha := clampf(danger - EDGE_MIN, 0.0, 1.0) * EDGE_ALPHA
	for edge in _edges:
		edge.color.a = alpha


## rows：BombScore.rows() 的结果（活着的人在前，玩家那行标 ▶）。
func show_result(rank: int, seconds: float, earned: int, rows: Array) -> void:
	_result.visible = true
	_set_armed(false)
	_countdown.visible = false
	_title.text = "第 %d 名" % rank
	_detail.text = "撑了 %d 秒，+%d 蘑菇币" % [ceili(seconds), earned]
	var lines := PackedStringArray()
	for row in rows:
		var mark := "▶ " if String(row["name"]) == "你" else "　"
		lines.append("%s%s　%s" % [mark, String(row["name"]), String(row["note"])])
	_rows.text = "\n".join(lines)


func show_pause() -> void:
	_pause.visible = true
	_set_armed(false)


func hide_pause() -> void:
	_pause.visible = false
	_set_armed(true)


func _set_armed(armed: bool) -> void:
	_left.armed = armed
	_right.armed = armed
