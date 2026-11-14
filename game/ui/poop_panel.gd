class_name PoopPanel
extends CanvasLayer

## 扔粑粑那一局的画面：正中的准星（粑粑直线飞，正中就是落点）、顶上的命中数 / 剩余时间、
## 右下三个弹药点和「扔」键、左上「放弃」、结算一行字。只画和发信号 —— 发 op 在 PoopGame。
## 动态拼的文字只用 ASCII 标点（真机系统字体没有全角）。

signal throw_pressed
signal give_up_pressed

var _root: Control
var _cross: Control
var _top: Label
var _throw: Button
var _give_up: Button
var _result: Label
var _round := false
var _ammo := 0


func _ready() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UIStyle.theme()
	_root.visible = false
	add_child(_root)

	_cross = Control.new()
	_cross.name = "Cross"
	_cross.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# CanvasLayer 自己不能画，准星和弹药点画在这层 Control 上
	_cross.draw.connect(_draw_overlay)
	_root.add_child(_cross)

	_top = Label.new()
	_top.name = "Top"
	_top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_top.add_theme_font_size_override("font_size", 34)
	_top.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_top.offset_left = -420.0
	_top.offset_right = 420.0
	_top.offset_top = 40.0
	_top.offset_bottom = 96.0
	_root.add_child(_top)

	_throw = Button.new()
	_throw.name = "Throw"
	_throw.text = "扔"
	_throw.custom_minimum_size = Vector2(360.0, 96.0)
	_throw.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_throw.offset_left = -180.0
	_throw.offset_right = 180.0
	# 和捉迷藏的「捉到」同一处：再往下就压到 TouchControls 的摇杆和动作键
	_throw.offset_top = -280.0
	_throw.offset_bottom = -184.0
	_throw.visible = false
	_throw.pressed.connect(func() -> void: throw_pressed.emit())
	UIStyle.style_button(_throw)
	_root.add_child(_throw)

	_give_up = Button.new()
	_give_up.name = "GiveUp"
	_give_up.text = "放弃"
	_give_up.custom_minimum_size = Vector2(150.0, 56.0)
	_give_up.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_give_up.offset_left = -75.0
	_give_up.offset_right = 75.0
	_give_up.offset_top = 110.0
	_give_up.offset_bottom = 166.0
	_give_up.visible = false
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


## 这一局的常规画面：顶上一句话 + 手上几发。
func show_round(top: String, ammo: int) -> void:
	_root.visible = true
	_result.visible = false
	_top.visible = true
	_throw.visible = true
	_give_up.visible = true
	_top.text = top
	var next := clampi(ammo, 0, Config.POOP_AMMO_MAX)
	if next != _ammo or not _round:
		_ammo = next
		_cross.queue_redraw()
	_round = true


func show_result(text: String) -> void:
	_root.visible = true
	_top.visible = false
	_throw.visible = false
	_give_up.visible = false
	_result.text = text
	_result.visible = true
	_round = false
	_cross.queue_redraw()


func close() -> void:
	_root.visible = false
	_result.visible = false
	_round = false
	_cross.queue_redraw()


func _draw_overlay() -> void:
	if not _round:
		return
	var size := _cross.size
	var mid := size * 0.5
	var color := Color(1.0, 1.0, 1.0, 0.55)
	# 空心圆 + 四道短十字：细、半透明，别挡视线
	_cross.draw_arc(mid, 12.0, 0.0, TAU, 40, color, 2.0, true)
	for dir in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		_cross.draw_line(mid + dir * 18.0, mid + dir * 26.0, color, 2.0)
	# 右下三个弹药点，摆在「扔」键上面
	var left := mid.x - 18.0 * float(Config.POOP_AMMO_MAX - 1)
	for i in Config.POOP_AMMO_MAX:
		var at := Vector2(left + 36.0 * float(i), size.y - 330.0)
		if i < _ammo:
			_cross.draw_circle(at, 9.0, Color(0.45, 0.32, 0.18, 0.95))
		else:
			_cross.draw_arc(at, 9.0, 0.0, TAU, 20, Color(1.0, 1.0, 1.0, 0.35), 2.0, true)
