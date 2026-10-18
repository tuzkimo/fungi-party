class_name DashButton
extends Control

## 赛跑的圆形冲刺按钮：尺寸/配色和 TouchControls 的跳按钮同一套，
## 中间一个双箭头；冷却时外圈从空画满，满了才点得动。

signal pressed

const RADIUS := 56.0
const GRAB := 1.5
const FILL := Color(1, 1, 1, 0.22)
const FILL_PRESSED := Color(1, 1, 1, 0.55)
const RING := Color(1, 1, 1, 0.45)
const READY_RING := Color(1, 1, 1, 0.75)
const COOL_ARC := Color(0.08, 0.07, 0.09, 0.55)
const ICON_READY := Color(1, 1, 1, 0.9)
const ICON_COOL := Color(1, 1, 1, 0.35)

var ratio := 1.0
var armed := true
## 传炸弹的两个投掷键用更大的圆、朝左的箭头；赛跑那边什么都不传，行为不变。
var radius := RADIUS
var mirror := false

var _finger := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


## ratio：0 = 刚用掉，1 = 冷却好了。
func set_ratio(value: float) -> void:
	value = clampf(value, 0.0, 1.0)
	if is_equal_approx(value, ratio):
		return
	ratio = value
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not armed or not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			if _finger < 0 and event.position.distance_to(get_global_rect().get_center()) <= radius * GRAB:
				_finger = event.index
				queue_redraw()
				pressed.emit()
		elif event.index == _finger:
			_finger = -1
			queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	draw_circle(center, radius, FILL_PRESSED if _finger >= 0 else FILL)
	draw_circle(center, radius, RING, false, 3.0)
	if ratio < 1.0:
		draw_arc(center, radius - 6.0, -PI * 0.5, -PI * 0.5 + TAU * ratio, 32, COOL_ARC, 7.0)
	else:
		draw_arc(center, radius + 4.0, 0.0, TAU, 32, READY_RING, 2.0)
	_draw_icon(center, ICON_READY if ratio >= 1.0 else ICON_COOL)


## 两个箭头（»），全部用多边形画，不依赖字体里的图标字形。
func _draw_icon(center: Vector2, color: Color) -> void:
	var dir := -1.0 if mirror else 1.0
	for i in 2:
		var x := center.x + dir * (-10.0 + float(i) * 12.0)
		draw_colored_polygon(PackedVector2Array([
			Vector2(x, center.y - 10.0),
			Vector2(x + dir * 9.0, center.y),
			Vector2(x, center.y + 10.0),
			Vector2(x - dir * 4.0, center.y + 10.0),
			Vector2(x + dir * 5.0, center.y),
			Vector2(x - dir * 4.0, center.y - 10.0),
		]), color)
