class_name Classroom
extends Node3D

## 教室编排：程序化建房间、摆四张课桌、驱动视线/人机/回合与结算。
## 自包含单场景：节点间直接引用，不跨场景查 group。

const FLOOR_COLOR := Color(0.62, 0.45, 0.30)
const WALL_COLOR := Color(0.93, 0.89, 0.80)
const BOARD_COLOR := Color(0.16, 0.32, 0.26)
const COUNTDOWN_SECONDS := 3.0
const START_FLASH := 0.5

var _gaze := Gaze.new(randi())
var _round := StealEat.new()
var _eat := EatInput.new()
var _npcs: Array[NpcSeat] = []
var _press: Array[bool] = []
var _teacher: Teacher
var _seats: Array[SeatVisual] = []
var _settled := false
var _countdown := COUNTDOWN_SECONDS
## 「开始！」闪一下的剩余时间：<0 还没闪，=0 闪完了
var _start_flash := -1.0
## 服务器把我拉进这一局了就是非空：这时规则在服务器跑，本机只画快照
var _net: NetClient = null
var _my_seat := 0
var _sent_press := false
var _seen_caught := 0

@onready var _camera: Camera3D = $Camera3D
@onready var _ui: ClassroomUI = $UI


func _bail_to_forest() -> void:
	get_tree().change_scene_to_file(Config.FOREST_PATH)


func _ready() -> void:
	_net = _joinable_room()
	if _net == null:
		if not Save.spend_stamina(Config.STAMINA_COST_CLASSROOM):
			# 体力不够就别开始，直接回森林；_ready 里换场景要延后
			call_deferred("_bail_to_forest")
			return
	else:
		# 这一局是服务器的：体力在成局那一下已经扣过，这里不重复扣
		_my_seat = _room_seat()
	Controls.ensure()
	_camera.look_at(Vector3(0.0, 0.8, -1.5))
	_build_room()

	_teacher = Teacher.new()
	_teacher.name = "Teacher"
	_teacher.position = Config.TEACHER_POS
	add_child(_teacher)

	for i in Config.SEAT_COUNT:
		var seat := SeatVisual.new()
		seat.name = "Seat%d" % i
		seat.setup(i)
		add_child(seat)
		_seats.append(seat)
		_press.append(false)

	for i in Config.NPC_GUTS.size():
		_npcs.append(NpcSeat.new(Config.NPC_GUTS[i], randi()))

	# 坐在座位上的玩家跟森林里长得一样（换场景后 Player 不在，座位才是「我」）
	if _net == null:
		_round.humans = Party.count()
		for seat in Party.count():
			_seats[seat].apply_look(seat)
	else:
		# 服务器那一局：人机数和座位表由服务器说了算，本地 2P 没有座位
		_round.humans = 0
		for seat_state in _net.session.get("seats", []):
			if not bool((seat_state as Dictionary).get("npc", false)):
				_round.humans += 1
		_seats[_my_seat].apply_look(0)

	_ui.again_pressed.connect(_on_again)
	_ui.forest_pressed.connect(_on_forest)


func _input(event: InputEvent) -> void:
	_eat.feed(event, get_viewport().get_visible_rect().size.x)


func _notification(what: int) -> void:
	# 系统抢走前台时抬手事件可能永远不来，不清掉就会一直「按着」
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_eat.clear()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		# 教室没有暂停面板：返回键还是直接退出，和以前一致
		get_tree().quit()


func _process(delta: float) -> void:
	if _net != null:
		_net_step(delta)
	else:
		_local_step(delta)

	for i in _seats.size():
		var seat: StealEat.Seat = _round.seats[i]
		var eating: bool = _press[i] and seat.stun <= 0.0 and not seat.out
		_seats[i].apply(seat, eating, delta, _gaze.watching() == i)

	_ui.set_state(_round.time_left, _player_rows(), _stunned())

	if _round.over and not _settled:
		_settle()


func _local_step(delta: float) -> void:
	if _countdown > 0.0:
		_countdown = maxf(0.0, _countdown - delta)
		_show_countdown(_countdown, delta)
	elif _start_flash != 0.0:
		_show_countdown(_countdown, delta)
	else:
		_play(delta)


## 服务器一局：把快照写进本地模型再照旧渲染，只上报「我按着」，不自己推进规则。
func _net_step(delta: float) -> void:
	var game: Dictionary = _net.session.get("game", {})
	if not game.is_empty():
		_countdown = float(game.get("countdown", 0.0))
		_apply_game(game, delta)
	# 服务器收局不一定是模型判的（有人走人、掉线、到硬顶）：只在 session 上置 over，
	# 这一格不认就会停在「时间 45」，结算面板永远不会出现
	_round.over = _round.over or bool(_net.session.get("over", false))
	_show_countdown(_countdown, delta)
	# 一台上一个人：整块屏都是自己的，不用分左右半
	_sent_press = _eat.pressing() or Input.is_action_pressed("jump")
	if _sent_press != _press[_my_seat]:
		_press[_my_seat] = _sent_press
		_net.send_input({"press": _sent_press})


## 倒数的显示本地一局和服务器一局长得一样：剩几秒 → 「开始！」闪一下 → 藏起来
func _show_countdown(remaining: float, delta: float) -> void:
	if remaining > 0.0:
		_ui.show_countdown(str(ceili(remaining)))
	elif _start_flash < 0.0:
		_ui.show_countdown("开始！")
		_start_flash = START_FLASH
	elif _start_flash > 0.0:
		_start_flash = maxf(0.0, _start_flash - delta)
		if _start_flash == 0.0:
			_ui.hide_countdown()


## 把服务器快照写进本地这几个对象（只写不推，规则全在服务器）
func _apply_game(game: Dictionary, delta: float) -> void:
	_round.time_left = float(game.get("time_left", _round.time_left))
	_round.over = bool(game.get("over", false))
	_round.winner = int(game.get("winner", -1))
	var states: Array = game.get("seats", [])
	for i in mini(states.size(), _round.seats.size()):
		var state: Dictionary = states[i]
		var seat: StealEat.Seat = _round.seats[i]
		seat.bites = int(state.get("bites", 0))
		seat.fill = float(state.get("fill", 0.0))
		seat.caught = int(state.get("caught", 0))
		seat.stun = float(state.get("stun", 0.0))
		seat.out = bool(state.get("out", false))
	var gaze: Dictionary = game.get("gaze", {})
	_gaze.phase = int(gaze.get("phase", Gaze.Phase.AWAY))
	_gaze.target = int(gaze.get("target", 0))
	_gaze.time_left = float(gaze.get("left", 0.0))
	_teacher.apply(_gaze, delta)
	var mine: StealEat.Seat = _round.seats[_my_seat]
	if mine.caught > _seen_caught:
		_seen_caught = mine.caught
		_ui.flash()


## 服务器那份 session 是不是「我该进这间教室」：只在 _ready 判一次，
## 局结束（over）之后还得继续按服务器那套画，不能又退回本地自己算。
func _joinable_room() -> NetClient:
	var net := get_tree().root.get_node_or_null("Net") as NetClient
	if net == null or not net.ready():
		return null
	if str(net.session.get("kind", "")) != "classroom" or bool(net.session.get("over", false)):
		return null
	return net


func _room_seat() -> int:
	var seats: Array = _net.session.get("seats", [])
	for i in seats.size():
		if str(seats[i].get("account", "")) == _net.player_name:
			return i
	return 0


func _on_again() -> void:
	_release_room()
	if _net != null:
		# 服务器那一局没法在本机重开：新一局要从森林重新邀请
		get_tree().change_scene_to_file(Config.FOREST_PATH)
		return
	get_tree().reload_current_scene()


func _on_forest() -> void:
	_release_room()
	get_tree().change_scene_to_file(Config.FOREST_PATH)


## 主动离开这一局：让服务器把房腾出来（否则「同时一间房」会被一次旧局占住）
func _release_room() -> void:
	if _net != null:
		_net.request("leave_room", {})


func _play(delta: float) -> void:
	_gaze.advance(delta)
	_teacher.apply(_gaze, delta)

	if not _round.over:
		# 双人各按自己那半边屏；单人时任意手指都算（老行为）
		_press[0] = _eat.pressing(0 if Party.joined() else -1) or Input.is_action_pressed("jump")
		if Party.joined():
			_press[1] = _eat.pressing(1)
		for i in _npcs.size():
			var seat_index: int = _round.humans + i
			if seat_index >= Config.SEAT_COUNT:
				break
			if Party.human(seat_index):
				continue   # 这个座位是人，不喂人机
			_press[seat_index] = _npcs[i].decide(delta, _gaze, seat_index, _round.seats[seat_index].stun > 0.0)
		var events := _round.tick(delta, _press, _gaze.watching())
		for seat in Party.count():
			if events["caught"][seat]:
				_ui.flash()
				break


## 每个玩家的成绩：UI 只认这个。
func _player_rows() -> Array:
	if _net != null:
		var rows := []
		var seats: Array = _net.session.get("seats", [])
		for i in mini(seats.size(), _round.seats.size()):
			if bool(seats[i].get("npc", false)):
				continue
			var mine: StealEat.Seat = _round.seats[i]
			rows.append({
				"name": str(seats[i].get("account", "")),
				"bites": mine.bites,
				"caught": mine.caught,
				"win": _round.winner == i,
			})
		return rows
	var rows := []
	for seat in Party.count():
		var mine: StealEat.Seat = _round.seats[seat]
		rows.append({
			"name": Party.name_of(seat),
			"bites": mine.bites,
			"caught": mine.caught,
			"win": _round.winner == seat,
		})
	return rows


func _stunned() -> Array:
	if _net != null:
		return [(_round.seats[_my_seat] as StealEat.Seat).stun > 0.0]
	var out := []
	for seat in Party.count():
		out.append((_round.seats[seat] as StealEat.Seat).stun > 0.0)
	return out


## 结算：每个玩家各自算币，都进同一个钱包（一台手机一份存档，不拆）。
func _settle() -> void:
	_settled = true
	if _net != null:
		# 币是服务器结的，这里只放演出
		var earned_online := int((_net.session.get("earned", {}) as Dictionary).get(_net.player_name, 0))
		_ui.show_result(_player_rows(), earned_online)
		return
	var earned := 0
	for seat in Party.count():
		var mine: StealEat.Seat = _round.seats[seat]
		earned += int(Save.apply_round(mine.bites, _round.winner == seat, mine.caught)["earned"])
	_ui.show_result(_player_rows(), earned)


func _build_room() -> void:
	var floor_mat := _solid(FLOOR_COLOR)
	var wall_mat := _solid(WALL_COLOR)
	_box("Floor", Vector3(14.0, 0.2, 16.0), Vector3(0.0, -0.1, -1.0), floor_mat)
	_box("BackWall", Vector3(14.0, 4.0, 0.2), Vector3(0.0, 2.0, -9.0), wall_mat)
	_box("WallLeft", Vector3(0.2, 4.0, 16.0), Vector3(-7.0, 2.0, -1.0), wall_mat)
	_box("WallRight", Vector3(0.2, 4.0, 16.0), Vector3(7.0, 2.0, -1.0), wall_mat)
	_box("Ceiling", Vector3(14.0, 0.2, 16.0), Vector3(0.0, 4.0, -1.0), wall_mat)
	_box("Blackboard", Vector3(6.0, 2.6, 0.1), Vector3(0.0, 1.8, -8.85), _solid(BOARD_COLOR))

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-50.0, -30.0, 0.0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 20.0
	add_child(sun)

	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	var world := WorldEnvironment.new()
	world.name = "Environment"
	world.environment = env
	add_child(world)


func _box(node_name: String, size: Vector3, pos: Vector3, material: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = pos
	node.material_override = material
	add_child(node)


func _solid(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.95
	return material
