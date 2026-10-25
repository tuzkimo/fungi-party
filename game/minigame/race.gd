extends Node3D

## 赛跑编排：按种子建赛道、摆玩家、喂输入、跟相机。
## 自包含单场景：节点间直接引用。每局新种子（RaceField.new(randi())），绝不写死。
## 同屏双人时两个 RacePlayer 各跑各的：屏幕左右各一半，每人一台相机跟着自己跑。

const COUNTDOWN_SECONDS := 3.0
const START_FLASH := 0.5
const CAMERA_HEIGHT := 3.5
const CAMERA_BACK := 7.0
## look_at 只用来定俯角：之后每帧只平移
const CAMERA_LOOK := Vector3(0.0, 0.8, 10.0)
## 分屏后每边只有半个屏幕宽：相机拉远、视角开一点，7 米外的整条赛道才还在视野里
const DUO_CAMERA_HEIGHT := 4.4
const DUO_CAMERA_BACK := 9.5
const DUO_FOV := 78.0
## 两个人在起跑线各站一条道，别叠在一起
const DUO_X := [-1.6, 1.6]
const RIVAL_STYLES := [RaceRacer.Style.STEADY, RaceRacer.Style.HUGGER, RaceRacer.Style.DASHER]
const RIVAL_NAMES := ["稳中型", "贴边型", "冲动型"]
const RIVAL_X := [-2.5, 0.0, 2.5]
const RIVAL_Z_STEP := 0.6
const PINE_SIZE := 0.6
const PINE_COLOR := Color(0.42, 0.30, 0.16)

var _field := RaceField.new(randi())
var _players: Array[RacePlayer] = []
var _cameras: Array[Camera3D] = []
var _camera: Camera3D
var _ui: RaceUI
var _touch: TouchControls
var _rivals: Array[RaceRacer] = []
var _rival_visuals: Array[RacerVisual] = []
var _animals: Array[AnimalActor] = []
var _dropped: Array[bool] = []
var _touch_held: Array[bool] = []
var _dash_requested: Array[bool] = []
var _elapsed := 0.0
var _countdown := COUNTDOWN_SECONDS
var _start_flash := 0.0
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

	_spawn_players()
	_build_cameras()

	var course := RaceCourse.new()
	course.name = "Course"
	add_child(course)
	course.build(_field)

	_spawn_rivals()
	_spawn_animals()
	_follow_cameras()

	_ui.again_pressed.connect(_restart)
	_ui.forest_pressed.connect(_to_forest)
	_ui.quit_pressed.connect(_quit)
	_ui.dash_pressed.connect(_on_dash)

	var layout := PackedStringArray()
	for group in _field.groups:
		layout.append("%.1f/%d" % [group.z, group.kind])
	print("赛道布局：%s" % " ".join(layout))


func _on_dash(player: int) -> void:
	_dash_requested[player] = true


func _physics_process(delta: float) -> void:
	if _countdown > 0.0:
		# 倒数期间不喂输入、不计时，人机也不动；按下的冲刺作废
		for i in _dash_requested.size():
			_dash_requested[i] = false
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
	for player in _players:
		if player.finished and player.finish_time <= 0.0:
			player.finish_time = _elapsed
	_follow_cameras()
	_update_hud()
	_settle_if_over()


## 人按座位号站位：单人还是老位置（中线），双人各占一条。
func _spawn_players() -> void:
	var duo := Party.joined()
	for seat in Party.count():
		var player := RacePlayer.new()
		player.name = "Player%d" % seat
		player.seat = seat
		add_child(player)
		player.position = Vector3(DUO_X[seat] if duo else 0.0, 0.0, 0.0)
		_players.append(player)
		_touch_held.append(false)
		_dash_requested.append(false)


## 单人：原来那台跟在脑后的相机。双人：左右各一个 SubViewport，共用同一份 World3D。
func _build_cameras() -> void:
	if not Party.joined():
		_camera.position = Vector3(0.0, CAMERA_HEIGHT, -CAMERA_BACK)
		_camera.look_at(CAMERA_LOOK)
		_cameras.append(_camera)
		return

	# 根视口不再出图，两块分屏铺满屏幕
	_camera.current = false
	var layer := CanvasLayer.new()
	layer.name = "Split"
	# 分屏垫在所有 HUD 下面：UI 也是默认层的 CanvasLayer，晚加的会画在上面
	layer.layer = -1
	add_child(layer)
	var row := HBoxContainer.new()
	row.name = "Views"
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 0)
	layer.add_child(row)
	for i in _players.size():
		var holder := SubViewportContainer.new()
		holder.name = "View%d" % i
		holder.stretch = true
		holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(holder)

		var view := SubViewport.new()
		view.name = "Sub%d" % i
		view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		view.handle_input_locally = false
		holder.add_child(view)
		# 场景只建一份，两台相机看同一个世界
		view.world_3d = get_world_3d()

		var cam := Camera3D.new()
		cam.name = "Camera3D"
		cam.fov = DUO_FOV
		cam.position = Vector3(0.0, DUO_CAMERA_HEIGHT, -DUO_CAMERA_BACK)
		view.add_child(cam)
		cam.look_at(CAMERA_LOOK)
		_cameras.append(cam)


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


## 键盘只喂一号位；触屏每个玩家一组摇杆 + 跳跃键，冲刺键在 UI 上。
func _feed() -> void:
	var move := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var jump := Input.is_action_just_pressed("jump")
	var dash := Input.is_action_just_pressed("run")
	_find_touch()
	for i in _players.size():
		var mine_move := move if i == 0 else Vector2.ZERO
		var mine_jump := jump if i == 0 else false
		var mine_dash := dash if i == 0 else false
		if _touch != null:
			if _touch.move(i).length() > 0.05:
				mine_move = _touch.move(i)
			var held := _touch.held(i)
			if held and not _touch_held[i]:
				mine_jump = true
			_touch_held[i] = held
		if _dash_requested[i]:
			mine_dash = true
		_dash_requested[i] = false
		_players[i].feed(mine_move, mine_jump, mine_dash)


func _find_touch() -> void:
	if _touch == null:
		_touch = get_tree().get_first_node_in_group("touch_controls") as TouchControls


func _update_hud() -> void:
	var order := RaceScore.ranking(_entries())
	var ranks := []
	for i in _players.size():
		ranks.append(order.find(i) + 1)
	_ui.set_progress(_player_z(), _rivals, ranks)
	_ui.set_time(_finish_times())
	for i in _players.size():
		var ratio := 1.0
		if _players[i].dash_cd > 0.0:
			ratio = 1.0 - _players[i].dash_cd / Config.RACE_DASH_COOLDOWN
		_ui.set_dash_ready(i, ratio)


## 名次判定的输入：先所有人，再所有人机（RaceScore 只认 finished / finish_time / z）。
func _entries() -> Array:
	var entries: Array = []
	for player in _players:
		entries.append({
			"finished": player.finished, "finish_time": player.finish_time, "z": player.position.z
		})
	for rival in _rivals:
		entries.append(rival)
	return entries


func _player_z() -> Array:
	var out := []
	for player in _players:
		out.append(player.position.z)
	return out


func _finish_times() -> Array:
	var out := []
	for player in _players:
		out.append(player.finish_time if player.finished else _elapsed)
	return out


## 两个人都跑完（或超时）才结算；单人沿用「前三名定了就结算」，不用干等最后一名。
func _settle_if_over() -> void:
	var entries := _entries()
	var done := true
	for player in _players:
		done = done and player.finished
	if not done and _elapsed < Config.RACE_TIME_LIMIT:
		if Party.joined() or not RaceScore.decided(entries):
			return
	_settled = true
	for player in _players:
		player.feed(Vector2.ZERO, false, false)

	var order := RaceScore.ranking(entries)
	var earned := 0
	var ranks := []
	var hits := []
	for i in _players.size():
		var rank: int = order.find(i)
		ranks.append(rank + 1)
		hits.append(_players[i].hits)
		earned += RaceScore.coins(rank, _players[i].hits)
	Save.add_coins(earned)
	_ui.show_result(ranks, _finish_times(), hits, earned, _standings(entries, order))


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


## 0..count()-1 是玩家，往后的下标对应人机。
func _racer_name(index: int) -> String:
	if Party.human(index):
		return Party.name_of(index)
	return RIVAL_NAMES[index - Party.count()]


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
func _follow_cameras() -> void:
	for i in _players.size():
		var target := _players[i].position
		if _cameras.size() == 1:
			_cameras[0].position = Vector3(target.x, CAMERA_HEIGHT, target.z - CAMERA_BACK)
		else:
			_cameras[i].position = Vector3(target.x, DUO_CAMERA_HEIGHT, target.z - DUO_CAMERA_BACK)
