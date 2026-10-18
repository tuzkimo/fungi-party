class_name RaceUI
extends CanvasLayer

## 赛跑 HUD：顶部前进条 + 名次/用时、右下角圆形冲刺按钮、倒数、结算与暂停面板。

signal again_pressed
signal forest_pressed
signal quit_pressed
signal dash_pressed

const PLAYER_COLOR := Color(0.92, 0.25, 0.22)
const RIVAL_COLORS := [Color(0.32, 0.55, 0.88), Color(0.66, 0.40, 0.86), Color(0.95, 0.58, 0.25)]
const DOT_SIZE := 16.0
## 冲刺按钮圆心离右下角的偏移，和跳跃按钮（圆心约 -176,-176）拉开距离，
## 免得一次点按既算跳又算冲刺。
const DASH_CENTER := Vector2(-300.0, -340.0)

var _time := 0.0
var _rank := 1
var _hud: Label
var _countdown: Label
var _bar: ColorRect
var _dots: Array[ColorRect] = []
var _dash: DashButton
var _result: ColorRect
var _title: Label
var _standings: Label
var _detail: Label
var _pause: ColorRect


func _ready() -> void:
	# 暂停面板要在 get_tree().paused 时还能点
	process_mode = Node.PROCESS_MODE_ALWAYS
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
	_build_pause(root)


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
	_dash = DashButton.new()
	_dash.name = "Dash"
	_dash.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_dash.offset_left = DASH_CENTER.x - DashButton.RADIUS
	_dash.offset_right = DASH_CENTER.x + DashButton.RADIUS
	_dash.offset_top = DASH_CENTER.y - DashButton.RADIUS
	_dash.offset_bottom = DASH_CENTER.y + DashButton.RADIUS
	_dash.pressed.connect(func() -> void: dash_pressed.emit())
	root.add_child(_dash)


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

	_standings = Label.new()
	_standings.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_standings.add_theme_font_size_override("font_size", 24)
	box.add_child(_standings)

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
	title.text = "要退出比赛吗"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 38)
	box.add_child(title)

	var hint := Label.new()
	hint.text = "再按一次返回键继续比赛"
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
	_dash.set_ratio(ratio)


## standings：按名次排好的 [{name, finished, time}]，全部跑者都在里面。
func show_result(rank: int, seconds: float, hits: int, earned: int, standings: Array) -> void:
	_result.visible = true
	_dash.armed = false
	_title.text = "第 %d 名" % rank
	_detail.text = "用时 %d 秒，撞了 %d 次，+%d 蘑菇币" % [ceili(seconds), hits, earned]
	var lines := PackedStringArray()
	for i in standings.size():
		var row: Dictionary = standings[i]
		var time: String = "%.1f 秒" % float(row["time"]) if bool(row["finished"]) else "未完赛"
		lines.append("%d. %s　%s" % [i + 1, row["name"], time])
	_standings.text = "\n".join(lines)


func show_pause() -> void:
	_pause.visible = true
	_dash.armed = false


func hide_pause() -> void:
	_pause.visible = false
	_dash.armed = true


func _dot_x(z: float) -> float:
	var width := maxf(_bar.size.x - DOT_SIZE, 1.0)
	return clampf(z / Config.RACE_TRACK_LENGTH, 0.0, 1.0) * width


func _refresh_hud() -> void:
	_hud.text = "用时 %d 秒　第 %d 名" % [int(_time), _rank]
