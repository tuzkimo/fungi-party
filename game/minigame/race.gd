extends Node3D

## 赛跑编排：按种子建赛道、摆玩家、喂输入、跟相机。
## 自包含单场景：节点间直接引用。每局新种子（RaceField.new(randi())），绝不写死。

const COUNTDOWN_SECONDS := 3.0
const START_FLASH := 0.5
const CAMERA_HEIGHT := 3.5
const CAMERA_BACK := 7.0
const RIVAL_STYLES := [RaceRacer.Style.STEADY, RaceRacer.Style.HUGGER, RaceRacer.Style.DASHER]
const RIVAL_X := [-2.5, 0.0, 2.5]
const RIVAL_Z_STEP := 0.6
const PINE_SIZE := 0.6
const PINE_COLOR := Color(0.42, 0.30, 0.16)

var _field := RaceField.new(randi())
var _player: RacePlayer
var _camera: Camera3D
var _ui: RaceUI
var _touch: TouchControls
var _rivals: Array[RaceRacer] = []
var _rival_visuals: Array[RacerVisual] = []
var _animals: Array[AnimalActor] = []
var _dropped: Array[bool] = []
var _elapsed := 0.0
var _countdown := COUNTDOWN_SECONDS
var _start_flash := 0.0
var _touch_jump := false
var _dash_requested := false
var _settled := false


func _ready() -> void:
	Controls.ensure()
	_camera = $Camera3D
	_ui = $UI

	var course := RaceCourse.new()
	course.name = "Course"
	add_child(course)
	course.build(_field)

	_player = RacePlayer.new()
	_player.name = "Player"
	add_child(_player)
	_spawn_rivals()
	_spawn_animals()
	_follow_player()

	_ui.again_pressed.connect(func() -> void: get_tree().reload_current_scene())
	_ui.forest_pressed.connect(func() -> void: get_tree().change_scene_to_file(Config.FOREST_PATH))
	_ui.dash_pressed.connect(func() -> void: _dash_requested = true)

	var layout := PackedStringArray()
	for group in _field.groups:
		layout.append("%.1f/%d" % [group.z, group.kind])
	print("赛道布局：%s" % " ".join(layout))


func _physics_process(delta: float) -> void:
	if _countdown > 0.0:
		# 倒数期间不喂输入、不计时，人机也不动
		_countdown -= delta
		if _countdown > 0.0:
			_ui.show_countdown(str(ceili(_countdown)))
		else:
			_ui.show_countdown("开始！")
			_start_flash = START_FLASH
		return
	if _start_flash > 0.0:
		_start_flash -= delta
		if _start_flash <= 0.0:
			_ui.hide_countdown()
	if _settled:
		return

	_elapsed += delta
	_feed()
	_update_actors(delta)
	if _player.finished and _player.finish_time <= 0.0:
		_player.finish_time = _elapsed
	_follow_player()
	_update_hud()
	_settle_if_over()


func _spawn_rivals() -> void:
	for i in RIVAL_STYLES.size():
		var racer := RaceRacer.new(RIVAL_STYLES[i], randi())
		racer.x = RIVAL_X[i]
		racer.z = RIVAL_Z_STEP * float(i + 1)
		_rivals.append(racer)
		var visual := RacerVisual.new()
		visual.name = "Rival%d" % i
		add_child(visual)
		visual.setup(RaceUI.RIVAL_COLORS[i])
		visual.apply(racer)
		_rival_visuals.append(visual)


func _spawn_animals() -> void:
	for i in _field.crossings.size():
		var crossing: RaceField.Crossing = _field.crossings[i]
		var animal := AnimalActor.new()
		animal.name = "Animal%d" % i
		add_child(animal)
		animal.setup(crossing.kind, crossing.side, crossing.z)
		animal.advance(-1.0)
		_animals.append(animal)
		_dropped.append(false)


func _update_actors(delta: float) -> void:
	for i in _rivals.size():
		_rivals[i].advance(delta, _field, _elapsed)
		_rival_visuals[i].apply(_rivals[i])
	for i in _animals.size():
		var crossing: RaceField.Crossing = _field.crossings[i]
		_animals[i].advance(_elapsed - crossing.time)
		_drop_pinecone(i, crossing)


## 松鼠横穿到一半时把松果丢在中线，整局留在原地。
func _drop_pinecone(index: int, crossing: RaceField.Crossing) -> void:
	if _dropped[index] or crossing.kind != RaceField.SQUIRREL:
		return
	if _elapsed < crossing.time + Config.RACE_ANIMAL_WARN + RaceField.WALK_IN:
		return
	_dropped[index] = true
	var pine := StaticBody3D.new()
	pine.name = "Pinecone%d" % index
	pine.add_to_group("hazard")
	pine.position = Vector3(0.0, PINE_SIZE * 0.5, crossing.z)
	add_child(pine)

	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3.ONE * PINE_SIZE
	mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = PINE_COLOR
	material.roughness = 0.9
	mesh.material_override = material
	pine.add_child(mesh)

	var shape := CollisionShape3D.new()
	var shape_box := BoxShape3D.new()
	shape_box.size = Vector3.ONE * PINE_SIZE
	shape.shape = shape_box
	pine.add_child(shape)


func _feed() -> void:
	var move := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var jump := Input.is_action_just_pressed("jump")
	var dash := Input.is_action_just_pressed("run") or _dash_requested
	_dash_requested = false
	_find_touch()
	if _touch != null:
		if _touch.move_input.length() > 0.05:
			move = _touch.move_input
		if _touch.jump_pressed and not _touch_jump:
			jump = true
		_touch_jump = _touch.jump_pressed
	_player.feed(move, jump, dash)


func _find_touch() -> void:
	if _touch == null:
		_touch = get_tree().get_first_node_in_group("touch_controls") as TouchControls


func _update_hud() -> void:
	_ui.set_time(_elapsed)
	_ui.set_progress(_player.position.z, _rivals, _current_rank())
	var ratio := 1.0
	if _player.dash_cd > 0.0:
		ratio = 1.0 - _player.dash_cd / Config.RACE_DASH_COOLDOWN
	_ui.set_dash_ready(ratio)


func _player_entry() -> Dictionary:
	return {"finished": _player.finished, "finish_time": _player.finish_time, "z": _player.position.z}


func _current_rank() -> int:
	var entries: Array = [_player_entry()]
	for rival in _rivals:
		entries.append(rival)
	return RaceScore.ranking(entries).find(0) + 1


## 玩家冲线或超时立即结算：算名次、入库、弹面板。
func _settle_if_over() -> void:
	if not _player.finished and _elapsed < Config.RACE_TIME_LIMIT:
		return
	_settled = true
	var entries: Array = [_player_entry()]
	for rival in _rivals:
		entries.append(rival)
	var rank := RaceScore.ranking(entries).find(0)
	var earned := RaceScore.coins(rank, _player.hits)
	Save.add_coins(earned)
	var seconds := _player.finish_time if _player.finished else _elapsed
	_ui.show_result(rank + 1, seconds, _player.hits, earned)


## 镜头锁死朝前：只平移，不转、不抖。
func _follow_player() -> void:
	_camera.position = Vector3(_player.position.x, CAMERA_HEIGHT, _player.position.z + CAMERA_BACK)
