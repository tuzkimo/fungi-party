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


func _bail_to_forest() -> void:
	get_tree().change_scene_to_file(Config.FOREST_PATH)


func _ready() -> void:
	if not Save.spend_stamina(Config.STAMINA_COST_BOMB):
		# 体力不够就别开始，直接回森林；_ready 里换场景要延后，
		# 这期间 UI 还没建好，别再 tick
		set_physics_process(false)
		call_deferred("_bail_to_forest")
		return
	Controls.ensure()
	var camera: Camera3D = $Camera3D
	camera.position = CAMERA_POSITION
	camera.look_at(CAMERA_TARGET)

	var seed_value := randi()
	_round = BombRound.new(seed_value)
	_round.humans = Party.count()
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
		seat.setup(SEAT_COLORS[i], i if Party.human(i) else -1)
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
	# 倒数期间两个投掷键不接收触摸
	_ui.set_armed(false)

	# 开局那颗：模型已经点燃了，视觉上让它从篝火飞过去
	_round.events.clear()
	_launch_from_fire(_round.holder)


func _physics_process(delta: float) -> void:
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


## 场上的人全被炸死了才算这局看完（双人时剩下那个接着玩）。
func _humans_out() -> bool:
	for seat in Party.count():
		if _round.alive.has(seat):
			return false
	return true


## 座位名：人坐前几个，人机从后面补。
func _seat_names() -> Array:
	var names := []
	for seat in BombRound.SEATS:
		names.append(Party.name_of(seat) if Party.human(seat) else NPC_NAMES[seat - 1])
	return names


## 倒数期间按按钮不许记账：否则倒数一结束炸弹会自己飞出去（玩家根本没按）。
func _on_throw_pressed(player: int, side: int) -> void:
	if _countdown > 0.0 or _settled:
		return
	_round.request_throw(player, side)


## 键盘只喂一号位（触屏两个玩家各有一对投掷键）。
func _feed() -> void:
	if Input.is_action_just_pressed("move_left"):
		_round.request_throw(0, -1)
	if Input.is_action_just_pressed("move_right"):
		_round.request_throw(0, 1)


func _update_visuals(delta: float) -> void:
	var holder := _round.holder
	for i in _seats.size():
		var hurried := 0.0
		if i == holder and not Party.human(i):
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
	_sfx.set_danger(_round.danger(), Party.human(holder))


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
	# 每个玩家各自按名次算币，都进同一个钱包（一台手机一份存档）
	var earned := 0
	var ranks := []
	for seat in Party.count():
		var rank := BombScore.rank_of(seat, _round.death_order, _round.alive)
		ranks.append(rank + 1)
		earned += BombScore.coins(rank)
	Save.add_coins(earned)
	print("结算：%s 名，撑了 %d 秒，+%d 蘑菇币" % [str(ranks), int(_elapsed), earned])
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
	get_tree().reload_current_scene()


func _to_forest() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(Config.FOREST_PATH)


func _quit() -> void:
	get_tree().paused = false
	get_tree().quit()
