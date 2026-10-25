class_name RacePlayer
extends CharacterBody3D

## 赛跑里的玩家：真实物理，撞到 hazard 组的东西就弹开 + 硬直。
## 只认 feed() 给的输入向量/按钮，输入源是谁（键盘、摇杆、按钮）不归它管。

const CAPSULE_RADIUS := 0.45
const CAPSULE_HEIGHT := 1.5
const LAND_SECONDS := 0.15
const DASH_STRETCH := 0.18
const HIT_SQUASH := 0.2

var hits := 0
var finished := false
var finish_time := 0.0
var freeze := 0.0
var dash_left := 0.0
var dash_cd := 0.0

var _move := Vector2.ZERO
var _want_jump := false
var _want_dash := false
var _visual: MushroomMesh
var _land_timer := 0.0
var _was_on_floor := true
var _walk_phase := 0.0


func _ready() -> void:
	add_to_group("race_player")
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = CAPSULE_RADIUS
	capsule.height = CAPSULE_HEIGHT
	shape.shape = capsule
	shape.position.y = CAPSULE_HEIGHT * 0.5
	add_child(shape)

	_visual = MushroomMesh.new()
	_visual.name = "MushroomMesh"
	_visual.use_saved_look()
	add_child(_visual)


## 每帧由 race.gd 喂一次；jump/dash 是「这一帧按下了」的意思，不是按住。
func feed(move: Vector2, jump: bool, dash: bool) -> void:
	_move = move if move.length() <= 1.0 else move.normalized()
	_want_jump = _want_jump or jump
	_want_dash = _want_dash or dash


func _physics_process(delta: float) -> void:
	dash_cd = maxf(0.0, dash_cd - delta)

	if freeze > 0.0:
		# 硬直期间不读输入也不留速度，解冻后从 0 起
		freeze = maxf(0.0, freeze - delta)
		velocity.x = 0.0
		velocity.z = 0.0
		if not is_on_floor():
			velocity.y -= Config.GRAVITY * delta
		else:
			velocity.y = 0.0
		move_and_slide()
		return

	if _want_dash and dash_cd <= 0.0 and dash_left <= 0.0:
		dash_left = Config.RACE_DASH_SECONDS
		dash_cd = Config.RACE_DASH_COOLDOWN
	_want_dash = false

	var speed := Config.RACE_BASE_SPEED
	if dash_left > 0.0:
		speed = Config.RACE_DASH_SPEED
		dash_left = maxf(0.0, dash_left - delta)

	# 镜头朝 +z 时画面右是 -x，所以摇杆的 x 要取反
	var direction := Vector3(-_move.x, 0.0, -_move.y)
	var horizontal := Movement.accelerate(
		Vector3(velocity.x, 0.0, velocity.z), direction * speed, Config.ACCEL, Config.DECEL, delta
	)
	velocity.x = horizontal.x
	velocity.z = horizontal.z

	var on_floor := is_on_floor()
	if on_floor and velocity.y < 0.0:
		velocity.y = 0.0
	if not on_floor:
		velocity.y -= Config.GRAVITY * delta
	if on_floor and _want_jump:
		velocity.y = Movement.jump_velocity(Config.GRAVITY, Config.JUMP_HEIGHT)
	_want_jump = false

	move_and_slide()
	_check_hits()

	if position.z >= Config.RACE_TRACK_LENGTH and not finished:
		finished = true

	if is_on_floor() and not _was_on_floor:
		_land_timer = LAND_SECONDS
	_was_on_floor = is_on_floor()

	_turn(direction, delta)
	_animate(horizontal.length(), delta)


func _check_hits() -> void:
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var body := collision.get_collider()
		if body is Node and (body as Node).is_in_group("hazard"):
			# 踩在障碍顶上不算撞：法线朝上的弹开会把人越弹越高
			if collision.get_normal().y > 0.7:
				continue
			hits += 1
			global_position += collision.get_normal() * Config.RACE_HIT_PUSH
			velocity = Vector3.ZERO
			dash_left = 0.0
			freeze = Config.RACE_HIT_FREEZE
			return


func _turn(direction: Vector3, delta: float) -> void:
	if direction.length() < 0.1:
		return
	rotation.y = lerp_angle(rotation.y, atan2(direction.x, direction.z), minf(1.0, 12.0 * delta))


func _animate(speed: float, delta: float) -> void:
	var squash := Movement.squash_stretch(velocity.y, Config.SQUASH_MAX)
	if _land_timer > 0.0:
		_land_timer = maxf(0.0, _land_timer - delta)
		var k := _land_timer / LAND_SECONDS
		squash = Vector3(1.0 + 0.15 * k, 1.0 - 0.15 * k, 1.0 + 0.15 * k)
	if freeze > 0.0:
		squash = Vector3.ONE * (1.0 + HIT_SQUASH * 0.5)
		squash.y = 1.0 - HIT_SQUASH
	elif dash_left > 0.0:
		squash = Vector3(1.0 - DASH_STRETCH, 1.0 + DASH_STRETCH, 1.0 - DASH_STRETCH)
	_visual.scale = squash

	if is_on_floor() and speed > 0.2:
		_walk_phase += delta * speed * 3.0
		_visual.position.y = absf(sin(_walk_phase)) * 0.06
	else:
		_visual.position.y = 0.0
