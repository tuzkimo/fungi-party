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
var _start_flash := 0.0

@onready var _camera: Camera3D = $Camera3D
@onready var _ui: ClassroomUI = $UI


func _bail_to_forest() -> void:
	get_tree().change_scene_to_file(Config.FOREST_PATH)


func _ready() -> void:
	if not Save.spend_stamina(Config.STAMINA_COST_CLASSROOM):
		# 体力不够就别开始，直接回森林；_ready 里换场景要延后
		call_deferred("_bail_to_forest")
		return
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

	_round.humans = Party.count()
	# 坐在座位上的玩家跟森林里长得一样（换场景后 Player 不在，座位才是「我」）
	for seat in Party.count():
		_seats[seat].apply_look(seat)

	_ui.again_pressed.connect(func() -> void: get_tree().reload_current_scene())
	_ui.forest_pressed.connect(func() -> void: get_tree().change_scene_to_file(Config.FOREST_PATH))


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
	if _countdown > 0.0:
		_countdown -= delta
		if _countdown > 0.0:
			_ui.show_countdown(str(ceili(_countdown)))
		else:
			_ui.show_countdown("开始！")
			_start_flash = START_FLASH
	elif _start_flash > 0.0:
		_start_flash -= delta
		if _start_flash <= 0.0:
			_ui.hide_countdown()
	else:
		_play(delta)

	for i in _seats.size():
		var seat: StealEat.Seat = _round.seats[i]
		var eating: bool = _press[i] and seat.stun <= 0.0 and not seat.out
		_seats[i].apply(seat, eating, delta, _gaze.watching() == i)

	_ui.set_state(_round.time_left, _player_rows(), _stunned())

	if _round.over and not _settled:
		_settle()


func _play(delta: float) -> void:
	_gaze.advance(delta)
	_teacher.apply(_gaze, delta)

	if not _round.over:
		# 双人各按自己那半边屏；单人时任意手指都算（老行为）
		_press[0] = _eat.pressing(0 if Party.joined() else -1) or Input.is_action_pressed("jump")
		if Party.joined():
			_press[1] = _eat.pressing(1)
		for i in _npcs.size():
			var seat_index: int = i + 1
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
	var out := []
	for seat in Party.count():
		out.append((_round.seats[seat] as StealEat.Seat).stun > 0.0)
	return out


## 结算：每个玩家各自算币，都进同一个钱包（一台手机一份存档，不拆）。
func _settle() -> void:
	_settled = true
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
