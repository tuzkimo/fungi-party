class_name Player
extends CharacterBody3D

## 编排层：读输入、走 Movement 的数学、驱动外观动画。
## 不引用任何具体 mesh 节点名字，只认 MushroomMesh 的 scale / position。

@onready var _visual: MushroomMesh = $MushroomMesh
@onready var _cam: CamRig = $CamRig

var speed_input := Vector2.ZERO
var _touch: TouchControls = null
var _prev_touch_jump := false
var _was_on_floor := true
var _land_timer := 0.0
var _walk_phase := 0.0


static func resolve_direction(input: Vector2, camera_yaw: float) -> Vector3:
	var dir := Vector3(input.x, 0.0, input.y)
	if dir.length() > 1.0:
		dir = dir.normalized()
	return dir.rotated(Vector3.UP, camera_yaw)


func _ready() -> void:
	Controls.ensure()
	add_to_group("player")
	apply_skin()


## 有皮肤且已穿戴时，把皮肤的三个数写进外观再重建一次。
func apply_skin() -> void:
	if not bool(Save.read()["equipped"]):
		return
	var skin := load(Config.SKIN_PATH) as MushroomSkin
	if skin == null:
		return
	_visual.tint_cap = skin.tint_cap
	_visual.tint_body = skin.tint_body
	_visual.spot_count = skin.spot_count
	_visual.build()


func _find_touch() -> void:
	# main.tscn 里 TouchControls 排在 Forest 之后，Player._ready 时它还没 add_to_group，
	# 只在 _ready 里找一次会永远是 null。惰性取，取到为止。
	if _touch != null:
		return
	_touch = get_tree().get_first_node_in_group("touch_controls") as TouchControls
	if _touch != null:
		print("touch controls wired")


func _physics_process(delta: float) -> void:
	_find_touch()
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var want_jump := Input.is_action_just_pressed("jump")
	if _touch != null:
		if _touch.move_input.length() > 0.05:
			input = _touch.move_input
		if _touch.jump_pressed and not _prev_touch_jump:
			want_jump = true
		_prev_touch_jump = _touch.jump_pressed
	speed_input = input

	var on_floor := is_on_floor()
	var speed := Config.RUN_SPEED if Input.is_action_pressed("run") else Config.WALK_SPEED
	var dir := Player.resolve_direction(input, _cam.global_rotation.y)

	var accel := Config.ACCEL if on_floor else Config.ACCEL * Config.AIR_CONTROL
	var horizontal := Movement.accelerate(
		Vector3(velocity.x, 0.0, velocity.z), dir * speed, accel, Config.DECEL, delta
	)
	velocity.x = horizontal.x
	velocity.z = horizontal.z

	if on_floor and velocity.y < 0.0:
		velocity.y = 0.0
	elif not on_floor:
		velocity.y -= Config.GRAVITY * delta
	if on_floor and want_jump:
		velocity.y = Movement.jump_velocity(Config.GRAVITY, Config.JUMP_HEIGHT)

	move_and_slide()

	if is_on_floor() and not _was_on_floor:
		_land_timer = 0.15
	_was_on_floor = is_on_floor()

	_turn(dir, delta)
	_animate(horizontal.length(), delta)


func _turn(dir: Vector3, delta: float) -> void:
	if dir.length() < 0.1:
		return
	rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), minf(1.0, 12.0 * delta))


func _animate(speed: float, delta: float) -> void:
	var squash := Movement.squash_stretch(velocity.y, Config.SQUASH_MAX)
	if _land_timer > 0.0:
		_land_timer = maxf(0.0, _land_timer - delta)
		var k := _land_timer / 0.15
		squash = Vector3(1.0 + 0.15 * k, 1.0 - 0.15 * k, 1.0 + 0.15 * k)
	_visual.scale = squash

	if is_on_floor() and speed > 0.2:
		_walk_phase += delta * speed * 3.0
		_visual.position.y = absf(sin(_walk_phase)) * 0.06
	else:
		_visual.position.y = 0.0
