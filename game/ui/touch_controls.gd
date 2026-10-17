class_name TouchControls
extends Control

## 单指摇杆 + 单指跳跃，按 finger index 各认各的手指。
## 相机把落在控件上的拖动交还给我们，否则推摇杆会同时转视角。

const STICK_RADIUS := 110.0
const JUMP_RADIUS := 56.0
const DEADZONE := 12.0
const GRAB_FACTOR := 1.6
const EDGE_MARGIN := 120.0

var move_input := Vector2.ZERO
var jump_pressed := false

var _stick_finger := -1
var _jump_finger := -1
var _stick_center := Vector2.ZERO
var _jump_center := Vector2.ZERO


static func safe_insets(screen: Vector2i, safe: Rect2i, viewport: Vector2) -> Vector2:
	if screen.x <= 0 or screen.y <= 0:
		return Vector2.ZERO
	var scale := viewport.x / float(screen.x)
	var left := maxf(0.0, float(safe.position.x) * scale)
	var right := maxf(0.0, float(screen.x - safe.position.x - safe.size.x) * scale)
	return Vector2(left, right)


static func joystick_vector(center: Vector2, touch: Vector2, radius: float, deadzone: float) -> Vector2:
	var delta := touch - center
	var length := delta.length()
	if length < deadzone:
		return Vector2.ZERO
	if length > radius:
		return delta.normalized()
	return delta / radius


func _ready() -> void:
	add_to_group("touch_controls")
	_layout()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()
		queue_redraw()


func _layout() -> void:
	var view := get_viewport_rect().size
	var insets := TouchControls.safe_insets(
		DisplayServer.screen_get_size(), DisplayServer.get_display_safe_area(), view
	)
	_stick_center = Vector2(
		insets.x + EDGE_MARGIN + STICK_RADIUS, view.y - EDGE_MARGIN - STICK_RADIUS
	)
	_jump_center = Vector2(
		view.x - insets.y - EDGE_MARGIN - JUMP_RADIUS, view.y - EDGE_MARGIN - JUMP_RADIUS
	)


func is_stick_finger(index: int) -> bool:
	return index >= 0 and index == _stick_finger


func is_on_control(pos: Vector2) -> bool:
	return (
		pos.distance_to(_stick_center) <= STICK_RADIUS * GRAB_FACTOR
		or pos.distance_to(_jump_center) <= JUMP_RADIUS * GRAB_FACTOR
	)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_on_press(event)
		else:
			_on_release(event)
	elif event is InputEventScreenDrag and event.index == _stick_finger:
		_update_stick(event.position)


func _on_press(event: InputEventScreenTouch) -> void:
	if _stick_finger < 0 and event.position.distance_to(_stick_center) <= STICK_RADIUS * GRAB_FACTOR:
		_stick_finger = event.index
		_update_stick(event.position)
	elif _jump_finger < 0 and event.position.distance_to(_jump_center) <= JUMP_RADIUS * GRAB_FACTOR:
		_jump_finger = event.index
		jump_pressed = true
		queue_redraw()


func _on_release(event: InputEventScreenTouch) -> void:
	if event.index == _stick_finger:
		_stick_finger = -1
		move_input = Vector2.ZERO
		queue_redraw()
	elif event.index == _jump_finger:
		_jump_finger = -1
		jump_pressed = false
		queue_redraw()


func _update_stick(position: Vector2) -> void:
	move_input = TouchControls.joystick_vector(_stick_center, position, STICK_RADIUS, DEADZONE)
	queue_redraw()


func _draw() -> void:
	draw_circle(_stick_center, STICK_RADIUS, Color(1, 1, 1, 0.16))
	draw_circle(_stick_center, STICK_RADIUS, Color(1, 1, 1, 0.35), false, 3.0)
	draw_circle(_stick_center + move_input * STICK_RADIUS, STICK_RADIUS * 0.42, Color(1, 1, 1, 0.55))
	var jump_alpha := 0.55 if jump_pressed else 0.22
	draw_circle(_jump_center, JUMP_RADIUS, Color(1, 1, 1, jump_alpha))
	draw_circle(_jump_center, JUMP_RADIUS, Color(1, 1, 1, 0.45), false, 3.0)
