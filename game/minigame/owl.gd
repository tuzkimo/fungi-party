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


func _bail_to_forest() -> void:
	get_tree().change_scene_to_file(Config.FOREST_PATH)


func _ready() -> void:
	if not Save.spend_stamina(Config.STAMINA_COST_OWL):
		# 体力不够就别开始，直接回森林；_ready 里换场景要延后，这期间别再 tick
		set_physics_process(false)
		call_deferred("_bail_to_forest")
		return
	Controls.ensure()
	var camera: Camera3D = $Camera3D
	camera.position = CAMERA_POSITION
	camera.fov = CAMERA_FOV
	camera.look_at(CAMERA_TARGET)

	var seed_value := randi()
	_round = OwlRound.new(seed_value)
	_round.humans = Party.count()
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
	for seat in Party.count():
		_actors[seat].apply_look(seat)

	_ui = $UI
	_ui.set_names(_names)
	_ui.set_hint("两人各按自己那半边屏幕：按住 = 张嘴，松开 = 闭嘴" if Party.joined() else "")
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
	match _phase:
		Phase.COUNTDOWN:
			_tick_countdown(delta)
		Phase.PLAY:
			_play(delta)
		Phase.BREAK:
			_tick_break(delta)


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
	for seat in OwlRound.SEATS:
		names.append(Party.name_of(seat) if Party.human(seat) else NPC_NAMES[seat - 1])
	return names


func _scores() -> Array:
	var scores := []
	for mouth in _round.mouths:
		scores.append(mouth.score)
	return scores


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
			"human": Party.human(index),
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
	var scores := _scores()
	var order := OwlRound.ranking(scores)
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
	get_tree().reload_current_scene()


func _to_forest() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(Config.FOREST_PATH)


func _quit() -> void:
	get_tree().paused = false
	get_tree().quit()
