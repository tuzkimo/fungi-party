extends Node3D

## 赛跑编排：按种子建赛道、摆四个跑者、喂输入、跟相机。
## 规则（前进 / 横移 / 跳 / 撞 / 冲线 / 币）全在 RaceRound 里：
## 本机局由这里 tick；服务器那一局只把快照写进 _round 再照旧渲染，不自己推进、不扣体力、不结账。
## 同屏双人时两个座位各占半边屏，每人一台相机跟着自己跑。

const START_FLASH := 0.5
const CAMERA_HEIGHT := 3.5
const CAMERA_BACK := 7.0
## look_at 只用来定俯角：之后每帧只平移
const CAMERA_LOOK := Vector3(0.0, 0.8, 10.0)
## 分屏后每边只有半个屏幕宽：相机拉远、视角开一点，7 米外的整条赛道才还在视野里
const DUO_CAMERA_HEIGHT := 4.4
const DUO_CAMERA_BACK := 9.5
const DUO_FOV := 78.0
const RIVAL_NAMES := ["稳中型", "贴边型", "冲动型"]
const PINE_SIZE := 0.6
const PINE_COLOR := Color(0.42, 0.30, 0.16)

var _round: RaceRound = null
var _camera: Camera3D
var _ui: RaceUI
var _touch: TouchControls
## 四个座位的视图（自己负责的是 RacePlayer，其余是染色的 RacerVisual）
var _views: Array = []
var _cameras: Array[Camera3D] = []
## 这台机器负责的座位：本机 0..count()-1，服务器那一局只有自己那一个
var _seats: Array[int] = []
## 四个座位的颜色（自己那几格是玩家色），圆点和头顶色块共用
var _colors: Array = []
var _animals: Array[AnimalActor] = []
var _dropped: Array[bool] = []
var _touch_held: Array[bool] = []
var _dash_requested: Array[bool] = []
var _start_flash := -1.0
var _countdown_text := ""
var _settled := false

## 服务器把我拉进这一局了就是非空：这时规则在服务器跑，本机只画快照
var _net: NetClient = null
var _my_seat := 0
var _sent_steer := 0.0
var _steer_sent := false


func _bail_to_forest() -> void:
	get_tree().change_scene_to_file(Config.FOREST_PATH)


func _ready() -> void:
	_net = _joinable_room()
	if _net == null:
		if not Save.spend_stamina(Config.STAMINA_COST_RACE):
			# 体力不够就别开始，直接回森林；_ready 里换场景要延后
			set_physics_process(false)
			call_deferred("_bail_to_forest")
			return
		_round = RaceRound.new(randi(), Party.count())
		for seat in Party.count():
			_seats.append(seat)
	else:
		# 这一局是服务器的：体力在成局那一下已经扣过，本地 2P 没有座位
		_my_seat = _net.seat_index()
		_seats.append(_my_seat)
		_round = RaceRound.new(int(_net.session.get("seed", 1)), _room_humans())
		_apply_game(_net.session.get("game", {}))
	for i in _seats.size():
		_touch_held.append(false)
		_dash_requested.append(false)
	_colors = RaceUI.seat_colors(_seats)

	Controls.ensure()
	_camera = $Camera3D
	_ui = $UI

	_spawn_views()
	_ui.set_seat_colors(_colors)
	_build_cameras()

	var course := RaceCourse.new()
	course.name = "Course"
	add_child(course)
	course.build(_round.field)

	_spawn_animals()
	_follow_cameras()

	_ui.again_pressed.connect(_restart)
	_ui.forest_pressed.connect(_to_forest)
	_ui.quit_pressed.connect(_quit)
	_ui.dash_pressed.connect(_on_dash)

	var layout := PackedStringArray()
	for group in _round.field.groups:
		layout.append("%.1f/%d" % [group.z, group.kind])
	print("赛道布局：%s" % " ".join(layout))


func _on_dash(player: int) -> void:
	if player < _dash_requested.size():
		_dash_requested[player] = true


func _physics_process(delta: float) -> void:
	if _settled:
		return
	if _net != null:
		_net_step(delta)
		return
	if _round.started():
		_feed_local()
	_round.tick(delta)
	_sync(delta)
	if _round.over:
		_settle()


## 服务器那一局：把快照写进本地模型再照旧渲染，只上报摇杆和跳/冲。
func _net_step(delta: float) -> void:
	# 掉线了：规则全在服务器上，本机没法接着算，回森林（否则画面冻在原地）
	if not _net.ready():
		set_physics_process(false)
		call_deferred("_bail_to_forest")
		return
	var game: Dictionary = _net.session.get("game", {})
	if not game.is_empty():
		_apply_game(game)
	# 服务器收局不一定是模型判的（有人走人、掉线、到硬顶）：session 上置了 over 也算
	_round.over = _round.over or bool(_net.session.get("over", false))
	_feed_net()
	_sync(delta)
	if _round.over:
		_settle()


## 把服务器快照写进本地模型（只写不推，规则全在服务器）
func _apply_game(game: Dictionary) -> void:
	if game.is_empty():
		return
	_round.countdown = float(game.get("countdown", _round.countdown))
	_round.elapsed = float(game.get("elapsed", _round.elapsed))
	_round.over = bool(game.get("over", false))
	_round.winner = int(game.get("winner", -1))
	var states: Array = game.get("racers", [])
	for i in mini(states.size(), _round.racers.size()):
		var state: Dictionary = states[i]
		var racer: RaceRacer = _round.racers[i]
		racer.x = float(state.get("x", racer.x))
		racer.y = float(state.get("y", racer.y))
		racer.z = float(state.get("z", racer.z))
		racer.steer = float(state.get("steer", racer.steer))
		racer.hits = int(state.get("hits", racer.hits))
		racer.finished = bool(state.get("finished", racer.finished))
		racer.finish_time = float(state.get("finish_time", racer.finish_time))
		racer.dash_left = float(state.get("dash_left", racer.dash_left))
		racer.dash_cd = float(state.get("dash_cd", racer.dash_cd))
		racer.freeze = float(state.get("freeze", racer.freeze))


## 本机：键盘只喂一号位，触屏每个座位一组摇杆 + 跳跃键，冲刺键在 UI 上。
func _feed_local() -> void:
	var move := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var jump := Input.is_action_just_pressed("jump")
	var dash := Input.is_action_just_pressed("run")
	_find_touch()
	for i in _seats.size():
		var seat: int = _seats[i]
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
		_round.steer(seat, mine_move.x)
		if mine_jump:
			_round.jump(seat)
		if mine_dash:
			_round.dash(seat)


## 服务器那一局：摇杆只在变了才发（20 Hz 没必要），跳和冲是点一下就发。
func _feed_net() -> void:
	var move := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var jump := Input.is_action_just_pressed("jump")
	var dash := Input.is_action_just_pressed("run") or _dash_requested[0]
	_dash_requested[0] = false
	_find_touch()
	if _touch != null:
		if _touch.move(0).length() > 0.05:
			move = _touch.move(0)
		var held := _touch.held(0)
		if held and not _touch_held[0]:
			jump = true
		_touch_held[0] = held
	if not _round.started():
		return
	if not _steer_sent or absf(move.x - _sent_steer) > 0.01:
		_sent_steer = move.x
		_steer_sent = true
		_net.send_input({"move": move.x})
	if jump:
		_net.send_input({"jump": true})
	if dash:
		_net.send_input({"dash": true})


## 四个座位各一个视图：真人按自己的体型皮肤长（联机时按他报上来的形象），人机是染色蘑菇。
func _spawn_views() -> void:
	for seat in Config.SEAT_COUNT:
		var look := _seat_look(seat)
		if _seats.has(seat):
			var player := RacePlayer.new()
			player.name = "Player%d" % seat
			add_child(player)
			player.setup_player(look)
			player.apply(_round.racers[seat], 0.0)
			player.set_label(_seat_name(seat))
			_views.append(player)
		else:
			var rival := RacerVisual.new()
			rival.name = "Racer%d" % seat
			add_child(rival)
			rival.setup(_colors[seat], look)
			rival.apply(_round.racers[seat], 0.0)
			rival.set_label(_seat_name(seat))
			_views.append(rival)


## 这一格是不是真人：联机看服务器的座位表，单机看 Party
func _is_human(seat: int) -> bool:
	if _net == null:
		return Party.human(seat)
	var seats: Array = _net.session.get("seats", [])
	return seat >= 0 and seat < seats.size() and not bool((seats[seat] as Dictionary).get("npc", false))


## 这一格的人长什么样：人机给空（用颜色认人），真人按座位表里那个账号报上来的形象
func _seat_look(seat: int) -> Dictionary:
	if not _is_human(seat):
		return {}
	return _net.seat_look(seat) if _net != null else Party.look(seat)


## 一个座位就是整块屏（服务器那一局、本机单人）。双人：左右各一个 SubViewport，共用同一份 World3D。
func _build_cameras() -> void:
	if _seats.size() == 1:
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
	for i in _seats.size():
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


func _spawn_animals() -> void:
	for i in _round.field.crossings.size():
		var crossing: RaceField.Crossing = _round.field.crossings[i]
		var animal := AnimalActor.new()
		animal.name = "Animal%d" % i
		add_child(animal)
		animal.setup(crossing.kind, crossing.side, crossing.z)
		animal.advance(-1.0)
		_animals.append(animal)
		_dropped.append(false)


func _sync(delta: float) -> void:
	for seat in Config.SEAT_COUNT:
		_views[seat].apply(_round.racers[seat], delta)
	_update_actors()
	_update_hud()
	_follow_cameras()
	_update_countdown(delta)


func _update_actors() -> void:
	for i in _animals.size():
		var crossing: RaceField.Crossing = _round.field.crossings[i]
		_animals[i].advance(_round.elapsed - crossing.time)
		_drop_pinecone(i, crossing)


## 松鼠横穿到一半时把松果丢在中线，整局留在原地（现在只是画，撞击由模型判）。
func _drop_pinecone(index: int, crossing: RaceField.Crossing) -> void:
	if _dropped[index] or crossing.kind != RaceField.SQUIRREL:
		return
	if _round.elapsed < crossing.time + Config.RACE_ANIMAL_WARN + RaceField.WALK_IN:
		return
	_dropped[index] = true
	var pine := Node3D.new()
	pine.name = "Pinecone%d" % index
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


func _find_touch() -> void:
	if _touch == null:
		_touch = get_tree().get_first_node_in_group("touch_controls") as TouchControls


func _update_hud() -> void:
	var order := RaceScore.ranking(_round.racers)
	var ranks := []
	var times := []
	var zs := []
	for racer in _round.racers:
		zs.append(racer.z)
	for i in _seats.size():
		var seat: int = _seats[i]
		var racer: RaceRacer = _round.racers[seat]
		ranks.append(order.find(seat) + 1)
		times.append(racer.finish_time if racer.finished else _round.elapsed)
	_ui.set_progress(zs, ranks)
	_ui.set_time(times)
	for i in _seats.size():
		var racer: RaceRacer = _round.racers[_seats[i]]
		var ratio := 1.0
		if racer.dash_cd > 0.0:
			ratio = 1.0 - racer.dash_cd / Config.RACE_DASH_COOLDOWN
		_ui.set_dash_ready(i, ratio)


## 倒数：剩几秒 → 「开始！」闪一下 → 藏起来。服务器那一局的 remain 也是快照给的。
func _update_countdown(delta: float) -> void:
	if _round.countdown > 0.0:
		var text := str(ceili(_round.countdown))
		if text != _countdown_text:
			_countdown_text = text
			_ui.show_countdown(text)
	elif _start_flash < 0.0:
		_ui.show_countdown("开始！")
		_start_flash = START_FLASH
	elif _start_flash > 0.0:
		_start_flash = maxf(0.0, _start_flash - delta)
		if _start_flash == 0.0:
			_ui.hide_countdown()


## 结算：服务器那局币是服务器结的（快照里带 earned），本机局自己进钱包。
func _settle() -> void:
	_settled = true
	var order := RaceScore.ranking(_round.racers)
	var ranks := []
	var times := []
	var hits := []
	var earned := 0
	for i in _seats.size():
		var seat: int = _seats[i]
		var racer: RaceRacer = _round.racers[seat]
		var rank := order.find(seat)
		ranks.append(rank + 1)
		times.append(racer.finish_time if racer.finished else _round.elapsed)
		hits.append(racer.hits)
		earned += RaceScore.coins(rank, racer.hits)
	if _net != null:
		earned = int((_net.session.get("earned", {}) as Dictionary).get(_net.player_name, 0))
	else:
		Save.add_coins(earned)
	_ui.show_result(ranks, times, hits, earned, _standings(order))


## 结算面板上的名次表：按名次排好，名字 + 时间（没跑完的写未完赛）。
func _standings(order: Array) -> Array:
	var rows := []
	for index in order:
		var racer: RaceRacer = _round.racers[index]
		rows.append({
			"name": _seat_name(index),
			"finished": racer.finished,
			"time": racer.finish_time,
		})
	return rows


## 0..count()-1 是本机玩家，其余按「人机 / 服务器上的别人」取名。
func _seat_name(seat: int) -> String:
	if _net != null:
		var seats: Array = _net.session.get("seats", [])
		if seat < seats.size() and not bool((seats[seat] as Dictionary).get("npc", false)):
			return str((seats[seat] as Dictionary).get("account", ""))
	elif Party.human(seat):
		return Party.name_of(seat)
	var rival := seat - _round.humans
	return RIVAL_NAMES[rival] if rival >= 0 and rival < RIVAL_NAMES.size() else "人机"


## 返回键：本机局先弹暂停面板（再按一次继续）；服务器那一局暂停不了，直接回森林。
func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_GO_BACK_REQUEST or _settled:
		return
	if _net != null:
		_to_forest()
		return
	if get_tree().paused:
		get_tree().paused = false
		_ui.hide_pause()
	else:
		get_tree().paused = true
		_ui.show_pause()


func _restart() -> void:
	get_tree().paused = false
	_release_room()
	if _net != null:
		# 服务器那一局没法在本机重开：新一局要从森林重新邀请
		get_tree().change_scene_to_file(Config.FOREST_PATH)
		return
	get_tree().reload_current_scene()


func _to_forest() -> void:
	get_tree().paused = false
	_release_room()
	get_tree().change_scene_to_file(Config.FOREST_PATH)


func _quit() -> void:
	get_tree().paused = false
	get_tree().quit()


## 主动离开这一局：让服务器把房腾出来（否则「同时一间房」会被一次旧局占住）
func _release_room() -> void:
	if _net != null:
		_net.request("leave_room", {})


## 服务器那份 session 是不是「我该进这条赛道」：只在 _ready 判一次，
## 局结束（over）之后还得继续按服务器那套画，不能又退回本机自己算。
func _joinable_room() -> NetClient:
	var net := NetClient.of(get_tree())
	return net if net != null and net.in_room("race") else null


func _room_humans() -> int:
	var out := 0
	for seat_state in _net.session.get("seats", []):
		if not bool((seat_state as Dictionary).get("npc", false)):
			out += 1
	return maxi(out, 1)


## 镜头锁死朝前：只平移，不转、不抖。双人各跟自己的座位。
func _follow_cameras() -> void:
	for i in _seats.size():
		# 跟视图而不是跟模型：联机快照 20 Hz，模型值是一跳一跳的
		var target: Vector3 = _views[_seats[i]].position
		if _cameras.size() == 1:
			_cameras[0].position = Vector3(target.x, CAMERA_HEIGHT, target.z - CAMERA_BACK)
		else:
			_cameras[i].position = Vector3(target.x, DUO_CAMERA_HEIGHT, target.z - DUO_CAMERA_BACK)
