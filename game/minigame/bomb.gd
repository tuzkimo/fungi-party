extends Node3D

## 传炸弹编排：把 BombRound 的状态喂给座位、炸弹、音效，读玩家输入。
## 自包含单场景：节点间直接引用；模型不碰节点，每局新种子（randi()），绝不写死。

const SEAT_NAMES := ["你", "蓝", "红", "紫"]
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


func _ready() -> void:
	Controls.ensure()
	var camera: Camera3D = $Camera3D
	camera.position = CAMERA_POSITION
	camera.look_at(CAMERA_TARGET)

	var seed_value := randi()
	_round = BombRound.new(seed_value)
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
		seat.setup(SEAT_COLORS[i], i == BombRound.PLAYER)
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
	_ui.throw_pressed.connect(func(side: int) -> void: _round.request_throw(side))

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
	if _settled:
		return

	_elapsed += delta
	_round.tick(delta)
	_feed()
	_drain_events()
	_update_visuals(delta)
	if _round.over or not _round.alive.has(BombRound.PLAYER):
		_settle()


func _feed() -> void:
	if Input.is_action_just_pressed("move_left"):
		_round.request_throw(-1)
	if Input.is_action_just_pressed("move_right"):
		_round.request_throw(1)


func _update_visuals(delta: float) -> void:
	var holder := _round.holder
	for i in _seats.size():
		var hurried := 0.0
		if i == holder and i != BombRound.PLAYER:
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
	_sfx.set_danger(_round.danger(), holder == BombRound.PLAYER)


func _drain_events() -> void:
	for event in _round.events:
		_handle_event(event)
	_round.events.clear()


func _handle_event(event: Dictionary) -> void:
	match event["kind"]:
		"ignite":
			var seat: int = event["seat"]
			print("点燃：%s" % SEAT_NAMES[seat])
			_launch_from_fire(seat)
		"throw":
			var from: int = event["from"]
			var to: int = event["to"]
			print("扔出：%s → %s" % [SEAT_NAMES[from], SEAT_NAMES[to]])
			_sfx.play("throw")
			_visual_flight = true
			_bomb.start_flight(_head_of(from), _head_of(to), Config.BOMB_THROW_SECONDS)
		"explode":
			var seat: int = event["seat"]
			print("爆炸：%s（%s）" % [SEAT_NAMES[seat], "空中" if bool(event["in_flight"]) else "手上"])
			_sfx.play("boom")
			_bomb.hide_bomb()
			_visual_flight = false
		"over":
			print("结束：%s 活到最后" % SEAT_NAMES[int(event["winner"])])
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
	var rank := BombScore.rank_of(BombRound.PLAYER, _round.death_order, _round.alive)
	var earned := BombScore.coins(rank)
	Save.add_coins(earned)
	print("结算：第 %d 名，撑了 %d 秒，+%d 蘑菇币" % [rank + 1, int(_elapsed), earned])
	_ui.show_result(
		rank + 1, _elapsed, earned, BombScore.rows(_round.death_order, _round.alive, SEAT_NAMES)
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
