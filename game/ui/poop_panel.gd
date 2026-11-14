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
## 准星该画在哪（扔的方向在屏幕上的位置）；负坐标 = 屏幕正中
var _aim := Vector2(-1.0, -1.0)


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
	_throw.add_theme_font_size_override("font_size", 30)
	_throw.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.92))
	# 和「跳」那个动作键一样是个圆的，摆在底下正中（双人时正好在两个人的动作键中间）：
	# 不能贴右下 —— 那里是二号位摇杆的抓取圈（TouchControls 先于 GUI 拿手指），按扔会变成推摇杆
	_throw.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_throw.offset_left = -56.0
	_throw.offset_right = 56.0
	_throw.offset_top = -164.0
	_throw.offset_bottom = -52.0
	_throw.visible = false
	_throw.pressed.connect(func() -> void: throw_pressed.emit())
	_throw.add_theme_stylebox_override("normal", _circle(0.22))
	_throw.add_theme_stylebox_override("hover", _circle(0.30))
	_throw.add_theme_stylebox_override("pressed", _circle(0.55))
	_throw.add_theme_stylebox_override("disabled", _circle(0.12))
	_root.add_child(_throw)

	_give_up = Button.new()
	_give_up.name = "GiveUp"
	_give_up.text = "放弃"
	_give_up.custom_minimum_size = Vector2(150.0, 56.0)
	# 左上角体力条下面：正中和右上都是看得到人的地方，别在那儿摆按钮
	_give_up.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_give_up.offset_left = 20.0
	_give_up.offset_right = 170.0
	_give_up.offset_top = 170.0
	_give_up.offset_bottom = 226.0
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


## 准星位置由 PoopGame 每帧算：相机俯着看人，正中不是扔出去的那条线。
func set_aim(point: Vector2) -> void:
	if point.is_equal_approx(_aim):
		return
	_aim = point
	_cross.queue_redraw()


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


## 和 TouchControls 那个动作键一样的半透明圆
static func _circle(alpha: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 1.0, 1.0, alpha)
	style.set_corner_radius_all(56)
	style.border_color = Color(1.0, 1.0, 1.0, 0.45)
	style.set_border_width_all(3)
	return style


func _draw_overlay() -> void:
	if not _round:
		return
	var size := _cross.size
	var mid := size * 0.5
	var color := Color(1.0, 1.0, 1.0, 0.55)
	# 空心圆 + 四道短十字：细、半透明，别挡视线
	var aim := _aim if _aim.x >= 0.0 else mid
	# 先垫一圈暗的：白准星压在亮草地/浅绿树上一眼看不见
	var shade := Color(0.0, 0.0, 0.0, 0.45)
	_cross.draw_arc(aim, 12.0, 0.0, TAU, 40, shade, 5.0, true)
	for dir in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		_cross.draw_line(aim + dir * 18.0, aim + dir * 26.0, shade, 5.0)
	_cross.draw_arc(aim, 12.0, 0.0, TAU, 40, color, 2.0, true)
	for dir in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		_cross.draw_line(aim + dir * 18.0, aim + dir * 26.0, color, 2.0)
	# 三个弹药点摆在「扔」键右手边（正中那块是玩家自己的身体）
	for i in Config.POOP_AMMO_MAX:
		var at := Vector2(size.x * 0.5 + 90.0 + 30.0 * float(i), size.y - 108.0)
		if i < _ammo:
			_cross.draw_circle(at, 9.0, Color(0.45, 0.32, 0.18, 0.95))
		else:
			_cross.draw_arc(at, 9.0, 0.0, TAU, 20, Color(1.0, 1.0, 1.0, 0.35), 2.0, true)
