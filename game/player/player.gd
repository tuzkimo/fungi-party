class_name Player
extends CharacterBody3D

## 编排层：读输入、走 Movement 的数学、驱动外观动画。
## 不引用任何具体 mesh 节点名字，只认 MushroomMesh 的 scale / position。
##
## 同屏双人里二号位是同一个类：seat = 1、leader = 一号位。有 leader 就追到 leader 身后。
## 森林里谁推摇杆谁带队（镜头跟着带队的那个），见 main.gd 的 _physics_process。

@onready var _visual: MushroomMesh = $MushroomMesh
@onready var _cam: CamRig = $CamRig

## 第几位玩家（Party 的座位号）：决定长什么样
var seat := 0
## 非空就进「跟随」模式：不读输入，追这个节点的身后
var leader: Node3D = null

var speed_input := Vector2.ZERO
var _touch: TouchControls = null
var _prev_touch_held := false
var _was_on_floor := true
var _land_timer := 0.0
var _walk_phase := 0.0
var _chew := -1.0   # >= 0 表示正在吃饭，-1 表示没在咬


static func resolve_direction(input: Vector2, camera_yaw: float) -> Vector3:
	var dir := Vector3(input.x, 0.0, input.y)
	if dir.length() > 1.0:
		dir = dir.normalized()
	return dir.rotated(Vector3.UP, camera_yaw)


## 跟随方向：已经站在目标点附近就停下（零向量），否则朝目标走。
static func follow_direction(from: Vector3, to: Vector3, stop: float) -> Vector3:
	var offset := to - from
	offset.y = 0.0
	if offset.length() <= stop:
		return Vector3.ZERO
	return offset.normalized()


## 抢方向盘：现在的领队没推摇杆、另一个人推了，就该换人带队。
static func should_swap(lead_input: bool, other_input: bool) -> bool:
	return other_input and not lead_input


## 某号座位的玩家（森林里可能同时有两个，别拿组里第一个凑数）。
static func of_seat(tree: SceneTree, seat: int) -> Player:
	if tree == null:
		return null
	for node in tree.get_nodes_in_group("player"):
		var player := node as Player
		if player != null and player.seat == seat:
			return player
	return null


## 跟随者要去的点：leader 身后 gap 米、往侧面再让开 side 米。
## Node3D 的 +Z 是背后（前方是 -Z）；正后方会正好夹在相机和 leader 中间，
## 把镜头射线顶到最短距离、糊满整块屏，所以默认往侧面让开。
static func follow_point(leader_position: Vector3, leader_basis: Basis, gap: float, side := 0.0) -> Vector3:
	return (
		leader_position
		+ leader_basis.z.normalized() * gap
		+ leader_basis.x.normalized() * side
	)


func _ready() -> void:
	Controls.ensure()
	add_to_group("player")
	set_leading(leader == null)
	apply_skin()


## 带队的人拿镜头；跟着的那个把镜头熄掉，别白做射线、也别抢拖动事件。
func set_leading(leading: bool) -> void:
	if _cam != null:
		_cam.set_active(leading)


## 自己这一帧推了摇杆没有。跟随者只认自己那半边。
func wants_to_lead() -> bool:
	_find_touch()
	return _read_input().length() > 0.05


## 按会话状态把外观刷成「该座位玩家戴着的皮肤 + 选的角色」。
func apply_skin() -> void:
	_visual.use_party_look(seat)


func is_follower() -> bool:
	return leader != null


func _find_touch() -> void:
	# main.tscn 里 TouchControls 排在 Forest 之后，Player._ready 时它还没 add_to_group，
	# 只在 _ready 里找一次会永远是 null。惰性取，取到为止。
	if _touch != null:
		return
	_touch = get_tree().get_first_node_in_group("touch_controls") as TouchControls
	if _touch != null:
		print("touch controls wired")


func _physics_process(delta: float) -> void:
	var dir := Vector3.ZERO
	var speed := Config.WALK_SPEED
	var want_jump := false
	if leader != null and is_instance_valid(leader):
		speed = _follow_speed()
		dir = _follow_direction()
		speed_input = Vector2(dir.x, dir.z)
	else:
		_find_touch()
		var input := _read_input()
		want_jump = _take_touch_jump()
		speed_input = input
		speed = Config.RUN_SPEED if Input.is_action_pressed("run") else Config.WALK_SPEED
		dir = Player.resolve_direction(input, _cam.global_rotation.y if _cam != null else 0.0)

	var on_floor := is_on_floor()
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


## 摇杆优先，键盘只给一号位兜底。
func _read_input() -> Vector2:
	var input := Vector2.ZERO
	if seat == 0:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if _touch != null and _touch.move(seat).length() > 0.05:
		input = _touch.move(seat)
	return input


## 动作键记的是「按着」，跳跃要的是「这一帧刚按下」，边沿检测在这做。
func _take_touch_jump() -> bool:
	var want := seat == 0 and Input.is_action_just_pressed("jump")
	if _touch == null:
		return want
	var held := _touch.held(seat)
	if held and not _prev_touch_held:
		want = true
	_prev_touch_held = held
	return want


## 走到一号位身后就停；已经贴到一号位跟前时也别再往前顶（会被推着往前跑）。
func _follow_direction() -> Vector3:
	var to_leader := leader.global_position - global_position
	to_leader.y = 0.0
	if to_leader.length() <= Config.PARTY_FOLLOW_STOP:
		return Vector3.ZERO
	return Player.follow_direction(
		global_position,
		Player.follow_point(
			leader.global_position, leader.global_basis,
			Config.PARTY_FOLLOW_GAP, Config.PARTY_FOLLOW_SIDE
		),
		Config.PARTY_FOLLOW_STOP
	)


## 被甩开就用跑的，贴着就走的。
func _follow_speed() -> float:
	if global_position.distance_to(leader.global_position) > Config.PARTY_FOLLOW_RUN:
		return Config.RUN_SPEED
	return Config.WALK_SPEED


## 咬三口：挤压力和走路的 squash 相乘，别把走路的挤掉。
func chew() -> void:
	_chew = 0.0


func _turn(dir: Vector3, delta: float) -> void:
	if dir.length() < 0.1:
		return
	rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), minf(1.0, 12.0 * delta))


func _animate(speed: float, delta: float) -> void:
	var squash := Movement.squash_stretch(velocity.y, Config.SQUASH_MAX)
	if _chew >= 0.0:
		_chew += delta
		squash = squash * Movement.chew_scale(_chew)
		if _chew > Config.MEAL_ANIMATION_SECONDS:
			_chew = -1.0
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
