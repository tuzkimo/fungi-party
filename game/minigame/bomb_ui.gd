class_name BombUI
extends CanvasLayer

## 传炸弹 HUD：左右两个大投掷键、屏幕四边泛红、倒数、结算与暂停面板。
## 布局照赛跑：process_mode ALWAYS 让暂停面板还能点。

signal again_pressed
signal forest_pressed
signal quit_pressed
## player：第几位玩家按的（Party 的座位号）；side：-1 左手边 / +1 右手边
signal throw_pressed(player: int, side: int)

const BUTTON_RADIUS := 76.0
const BUTTON_INSET := 150.0
## 双人：每人一对键挤在自己那半边，半径小一圈才放得下两根手指
const DUO_RADIUS := 66.0
const DUO_EDGE := 90.0
const DUO_GAP := 210.0
const DUO_BOTTOM := 110.0
## 屏幕泛红：danger 超过这个值才开始泛，到 1 时最浓。
const EDGE_MIN := 0.35
const EDGE_ALPHA := 0.55
const EDGE_THICK := 24.0
const EDGE_COLOR := Color(0.86, 0.12, 0.10)

var _countdown: Label
var _edges: Array[ColorRect] = []
var _buttons: Array[DashButton] = []
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


## 投掷键布局：[{anchor, offset, player, side}]。单人两个键分在屏幕两头（老布局）；
## 双人每人一对挤在自己那半边，两人各按各的。
static func button_layout(duo_mode: bool) -> Array:
	if not duo_mode:
		return [
			{"anchor": Control.PRESET_BOTTOM_LEFT, "offset": Vector2(BUTTON_INSET, -BUTTON_INSET), "player": 0, "side": -1},
			{"anchor": Control.PRESET_BOTTOM_RIGHT, "offset": Vector2(-BUTTON_INSET, -BUTTON_INSET), "player": 0, "side": 1},
		]
	return [
		{"anchor": Control.PRESET_BOTTOM_LEFT, "offset": Vector2(DUO_EDGE, -DUO_BOTTOM), "player": 0, "side": -1},
		{"anchor": Control.PRESET_BOTTOM_LEFT, "offset": Vector2(DUO_EDGE + DUO_GAP, -DUO_BOTTOM), "player": 0, "side": 1},
		{"anchor": Control.PRESET_BOTTOM_RIGHT, "offset": Vector2(-DUO_EDGE - DUO_GAP, -DUO_BOTTOM), "player": 1, "side": -1},
		{"anchor": Control.PRESET_BOTTOM_RIGHT, "offset": Vector2(-DUO_EDGE, -DUO_BOTTOM), "player": 1, "side": 1},
	]


func _build_buttons(root: Control) -> void:
	var duo_mode := Party.joined()
	var layout := BombUI.button_layout(duo_mode)
	for i in layout.size():
		var spec: Dictionary = layout[i]
		var button := _throw_button("Throw%d" % i, int(spec["side"]) < 0, duo_mode)
		button.set_anchors_preset(int(spec["anchor"]))
		_place(button, spec["offset"])
		var player := int(spec["player"])
		var side := int(spec["side"])
		button.pressed.connect(func() -> void: throw_pressed.emit(player, side))
		root.add_child(button)
		_buttons.append(button)


func _throw_button(node_name: String, mirrored: bool, duo_mode: bool) -> DashButton:
	var button := DashButton.new()
	button.name = node_name
	button.radius = DUO_RADIUS if duo_mode else BUTTON_RADIUS
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


## ranks：每个玩家的名次（1 基，按座位序）。
## rows：BombScore.rows() 的结果（活着的人在前，人那几行标 ▶）。
func show_result(ranks: Array, seconds: float, earned: int, rows: Array) -> void:
	_result.visible = true
	_set_armed(false)
	_countdown.visible = false
	var titles := PackedStringArray()
	for i in ranks.size():
		var who := "" if ranks.size() == 1 else "%s " % Party.name_of(i)
		titles.append("%s第 %d 名" % [who, int(ranks[i])])
	_title.text = "，".join(titles)
	_detail.text = "撑了 %d 秒，+%d 蘑菇币" % [ceili(seconds), earned]
	var lines := PackedStringArray()
	for row in rows:
		var mark := "▶ " if bool(row.get("human", false)) else "　"
		lines.append("%s%s　%s" % [mark, String(row["name"]), String(row["note"])])
	_rows.text = "\n".join(lines)


func show_pause() -> void:
	_pause.visible = true
	_set_armed(false)


func hide_pause() -> void:
	_pause.visible = false
	_set_armed(true)


func _set_armed(armed: bool) -> void:
	for button in _buttons:
		button.armed = armed
