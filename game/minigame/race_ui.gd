class_name RaceUI
extends CanvasLayer

## 赛跑 HUD：顶部前进条 + 名次/用时、右下角冲刺按钮（冷却遮罩）、倒数、结算面板。

signal again_pressed
signal forest_pressed
signal dash_pressed

const PLAYER_COLOR := Color(0.92, 0.25, 0.22)
const RIVAL_COLORS := [Color(0.32, 0.55, 0.88), Color(0.66, 0.40, 0.86), Color(0.95, 0.58, 0.25)]
const DOT_SIZE := 16.0
# 放在跳跃按钮正上方，离 TouchControls 的抓取半径足够远，免得一次点按既冲刺又跳
const DASH_RECT := [-350.0, -366.0, -210.0, -270.0]

var _time := 0.0
var _rank := 1
var _hud: Label
var _countdown: Label
var _bar: ColorRect
var _dots: Array[ColorRect] = []
var _dash: Button
var _mask: ColorRect
var _result: ColorRect
var _title: Label
var _detail: Label


func _ready() -> void:
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UIStyle.theme()
	add_child(root)

	_hud = Label.new()
	_hud.name = "Hud"
	_hud.position = Vector2(28.0, 52.0)
	root.add_child(_hud)

	_build_bar(root)
	_build_dash(root)
	_build_countdown(root)
	_build_result(root)


func _build_bar(root: Control) -> void:
	_bar = ColorRect.new()
	_bar.name = "Bar"
	_bar.color = Color(0.08, 0.07, 0.10, 0.55)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_bar.offset_left = 220.0
	_bar.offset_right = -220.0
	_bar.offset_top = 26.0
	_bar.offset_bottom = 42.0
	root.add_child(_bar)

	for i in RIVAL_COLORS.size() + 1:
		var dot := ColorRect.new()
		dot.name = "Dot%d" % i
		dot.size = Vector2(DOT_SIZE, DOT_SIZE)
		dot.color = PLAYER_COLOR if i == 0 else RIVAL_COLORS[i - 1]
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.position.y = -1.0
		_bar.add_child(dot)
		_dots.append(dot)


func _build_dash(root: Control) -> void:
	_dash = Button.new()
	_dash.name = "Dash"
	_dash.text = "冲刺"
	_dash.focus_mode = Control.FOCUS_NONE
	_dash.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_dash.offset_left = DASH_RECT[0]
	_dash.offset_top = DASH_RECT[1]
	_dash.offset_right = DASH_RECT[2]
	_dash.offset_bottom = DASH_RECT[3]
	_dash.pressed.connect(func() -> void: dash_pressed.emit())
	UIStyle.style_button(_dash)
	root.add_child(_dash)

	_mask = ColorRect.new()
	_mask.name = "Cooldown"
	_mask.color = Color(0.02, 0.02, 0.03, 0.62)
	_mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mask.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dash.add_child(_mask)


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
	box.add_theme_constant_override("separation", 22)
	center.add_child(box)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)

	_detail = Label.new()
	_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_detail)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 32)
	box.add_child(row)

	var again := Button.new()
	again.text = "再来一局"
	again.custom_minimum_size = Vector2(200.0, 64.0)
	again.pressed.connect(func() -> void: again_pressed.emit())
	UIStyle.style_button(again)
	row.add_child(again)

	var forest := Button.new()
	forest.text = "回森林"
	forest.custom_minimum_size = Vector2(200.0, 64.0)
	forest.pressed.connect(func() -> void: forest_pressed.emit())
	UIStyle.style_button(forest)
	row.add_child(forest)


func show_countdown(text: String) -> void:
	_countdown.text = text
	_countdown.visible = true


func hide_countdown() -> void:
	_countdown.visible = false


func set_progress(player_z: float, rivals: Array, rank: int) -> void:
	_rank = rank
	_dots[0].position.x = _dot_x(player_z)
	for i in rivals.size():
		_dots[i + 1].position.x = _dot_x(rivals[i].z)
	_refresh_hud()


func set_time(seconds: float) -> void:
	_time = seconds
	_refresh_hud()


## ratio：0 = 刚用掉，1 = 冷却好了。
func set_dash_ready(ratio: float) -> void:
	ratio = clampf(ratio, 0.0, 1.0)
	_mask.offset_top = -_dash.size.y * (1.0 - ratio)
	_mask.offset_bottom = 0.0
	_dash.disabled = ratio < 1.0
	_dash.text = "冲刺" if ratio >= 1.0 else "%d" % ceili((1.0 - ratio) * Config.RACE_DASH_COOLDOWN)


func show_result(rank: int, seconds: float, hits: int, earned: int) -> void:
	_result.visible = true
	_title.text = "第 %d 名" % rank
	_detail.text = "用时 %d 秒，撞了 %d 次，+%d 蘑菇币" % [ceili(seconds), hits, earned]


func _dot_x(z: float) -> float:
	var width := maxf(_bar.size.x - DOT_SIZE, 1.0)
	return clampf(z / Config.RACE_TRACK_LENGTH, 0.0, 1.0) * width


func _refresh_hud() -> void:
	_hud.text = "用时 %d 秒　第 %d 名" % [int(_time), _rank]
