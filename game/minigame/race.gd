extends Node3D

## 赛跑编排：按种子建赛道、摆玩家、喂输入、跟相机。
## 自包含单场景：节点间直接引用。每局新种子（RaceField.new(randi())），绝不写死。

const COUNTDOWN_SECONDS := 3.0
const START_FLASH := 0.5
const CAMERA_HEIGHT := 3.5
const CAMERA_BACK := 7.0
const RIVAL_STYLES := [RaceRacer.Style.STEADY, RaceRacer.Style.HUGGER, RaceRacer.Style.DASHER]
const RIVAL_NAMES := ["稳中型", "贴边型", "冲动型"]
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


func _bail_to_forest() -> void:
	get_tree().change_scene_to_file(Config.FOREST_PATH)


func _ready() -> void:
	if not Save.spend_stamina(Config.STAMINA_COST_RACE):
		# 体力不够就别开始，直接回森林；_ready 里换场景要延后，
		# 这期间 UI 还没建好，别再 tick
		set_physics_process(false)
		call_deferred("_bail_to_forest")
		return
	Controls.ensure()
	_camera = $Camera3D
	_ui = $UI
	# 镜头在玩家脑后朝前，俯角固定：只定一次朝向，之后每帧只平移
	_camera.position = Vector3(0.0, CAMERA_HEIGHT, -CAMERA_BACK)
	_camera.look_at(Vector3(0.0, 0.8, 10.0))

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

	_ui.again_pressed.connect(_restart)
	_ui.forest_pressed.connect(_to_forest)
	_ui.quit_pressed.connect(_quit)
	_ui.dash_pressed.connect(func() -> void: _dash_requested = true)

	var layout := PackedStringArray()
	for group in _field.groups:
		layout.append("%.1f/%d" % [group.z, group.kind])
	print("赛道布局：%s" % " ".join(layout))


func _physics_process(delta: float) -> void:
	if _countdown > 0.0:
		# 倒数期间不喂输入、不计时，人机也不动；按下的冲刺作废
		_dash_requested = false
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


## 玩家冲线、前三名都定了、或超时 → 立即结算（不等最后一名跑完）。
func _settle_if_over() -> void:
	var entries: Array = [_player_entry()]
	for rival in _rivals:
		entries.append(rival)
	if not _player.finished and not RaceScore.decided(entries) and _elapsed < Config.RACE_TIME_LIMIT:
		return
	_settled = true
	_player.feed(Vector2.ZERO, false, false)
	var order := RaceScore.ranking(entries)
	var rank: int = order.find(0)
	var earned := RaceScore.coins(rank, _player.hits)
	Save.add_coins(earned)
	var seconds := _player.finish_time if _player.finished else _elapsed
	_ui.show_result(rank + 1, seconds, _player.hits, earned, _standings(entries, order))


## 结算面板上的名次表：按名次排好，名字 + 时间（没跑完的写未完赛）。
func _standings(entries: Array, order: Array) -> Array:
	var rows := []
	for index in order:
		var racer: Variant = entries[index]
		rows.append({
			"name": _racer_name(index),
			"finished": bool(racer["finished"]),
			"time": float(racer["finish_time"]),
		})
	return rows


func _racer_name(index: int) -> String:
	return "你" if index == 0 else RIVAL_NAMES[index - 1]


## 返回键：先弹暂停面板（再按一次继续），不直接把整个应用退掉。
func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_GO_BACK_REQUEST or _settled:
		return
	if get_tree().paused:
		get_tree().paused = false
		_ui.hide_pause()
	else:
		_ui.show_pause()
		get_tree().paused = true


func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _to_forest() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(Config.FOREST_PATH)


func _quit() -> void:
	get_tree().paused = false
	get_tree().quit()


## 镜头锁死朝前：只平移，不转、不抖。
func _follow_player() -> void:
	_camera.position = Vector3(_player.position.x, CAMERA_HEIGHT, _player.position.z - CAMERA_BACK)
