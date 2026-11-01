extends Node3D

## 猫头鹰喂食编排：扣体力、建场景、喂输入、阶段机（倒数 / 对战 / 关间停顿 / 结算）。
## 自包含单场景：节点间直接引用；规则全在 OwlRound 里，每局新种子（randi()），绝不写死。

## 人机三个性格的名字，按「座位号 - 1」对表（座位 0 永远是玩家）
const NPC_NAMES := ["稳", "贪", "胆小"]
const SEAT_COLORS := [
	Color(0.92, 0.25, 0.22), Color(0.32, 0.55, 0.88), Color(0.95, 0.58, 0.25), Color(0.66, 0.40, 0.86)
]
const CAMERA_POSITION := Vector3(0.0, 2.35, 6.3)
const CAMERA_TARGET := Vector3(0.0, 1.55, -1.5)
## 默认 75 度太广，画面上下全是空天；收到 62 度四朵蘑菇和猫头鹰才占满
const CAMERA_FOV := 62.0


enum Phase { COUNTDOWN, PLAY, BREAK, DONE }

var _round: OwlRound
var _arena: OwlArena
var _ui: OwlUI
var _actors: Array[OwlActor] = []
var _items: Array[OwlItem] = []
var _eat := EatInput.new()
var _phase := Phase.COUNTDOWN
var _timer := Config.OWL_COUNTDOWN
var _countdown_shown := -1
var _settled := false
var _names := []
## 服务器把我拉进这一局了就是非空：这时规则在服务器跑，本机只画快照
var _net: NetClient = null
var _my_seat := 0
var _sent_press := false


func _bail_to_forest() -> void:
	get_tree().change_scene_to_file(Config.FOREST_PATH)


func _ready() -> void:
	var net := NetClient.of(get_tree())
	if net != null and net.in_room("owl"):
		# 这一局是服务器的：体力在成局那一下已经扣过，这里不重复扣
		_net = net
		_my_seat = net.seat_index()
	elif not Save.spend_stamina(Config.STAMINA_COST_OWL):
		# 体力不够就别开始，直接回森林；_ready 里换场景要延后，这期间别再 tick
		set_physics_process(false)
		call_deferred("_bail_to_forest")
		return
	Controls.ensure()
	var camera: Camera3D = $Camera3D
	camera.position = CAMERA_POSITION
	camera.fov = CAMERA_FOV
	camera.look_at(CAMERA_TARGET)

	# 服务器那一局的随机序列在服务器上；本机这份只拿来接快照和画
	var seed_value := int(_net.session.get("seed", 0)) if _net != null else randi()
	_round = OwlRound.new(seed_value)
	_round.humans = _human_count()
	_names = _seat_names()
	print("猫头鹰种子：%d" % seed_value)

	_arena = OwlArena.new()
	_arena.name = "Arena"
	add_child(_arena)
	_arena.build()

	for i in OwlRound.SEATS:
		var actor := OwlActor.new()
		actor.name = "Actor%d" % i
		actor.position = Vector3(Config.OWL_SEAT_X[i], 0.0, 0.0)
		add_child(actor)
		# 四朵都背对镜头、正面朝着猫头鹰（不说话，抬头就当张嘴）
		actor.setup(SEAT_COLORS[i], Gaze.yaw_to(actor.position, _arena.owl_point()))
		_actors.append(actor)

		var item := OwlItem.new()
		item.name = "Item%d" % i
		add_child(item)
		item.setup()
		item.visible = false
		_items.append(item)

	# 玩家坐的那几朵跟森林里长得一样（教室同款做法）
	if _net == null:
		for seat in Party.count():
			_actors[seat].apply_look(seat)
	else:
		_actors[_my_seat].apply_look(0)

	_ui = $UI
	_ui.set_names(_names)
	_ui.set_hint(
		"两人各按自己那半边屏幕：按住 = 张嘴，松开 = 闭嘴" if _net == null and Party.joined() else ""
	)
	_ui.again_pressed.connect(_restart)
	_ui.forest_pressed.connect(_to_forest)
	_ui.quit_pressed.connect(_quit)


func _input(event: InputEvent) -> void:
	_eat.feed(event, get_viewport().get_visible_rect().size.x)


func _notification(what: int) -> void:
	# 系统抢走前台时抬手事件可能永远不来，不清掉就会一直「按着」
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_eat.clear()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if _settled:
			return
		# 返回键：先弹暂停面板（再按一次继续）
		if get_tree().paused:
			get_tree().paused = false
			# 暂停期间收不到抬手事件，恢复时把手指状态丢掉，免得嘴一直张着
			_eat.clear()
			_ui.hide_pause()
		else:
			_ui.show_pause()
			get_tree().paused = true


func _physics_process(delta: float) -> void:
	if _net != null:
		_net_step(delta)
		return
	match _phase:
		Phase.COUNTDOWN:
			_tick_countdown(delta)
		Phase.PLAY:
			_play(delta)
		Phase.BREAK:
			_tick_break(delta)


## 服务器那一局：把快照写进本地模型再照旧渲染，只上报「我按着」，不自己推规则。
func _net_step(delta: float) -> void:
	if _settled:
		return
	# 掉线了：服务器那一局的规则全在服务器上，本机没法接着算，回森林
	if not _net.ready():
		set_physics_process(false)
		call_deferred("_bail_to_forest")
		return
	var game: Dictionary = _net.session.get("game", {})
	if not game.is_empty():
		_apply_game(game)
	_send_press()
	_update_visuals(delta)
	_ui.set_hud(_round.level + 1, _round.time_left, _scores(), _outs())
	_show_break()
	# 服务器收局不一定是模型判的（有人走人、掉线、到硬顶）：session 上置了 over 也算
	if _round.match_over or bool(_net.session.get("over", false)):
		_settle()


## 把服务器快照写进本地模型（只写不推，规则全在服务器）
func _apply_game(game: Dictionary) -> void:
	_round.level = int(game.get("level", _round.level))
	_round.time_left = float(game.get("time_left", _round.time_left))
	_round.level_over = bool(game.get("level_over", false))
	_round.break_left = float(game.get("break_left", 0.0))
	_round.match_over = bool(game.get("over", false))
	var states: Array = game.get("seats", [])
	for i in mini(states.size(), _round.mouths.size()):
		var mouth: OwlRound.Mouth = _round.mouths[i]
		var state: Dictionary = states[i]
		mouth.score = int(state.get("score", 0))
		mouth.out = bool(state.get("out", false))
		mouth.open = bool(state.get("open", false))
		mouth.flying = float(state.get("flying", 0.0))
		mouth.fall = float(state.get("fall", 0.0))
		mouth.poop = bool(state.get("poop", false))


## 一台上一个人：整块屏都是自己的，按住 = 张嘴。只在状态变了才发，省流量。
func _send_press() -> void:
	var held := _eat.pressing() or Input.is_action_pressed("jump")
	if held == _sent_press:
		return
	_sent_press = held
	_net.send_input({"press": held})


## 关间停顿：服务器只给「还剩多久 / 现在是第几关」，那一屏的字本机拼
func _show_break() -> void:
	if _round.break_left > 0.0:
		_ui.show_countdown("第 %d 关" % (_round.level + 2))
	elif not _round.match_over:
		_ui.hide_countdown()


func _tick_countdown(delta: float) -> void:
	_timer -= delta
	var shown := ceili(_timer)
	if shown > 0 and shown != _countdown_shown:
		_countdown_shown = shown
		_ui.show_countdown(str(shown))
	if _timer <= 0.0:
		_countdown_shown = -1
		_ui.hide_countdown()
		_enter_play()


func _play(delta: float) -> void:
	# 玩家出局后本关剩下一段 2.5 倍速跑完：人机分数照实累加，不做补算
	var speed := Config.OWL_FAST_FORWARD if _round.players_out() else 1.0
	_round.tick(delta * speed, _presses())
	_drain_events()
	_update_visuals(delta)
	_ui.set_hud(_round.level + 1, _round.time_left, _scores(), _outs())
	if not _round.level_over:
		return
	_round.mouths[OwlRound.PLAYER].open = false
	if _round.level >= Config.OWL_SECONDS.size() - 1:
		_settle()
		return
	# 关间停顿里模型不 tick，画面也不能留着半空的东西和半张的嘴
	_freeze_visuals()
	_phase = Phase.BREAK
	_timer = Config.OWL_BREAK_SECONDS
	_countdown_shown = -1
	_ui.show_countdown("第 %d 关" % (_round.level + 2))


func _tick_break(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_ui.hide_countdown()
	_round.start_level(_round.level + 1)
	_enter_play()


## 进对战那一刻把输入清零：倒数时拇指搭在屏幕上、暂停时松手（暂停期间收不到抬手事件），
## 不清就会带着一张「自己张开的嘴」进场，第一颗正好是屎时玩家完全解释不了。
func _enter_play() -> void:
	_eat.clear()
	_phase = Phase.PLAY
	_ui.set_hud(_round.level + 1, _round.time_left, _scores(), _outs())


## 只有对战阶段才喂输入。
func _presses() -> Array:
	var presses := [false, false, false, false]
	if _phase != Phase.PLAY:
		return presses
	presses[0] = _eat.pressing(0 if Party.joined() else -1) or Input.is_action_pressed("jump")
	if Party.joined():
		presses[1] = _eat.pressing(1)
	return presses


## 座位名：人坐前几个，人机从后面补。
func _seat_names() -> Array:
	var names := []
	var seats: Array = _net.session.get("seats", []) if _net != null else []
	for seat in OwlRound.SEATS:
		if not _is_human(seat):
			names.append(NPC_NAMES[seat - 1])
		elif _net != null:
			names.append(str((seats[seat] as Dictionary).get("account", "")))
		else:
			names.append(Party.name_of(seat))
	return names


## 这个座位是不是人在玩：本地按 Party 算，服务器那一局按 session 的座位表算。
func _is_human(seat: int) -> bool:
	if _net == null:
		return Party.human(seat)
	var seats: Array = _net.session.get("seats", [])
	return seat >= 0 and seat < seats.size() and not bool((seats[seat] as Dictionary).get("npc", false))


func _human_count() -> int:
	var out := 0
	for seat in OwlRound.SEATS:
		if _is_human(seat):
			out += 1
	return out


func _scores() -> Array:
	return _round.scores()


func _outs() -> Array:
	var outs := []
	for mouth in _round.mouths:
		outs.append(mouth.out)
	return outs


func _drain_events() -> void:
	for event in _round.events:
		match String(event["kind"]):
			"eat":
				print("吃到糖：%s" % _names[int(event["seat"])])
			"poop":
				print("吃屎出局：%s" % _names[int(event["seat"])])
	_round.events.clear()


func _update_visuals(delta: float) -> void:
	for i in OwlRound.SEATS:
		var mouth: OwlRound.Mouth = _round.mouths[i]
		_actors[i].apply(mouth.score, mouth.open, mouth.out, delta)
		var item := _items[i]
		if mouth.flying > 0.0 and mouth.fall > 0.0:
			item.set_kind(mouth.poop)
			item.place(_arena.owl_point(), _actors[i].mouth_point(), 1.0 - mouth.flying / mouth.fall)
			item.visible = true
		else:
			item.visible = false


func _rows(order: Array) -> Array:
	var rows := []
	for index in order:
		var mouth: OwlRound.Mouth = _round.mouths[index]
		rows.append({
			"name": _names[index],
			"score": mouth.score,
			"out": mouth.out,
			"human": _is_human(index),
		})
	return rows


## 嘴全部闭上、线上东西全部收掉：关间停顿和结算都用这一下。
func _freeze_visuals() -> void:
	for i in OwlRound.SEATS:
		var mouth: OwlRound.Mouth = _round.mouths[i]
		_actors[i].apply(mouth.score, false, mouth.out, 1.0)
		_items[i].visible = false


func _settle() -> void:
	_settled = true
	_phase = Phase.DONE
	_freeze_visuals()
	var order := OwlRound.ranking(_scores())
	if _net != null:
		# 币是服务器结的，这里只放演出
		var my_rank := order.find(_my_seat) + 1
		var earned_online := int((_net.session.get("earned", {}) as Dictionary).get(_net.player_name, 0))
		print("结算：第 %d 名，+%d 蘑菇币（服务器）" % [my_rank, earned_online])
		_ui.show_result([my_rank], earned_online, _rows(order))
		return
	# 每个玩家各自按名次算币，都进同一个钱包（一台手机一份存档）
	var earned := 0
	var ranks := []
	for seat in Party.count():
		var rank: int = order.find(seat)
		ranks.append(rank + 1)
		earned += OwlRound.coins(rank)
	Save.add_coins(earned)
	print("结算：%s 名，+%d 蘑菇币" % [str(ranks), earned])
	_ui.show_result(ranks, earned, _rows(order))


func _restart() -> void:
	get_tree().paused = false
	if _net != null:
		# 服务器那一局没法在本机重开：新一局要从森林重新邀请
		_release_room()
		get_tree().change_scene_to_file(Config.FOREST_PATH)
		return
	get_tree().reload_current_scene()


func _to_forest() -> void:
	get_tree().paused = false
	_release_room()
	get_tree().change_scene_to_file(Config.FOREST_PATH)


## 主动离开这一局：让服务器把房腾出来（否则「同时一间房」会被一次旧局占住）
func _release_room() -> void:
	if _net != null:
		_net.request("leave_room", {})


func _quit() -> void:
	get_tree().paused = false
	get_tree().quit()
