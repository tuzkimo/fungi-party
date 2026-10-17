class_name Classroom
extends Node3D

## 教室编排：程序化建房间、摆四张课桌、驱动视线/人机/回合与结算。
## 自包含单场景：节点间直接引用，不跨场景查 group。

const FLOOR_COLOR := Color(0.62, 0.45, 0.30)
const WALL_COLOR := Color(0.93, 0.89, 0.80)
const BOARD_COLOR := Color(0.16, 0.32, 0.26)

var _gaze := Gaze.new()
var _round := StealEat.new()
var _eat := EatInput.new()
var _npcs: Array[NpcSeat] = []
var _press: Array[bool] = []
var _teacher: Teacher
var _seats: Array[SeatVisual] = []
var _settled := false

@onready var _camera: Camera3D = $Camera3D
@onready var _ui: ClassroomUI = $UI


func _ready() -> void:
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
		_npcs.append(NpcSeat.new(Config.NPC_GUTS[i], i + 11))

	_ui.again_pressed.connect(func() -> void: get_tree().reload_current_scene())
	_ui.forest_pressed.connect(func() -> void: get_tree().change_scene_to_file(Config.FOREST_PATH))


func _input(event: InputEvent) -> void:
	_eat.feed(event)


func _process(delta: float) -> void:
	_gaze.advance(delta)
	_teacher.apply(_gaze, delta)

	if not _round.over:
		_press[0] = _eat.pressing() or Input.is_action_pressed("jump")
		for i in _npcs.size():
			var seat_index: int = i + 1
			_press[seat_index] = _npcs[i].decide(delta, _gaze, seat_index, _round.seats[seat_index].stun > 0.0)
		var events := _round.tick(delta, _press, _gaze.watching())
		for caught in events["caught"]:
			if caught:
				_ui.flash()

	for i in _seats.size():
		var seat: StealEat.Seat = _round.seats[i]
		var eating: bool = _press[i] and seat.stun <= 0.0 and not seat.out
		_seats[i].apply(seat, eating, delta, _gaze.watching() == i)

	_ui.set_state(_round.time_left, _round.seats[0].bites, _round.seats[0].caught, _round.seats[0].stun > 0.0)

	if _round.over and not _settled:
		_settled = true
		var mine: StealEat.Seat = _round.seats[0]
		var won := _round.winner == 0
		var earned := int(Save.apply_round(mine.bites, won, mine.caught)["earned"])
		_ui.show_result(mine.bites, mine.caught, won, earned)


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
