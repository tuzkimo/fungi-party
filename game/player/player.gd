extends CharacterBody3D

## 编排层：读输入、走 Movement 的数学、驱动外观动画。
## 不引用任何具体 mesh 节点名字，只认 MushroomMesh 的 scale / position。

@onready var _visual: MushroomMesh = $MushroomMesh

var speed_input := Vector2.ZERO
var _was_on_floor := true
var _land_timer := 0.0
var _walk_phase := 0.0


func _ready() -> void:
	Controls.ensure()


func _physics_process(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	speed_input = input

	var on_floor := is_on_floor()
	var speed := Config.RUN_SPEED if Input.is_action_pressed("run") else Config.WALK_SPEED
	var dir := Vector3(input.x, 0.0, input.y)
	if dir.length() > 1.0:
		dir = dir.normalized()

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
	if on_floor and Input.is_action_just_pressed("jump"):
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
