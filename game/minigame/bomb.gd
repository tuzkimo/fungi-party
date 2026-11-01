extends Node3D

## 传炸弹编排：把 BombRound 的状态喂给座位、炸弹、音效，读玩家输入。
## 自包含单场景：节点间直接引用；模型不碰节点，每局新种子（randi()），绝不写死。

## 人机三个座位的名字（座位 0 永远是玩家）
const NPC_NAMES := ["蓝", "红", "紫"]
const SEAT_COLORS := [
	Color(0.92, 0.25, 0.22), Color(0.32, 0.55, 0.88), Color(0.86, 0.30, 0.26), Color(0.66, 0.40, 0.86)
]
const HOLD_OFFSET := Vector3(0.0, 1.9, 0.0)
## 点燃那一飞：炸弹从篝火飞向落点，比计划里的传递飞行慢一点，看得清是谁接到了
const IGNITE_FLIGHT := 0.45
## 座位上的人「犹豫程度」的分母：引信还剩这么多时动作就夸张到顶
const HURRIED_FUSE := 2.5
const CAMERA_POSITION := Vector3(0.0, 7.8, 7.0)
const CAMERA_TARGET := Vector3(0.0, 0.4, 0.0)

var _round: BombRound
var _arena: BombArena
var _bomb: BombVisual
var _sfx: Sfx
var _ui: BombUI
var _seats: Array[BombSeat] = []
var _countdown := Config.BOMB_COUNTDOWN
var _countdown_shown := -1
var _visual_flight := false
var _settled := false
var _elapsed := 0.0
var _names := []
## 服务器把我拉进这一局了就是非空：这时规则在服务器跑，本机只画快照
var _net: NetClient = null
var _my_seat := 0


func _bail_to_forest() -> void:
	get_tree().change_scene_to_file(Config.FOREST_PATH)


func _ready() -> void:
	_net = _joinable_room()
	if _net == null:
		if not Save.spend_stamina(Config.STAMINA_COST_BOMB):
			# 体力不够就别开始，直接回森林；_ready 里换场景要延后，
			# 这期间 UI 还没建好，别再 tick
			set_physics_process(false)
			call_deferred("_bail_to_forest")
			return
	else:
		# 这一局是服务器的：体力在成局那一下已经扣过，这里不重复扣
		_my_seat = _room_seat()
	Controls.ensure()
	var camera: Camera3D = $Camera3D
	camera.position = CAMERA_POSITION
	camera.look_at(CAMERA_TARGET)

	# 服务器那一局的随机序列在服务器上；本机这份只拿来接快照和画，种子只影响没被覆盖到的字段
	var seed_value := int(_net.session.get("seed", 0)) if _net != null else randi()
	_round = BombRound.new(seed_value)
	_round.humans = _human_count()
	_names = _seat_names()
	print("炸弹种子：%d" % seed_value)

	_arena = BombArena.new()
	_arena.name = "Arena"
	add_child(_arena)
	_arena.build()

	for i in BombRound.SEATS:
		var seat := BombSeat.new()
		seat.name = "Seat%d" % i
		seat.position = BombSeat.seat_position(i)
		add_child(seat)
		# 本机的人按自己的体型皮肤长，别人（含远端真人和人机）用色块认人
		var look := i if _net == null and _is_human(i) else -1
		if _net != null and i == _my_seat:
			look = 0
		seat.setup(SEAT_COLORS[i], look)
		_seats.append(seat)

	_bomb = BombVisual.new()
	_bomb.name = "Bomb"
	add_child(_bomb)
	_bomb.setup()

	_sfx = Sfx.new()
	_sfx.name = "Sfx"
	add_child(_sfx)

	_ui = $UI
	_ui.again_pressed.connect(_restart)
	_ui.forest_pressed.connect(_to_forest)
	_ui.quit_pressed.connect(_quit)
	_ui.throw_pressed.connect(_on_throw_pressed)
	# _init 自己塞的那条 ignite 先扔掉：本机一局重新放点火动画，服务器那一局等服务器的 ignite 事件
	_round.events.clear()
	if _net != null:
		# 服务器那一局没有本机倒数（引信在服务器上已经在烧）：投掷键直接可用
		_countdown = 0.0
		_ui.set_armed(true)
	else:
		# 倒数期间两个投掷键不接收触摸
		_ui.set_armed(false)
		# 开局那颗：模型已经点燃了，视觉上让它从篝火飞过去
		_launch_from_fire(_round.holder)


func _physics_process(delta: float) -> void:
	if _net != null:
		_net_step(delta)
		return
	if _countdown > 0.0:
		# 倒数期间不 tick 模型、不喂输入，引信也不烧
		_countdown -= delta
		var shown := ceili(maxf(_countdown, 0.0))
		if shown != _countdown_shown:
			_countdown_shown = shown
			_ui.show_countdown(str(shown))
		return
	if _countdown_shown >= 0:
		_countdown_shown = -1
		_ui.hide_countdown()
		_ui.set_armed(true)
		for seat in Party.count():
			_round.queued[seat] = 0
	if _settled:
		return

	_elapsed += delta
	_round.tick(delta)
	_feed()
	_drain_events()
	_update_visuals(delta)
	if _round.over or _humans_out():
		_settle()


## 服务器那一局：把快照写进本地模型再照旧渲染，只上报「我往哪边扔」，不自己推规则。
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
	_feed()
	_drain_events()
	_update_visuals(delta)
	# 服务器收局不一定是模型判的（有人走人、掉线、到硬顶）：session 上置了 over 也算
	_round.over = _round.over or bool(_net.session.get("over", false))
	if _round.over:
		_settle()


## 把服务器快照写进本地模型（只写不推，规则全在服务器）
func _apply_game(game: Dictionary) -> void:
	_round.holder = int(game.get("holder", -1))
	_round.thrower = int(game.get("thrower", -1))
	_round.target = int(game.get("target", -1))
	_round.flight = float(game.get("flight", 0.0))
	_round.fuse = float(game.get("fuse", _round.fuse))
	_round.alive = (game.get("alive", []) as Array).duplicate()
	_round.death_order = (game.get("death_order", []) as Array).duplicate()
	_round.over = bool(game.get("over", false))
	_round.elapsed = float(game.get("elapsed", _round.elapsed))
	for event in _net.take_events():
		_round.events.append(event)


## 这个座位是不是人在玩：本地按 Party 算，服务器那一局按 session 的座位表算。
func _is_human(seat: int) -> bool:
	if _net == null:
		return Party.human(seat)
	var seats: Array = _net.session.get("seats", [])
	return seat >= 0 and seat < seats.size() and not bool((seats[seat] as Dictionary).get("npc", false))


func _human_count() -> int:
	var out := 0
	for seat in BombRound.SEATS:
		if _is_human(seat):
			out += 1
	return out


## 服务器那份 session 是不是「我该进这局传炸弹」：只在 _ready 判一次，
## 局结束（over）之后还得继续按服务器那套画，不能又退回本机自己算。
func _joinable_room() -> NetClient:
	var net := get_tree().root.get_node_or_null("Net") as NetClient
	if net == null or not net.ready():
		return null
	if str(net.session.get("kind", "")) != "bomb" or bool(net.session.get("over", false)):
		return null
	return net


func _room_seat() -> int:
	var seats: Array = _net.session.get("seats", [])
	for i in seats.size():
		if str((seats[i] as Dictionary).get("account", "")) == _net.player_name:
			return i
	return 0


## 场上的人全被炸死了才算这局看完（双人时剩下那个接着玩）。
## 服务器那一局不看这个：我死了别人还在玩，收局由服务器说。
func _humans_out() -> bool:
	if _net != null:
		return false
	for seat in Party.count():
		if _round.alive.has(seat):
			return false
	return true


## 座位名：人坐前几个，人机从后面补。
func _seat_names() -> Array:
	var names := []
	for seat in BombRound.SEATS:
		var human := _is_human(seat)
		if _net != null:
			var seats: Array = _net.session.get("seats", [])
			names.append(str((seats[seat] as Dictionary).get("account", "")) if human else NPC_NAMES[seat - 1])
		else:
			names.append(Party.name_of(seat) if human else NPC_NAMES[seat - 1])
	return names


## 倒数期间按按钮不许记账：否则倒数一结束炸弹会自己飞出去（玩家根本没按）。
func _on_throw_pressed(player: int, side: int) -> void:
	if _settled:
		return
	if _net != null:
		# 座位由服务器按账号认，本机只报「往哪边扔」
		_net.send_input({"throw": side})
		return
	if _countdown > 0.0:
		return
	_round.request_throw(player, side)


## 键盘只喂一号位（触屏两个玩家各有一对投掷键）。
func _feed() -> void:
	if Input.is_action_just_pressed("move_left"):
		_on_throw_pressed(0, -1)
	if Input.is_action_just_pressed("move_right"):
		_on_throw_pressed(0, 1)


func _update_visuals(delta: float) -> void:
	var holder := _round.holder
	for i in _seats.size():
		var hurried := 0.0
		if i == holder and not _is_human(i):
			hurried = clampf(1.0 - _round.fuse / HURRIED_FUSE, 0.0, 1.0)
		_seats[i].apply(hurried, _round.alive.has(i), delta)

	if _visual_flight:
		if _bomb.advance(delta):
			_visual_flight = false
			_sfx.play("catch")
	elif holder >= 0:
		_bomb.hold(_head_of(holder))

	_bomb.set_danger(_round.danger(), _round.tier())
	_ui.set_danger(_round.danger())
	_sfx.set_danger(_round.danger(), _is_human(holder))


func _drain_events() -> void:
	for event in _round.events:
		_handle_event(event)
	_round.events.clear()


func _handle_event(event: Dictionary) -> void:
	match event["kind"]:
		"ignite":
			var seat: int = event["seat"]
			print("点燃：%s" % _names[seat])
			_launch_from_fire(seat)
		"throw":
			var from: int = event["from"]
			var to: int = event["to"]
			print("扔出：%s → %s" % [_names[from], _names[to]])
			_sfx.play("throw")
			_visual_flight = true
			_bomb.start_flight(_head_of(from), _head_of(to), Config.BOMB_THROW_SECONDS)
		"explode":
			var seat: int = event["seat"]
			print("爆炸：%s（%s）" % [_names[seat], "空中" if bool(event["in_flight"]) else "手上"])
			_sfx.play("boom")
			# 规则上「空中炸算扔的人死」，但视觉上要死得明白：火球在死的那个人头上炸开
			_bomb.explode(_head_of(seat))
			_visual_flight = false
		"over":
			print("结束：%s 活到最后" % _names[int(event["winner"])])
			_sfx.play("win")


func _launch_from_fire(seat: int) -> void:
	if seat < 0:
		return
	_visual_flight = true
	_bomb.start_flight(_arena.fire_position(), _head_of(seat), IGNITE_FLIGHT)


func _head_of(seat: int) -> Vector3:
	return BombSeat.seat_position(seat) + HOLD_OFFSET


func _settle() -> void:
	_settled = true
	_sfx.stop_fuse()
	if _net != null:
		# 币是服务器结的，这里只放演出
		var my_rank := BombScore.rank_of(_my_seat, _round.death_order, _round.alive) + 1
		var earned_online := int((_net.session.get("earned", {}) as Dictionary).get(_net.player_name, 0))
		print("结算：第 %d 名，撑了 %d 秒，+%d 蘑菇币（服务器）" % [my_rank, int(_round.elapsed), earned_online])
		_ui.show_result(
			[my_rank], _round.elapsed, earned_online,
			BombScore.rows(_round.death_order, _round.alive, _names, _round.humans)
		)
		return
	# 每个玩家各自按名次算币，都进同一个钱包（一台手机一份存档）
	var earned := 0
	var ranks := []
	for seat in Party.count():
		var rank := BombScore.rank_of(seat, _round.death_order, _round.alive)
		ranks.append(rank + 1)
		earned += BombScore.coins(rank)
	print("结算：%s 名，撑了 %d 秒，+%d 蘑菇币" % [str(ranks), int(_elapsed), earned])
	# 币进本机钱包（联机但没被邀请时走 add_coins 那条 op）；服务器那一局的币在上面结过账了
	Save.add_coins(earned)
	_ui.show_result(
		ranks, _elapsed, earned,
		BombScore.rows(_round.death_order, _round.alive, _names, Party.count())
	)


## 返回键：先弹暂停面板（再按一次继续）。暂停时嗤嗤声和滴答停住，模型跟着 get_tree().paused 停。
func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_GO_BACK_REQUEST or _settled:
		return
	if get_tree().paused:
		get_tree().paused = false
		_ui.hide_pause()
	else:
		_ui.show_pause()
		_sfx.stop_fuse()
		get_tree().paused = true


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
