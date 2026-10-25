class_name TouchControls
extends Control

## 每个玩家一组「摇杆 + 动作键」，按 finger index 各认各的手指。
## 单人：摇杆左下、动作键右下（老布局，手感不动）。
## 双人：一号位摇杆贴最左、动作键在中线左边；二号位镜像 —— 两人各用自己那半边。
## 森林里二号位不走路，那张场景把 duo 关掉，只画一号位那一组。

const STICK_RADIUS := 110.0
const ACTION_RADIUS := 56.0
const DEADZONE := 12.0
const GRAB_FACTOR := 1.6
const EDGE_MARGIN := 120.0
## 双人时动作键离屏幕中线多远：两个键之间的空隙就由它决定
const CENTER_GAP := 170.0

## 关掉 = 只摆一号位那一组（森林用）
@export var duo := true


class Arm extends RefCounted:
	var stick := Vector2.ZERO
	var action := Vector2.ZERO
	var stick_finger := -1
	var action_finger := -1
	var move := Vector2.ZERO
	var held := false


var _arms: Array[Arm] = []


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


## 每个玩家两个圆心：[摇杆, 动作键]。单人只返回一组，双人返回两组（左、右）。
static func arm_centers(view: Vector2, insets: Vector2, duo_mode: bool) -> Array:
	var stick_y := view.y - EDGE_MARGIN - STICK_RADIUS
	var action_y := view.y - EDGE_MARGIN - ACTION_RADIUS
	var left := insets.x + EDGE_MARGIN + STICK_RADIUS
	var right := view.x - insets.y - EDGE_MARGIN - STICK_RADIUS
	if not duo_mode:
		return [[Vector2(left, stick_y), Vector2(right, action_y)]]
	var mid := view.x * 0.5
	return [
		[Vector2(left, stick_y), Vector2(mid - CENTER_GAP, action_y)],
		[Vector2(right, stick_y), Vector2(mid + CENTER_GAP, action_y)],
	]


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
	# duo 只表示「这张场景允许双人」；真的摆两组还得有人坐在二号位
	var centers := TouchControls.arm_centers(view, insets, duo and Party.joined())
	# 组数变了（森林 ↔ 小游戏）就把多余的手指状态丢掉，别留着一个按死的键
	while _arms.size() > centers.size():
		var dropped: Arm = _arms.pop_back()
		dropped.stick_finger = -1
		dropped.action_finger = -1
		dropped.move = Vector2.ZERO
		dropped.held = false
	while _arms.size() < centers.size():
		_arms.append(Arm.new())
	for i in centers.size():
		_arms[i].stick = centers[i][0]
		_arms[i].action = centers[i][1]


func players() -> int:
	return _arms.size()


func move(player: int) -> Vector2:
	return _arms[player].move if player >= 0 and player < _arms.size() else Vector2.ZERO


func held(player: int) -> bool:
	return _arms[player].held if player >= 0 and player < _arms.size() else false


func is_stick_finger(index: int) -> bool:
	for arm in _arms:
		if index >= 0 and index == arm.stick_finger:
			return true
	return false


## 落在任何控件上的手指：相机不许拿它转视角（双人时二号位的摇杆也会转歪一号位的镜头）。
func is_control_finger(index: int) -> bool:
	for arm in _arms:
		if index >= 0 and (index == arm.stick_finger or index == arm.action_finger):
			return true
	return false


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_on_press(event)
		else:
			_on_release(event)
	elif event is InputEventScreenDrag:
		for arm in _arms:
			if arm.stick_finger == event.index:
				_update_stick(arm, event.position)
				return


func _on_press(event: InputEventScreenTouch) -> void:
	for arm in _arms:
		if arm.stick_finger < 0 and event.position.distance_to(arm.stick) <= STICK_RADIUS * GRAB_FACTOR:
			arm.stick_finger = event.index
			_update_stick(arm, event.position)
			return
	for arm in _arms:
		if (
			arm.action_finger < 0
			and event.position.distance_to(arm.action) <= ACTION_RADIUS * GRAB_FACTOR
		):
			arm.action_finger = event.index
			arm.held = true
			queue_redraw()
			return


func _on_release(event: InputEventScreenTouch) -> void:
	for arm in _arms:
		if event.index == arm.stick_finger:
			arm.stick_finger = -1
			arm.move = Vector2.ZERO
			queue_redraw()
		elif event.index == arm.action_finger:
			arm.action_finger = -1
			arm.held = false
			queue_redraw()


func _update_stick(arm: Arm, position: Vector2) -> void:
	arm.move = TouchControls.joystick_vector(arm.stick, position, STICK_RADIUS, DEADZONE)
	queue_redraw()


func _draw() -> void:
	for arm in _arms:
		draw_circle(arm.stick, STICK_RADIUS, Color(1, 1, 1, 0.16))
		draw_circle(arm.stick, STICK_RADIUS, Color(1, 1, 1, 0.35), false, 3.0)
		draw_circle(arm.stick + arm.move * STICK_RADIUS, STICK_RADIUS * 0.42, Color(1, 1, 1, 0.55))
		draw_circle(arm.action, ACTION_RADIUS, Color(1, 1, 1, 0.55 if arm.held else 0.22))
		draw_circle(arm.action, ACTION_RADIUS, Color(1, 1, 1, 0.45), false, 3.0)
