class_name HidePanel
extends CanvasLayer

## 捉迷藏那一局的画面：找的人黑屏倒数、两边的剩余时间、捉到 / 放弃、结算一行字。
## 只画和发信号 —— 发 op 在 HideGame。
## 动态拼的文字只用 ASCII 标点（真机系统字体没有全角）。

signal catch_pressed
signal give_up_pressed

var _root: Control
var _black: ColorRect
var _big: Label
var _hint: Label
var _catch: Button
var _give_up: Button
var _result: Label
var _target := ""


func _ready() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UIStyle.theme()
	_root.visible = false
	add_child(_root)

	_black = ColorRect.new()
	_black.name = "Black"
	_black.color = Color(0.02, 0.02, 0.03, 1.0)
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_STOP
	_black.visible = false
	_root.add_child(_black)

	_big = Label.new()
	_big.name = "Big"
	_big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_big.add_theme_font_size_override("font_size", 86)
	_big.set_anchors_preset(Control.PRESET_CENTER)
	_big.offset_left = -240.0
	_big.offset_right = 240.0
	_big.offset_top = -90.0
	_big.offset_bottom = 70.0
	_big.visible = false
	_root.add_child(_big)

	_hint = Label.new()
	_hint.name = "Hint"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 40)
	_hint.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_hint.offset_left = -360.0
	_hint.offset_right = 360.0
	_hint.offset_top = 40.0
	_hint.offset_bottom = 100.0
	_root.add_child(_hint)

	_catch = Button.new()
	_catch.name = "Catch"
	_catch.custom_minimum_size = Vector2(360.0, 96.0)
	_catch.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_catch.offset_left = -180.0
	_catch.offset_right = 180.0
	_catch.offset_top = -280.0
	_catch.offset_bottom = -184.0
	_catch.visible = false
	_catch.pressed.connect(func() -> void: catch_pressed.emit())
	UIStyle.style_button(_catch)
	_root.add_child(_catch)

	_give_up = Button.new()
	_give_up.name = "GiveUp"
	_give_up.text = "放弃"
	_give_up.custom_minimum_size = Vector2(150.0, 56.0)
	_give_up.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_give_up.offset_left = -75.0
	_give_up.offset_right = 75.0
	_give_up.offset_top = 110.0
	_give_up.offset_bottom = 166.0
	_give_up.pressed.connect(func() -> void: give_up_pressed.emit())
	UIStyle.style_button(_give_up)
	_root.add_child(_give_up)

	_result = Label.new()
	_result.name = "Result"
	_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result.add_theme_font_size_override("font_size", 48)
	_result.set_anchors_preset(Control.PRESET_CENTER)
	_result.offset_left = -400.0
	_result.offset_right = 400.0
	_result.offset_top = -60.0
	_result.offset_bottom = 60.0
	_result.visible = false
	_root.add_child(_result)


## 倒计时文案现在归 UIStyle（扔粑粑也要用），这里留一层转调
static func clock_text(seconds: float) -> String:
	return UIStyle.clock_text(seconds)


## 这一局的常规画面：black = 找的人那 30 秒黑屏；hint 是「快去藏 / 去捉 / 藏好」这类一句话。
func show_round(black: bool, left: float, hint: String) -> void:
	_root.visible = true
	_result.visible = false
	_black.visible = black
	_big.visible = black
	_give_up.visible = true
	_big.text = clock_text(left)
	_hint.text = "%s  %s" % [hint, clock_text(left)]


## 找到人了：把「捉到 X」按出来（target 空 = 收起来）
func set_target(name: String) -> void:
	_target = name
	_catch.visible = name != "" and _root.visible
	_catch.text = "捉到 %s" % name


func show_result(text: String) -> void:
	_root.visible = true
	_black.visible = false
	_big.visible = false
	_hint.visible = false
	_catch.visible = false
	_give_up.visible = false
	_result.text = text
	_result.visible = true
	_target = ""


func close() -> void:
	_root.visible = false
	_black.visible = false
	_big.visible = false
	_hint.visible = true
	_catch.visible = false
	_give_up.visible = false
	_result.visible = false
	_target = ""


func target() -> String:
	return _target
