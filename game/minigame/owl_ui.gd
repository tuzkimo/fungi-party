class_name OwlUI
extends CanvasLayer

## 喂食 HUD：顶上关卡/时间/四人分数、底部操作提示、倒数与关间横幅、结算、暂停。
## 布局照传炸弹：process_mode ALWAYS 让暂停面板还能点。

signal again_pressed
signal forest_pressed
signal quit_pressed

const HINT_TEXT := "长按屏幕 = 张嘴，松手 = 闭嘴"

var _hud: Label
var _countdown: Label
var _result: ColorRect
var _title: Label
var _rows: Label
var _detail: Label
var _pause: ColorRect
var _names: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UIStyle.theme()
	add_child(root)

	_build_hud(root)
	_build_hint(root)
	_build_countdown(root)
	_build_result(root)
	_build_pause(root)


func set_names(names: Array) -> void:
	_names = names


func _build_hud(root: Control) -> void:
	_hud = Label.new()
	_hud.name = "Hud"
	_hud.position = Vector2(28.0, 44.0)
	_hud.add_theme_font_size_override("font_size", 26)
	root.add_child(_hud)


func _build_hint(root: Control) -> void:
	var hint := Label.new()
	hint.name = "Hint"
	hint.text = HINT_TEXT
	hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hint.offset_left = 28.0
	hint.offset_top = -56.0
	hint.offset_bottom = -20.0
	hint.add_theme_font_size_override("font_size", 22)
	hint.modulate.a = 0.75
	root.add_child(hint)


func _build_countdown(root: Control) -> void:
	_countdown = Label.new()
	_countdown.name = "Countdown"
	_countdown.set_anchors_preset(Control.PRESET_FULL_RECT)
	_countdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_countdown.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_countdown.add_theme_font_size_override("font_size", 96)
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
	_title.add_theme_font_size_override("font_size", 38)
	box.add_child(_title)

	_rows = Label.new()
	_rows.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rows.add_theme_font_size_override("font_size", 26)
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


func show_countdown(text: String) -> void:
	_countdown.text = text
	_countdown.visible = true


func hide_countdown() -> void:
	_countdown.visible = false


## 两行：关卡与剩余时间 / 四个人的分数（出局的标出来）。
func set_hud(level: int, time_left: float, scores: Array, outs: Array) -> void:
	var head := "第 %d/%d 关 · 剩 %d 秒" % [level, Config.OWL_SECONDS.size(), ceili(time_left)]
	var parts := PackedStringArray()
	for i in scores.size():
		var name := String(_names[i]) if i < _names.size() else str(i)
		var out := bool(outs[i]) if i < outs.size() else false
		parts.append("%s %d%s" % [name, int(scores[i]), "（出局）" if out else ""])
	_hud.text = "%s\n%s" % [head, " · ".join(parts)]


## rows：按名次排好的 [{"name": String, "score": int, "out": bool}]。
func show_result(rank: int, earned: int, rows: Array) -> void:
	_result.visible = true
	_countdown.visible = false
	_title.text = "第 %d 名" % rank
	_detail.text = "+%d 蘑菇币" % earned
	var lines := PackedStringArray()
	for row in rows:
		var mark := "▶ " if String(row["name"]) == "你" else "　"
		var out := "（出局）" if bool(row.get("out", false)) else ""
		lines.append("%s%s　%d 分%s" % [mark, String(row["name"]), int(row["score"]), out])
	_rows.text = "\n".join(lines)


func show_pause() -> void:
	_pause.visible = true


func hide_pause() -> void:
	_pause.visible = false
