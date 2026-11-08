class_name HideGame
extends Node

## 森林里那一局捉迷藏：不换场景，按服务器的 SESSION 快照锁人、降速、藏名字、转给面板。
## 进局 / 收局全看 `NetClient.in_room("hide")`：over 之后它自己就是 false，所以「收局」不用另写一条路。

## 找的人在 30 秒倒数里黑屏站着，动不了；藏的人这段满速去藏
static func locked(phase: String, seeker: bool) -> bool:
	return seeker and phase == "countdown"


## 找的阶段藏的人降速：同速跑起来永远捉不到，躲才是正解
static func speed_scale(phase: String, hider: bool) -> float:
	return Config.HIDE_HIDER_SPEED if hider and phase == "seeking" else 1.0


## 我这一台是不是「找的人」（座位号由服务器给，一个账号算一个角色）
static func is_seeker(session: Dictionary, my_seat: int) -> bool:
	var game: Dictionary = session.get("game", {})
	if game.is_empty():
		return false
	return int(game.get("seeker", -1)) == my_seat


## 屏幕顶上的那一句：「快去藏 / 别偷看 / 去捉他 / 藏好，别动」
static func hint_text(phase: String, seeker: bool) -> String:
	if phase == "countdown":
		return "\u522b\u5077\u770b" if seeker else "\u5feb\u53bb\u85cf"
	return "\u53bb\u6349\u4ed6" if seeker else "\u85cf\u597d\uff0c\u522b\u52a8"


## 结算那一行：赢的 +5、输的 -5、没算钱（掉线 / 放弃前就收了）
static func result_text(earned: int) -> String:
	if earned > 0:
		return "\u4f60\u8d62\u4e86 +%d \u8611\u83c7\u5e01" % earned
	if earned < 0:
		return "\u4f60\u8f93\u4e86 %d \u8611\u83c7\u5e01" % absi(earned)
	return "\u8fd9\u4e00\u5c40\u6ca1\u7b97\u94b1"


@export var panel_path: NodePath

var _net: NetClient = null
var _panel: HidePanel = null
var _active := false
## 收局之后结果那行字还留多久（秒）
var _result_left := 0.0


func _ready() -> void:
	if panel_path.is_empty():
		return
	_panel = get_node_or_null(panel_path) as HidePanel
	if _panel == null:
		return
	_panel.catch_pressed.connect(_on_catch)
	_panel.give_up_pressed.connect(_on_give_up)


func _process(delta: float) -> void:
	if _net == null:
		_net = NetClient.of(get_tree())
		if _net == null:
			return
	# 名字要给全森林都藏起来（观战的人没有 SESSION，只能读 WORLD 里那个标记）
	NameTag.hidden = _net.hide_round
	if not _net.in_room("hide"):
		if _active:
			_finish()
		if _result_left > 0.0:
			_result_left -= delta
			if _result_left <= 0.0:
				_result_left = 0.0
				if _panel != null:
					_panel.close()
		return
	var game: Dictionary = _net.session.get("game", {})
	var phase := str(game.get("phase", ""))
	var seeker := is_seeker(_net.session, _net.seat_index())
	_active = true
	for node in get_tree().get_nodes_in_group("player"):
		var player := node as Player
		if player == null:
			continue
		player.input_locked = locked(phase, seeker)
		player.speed_scale = speed_scale(phase, not seeker)
	if _panel == null:
		return
	var target := ""
	if seeker and bool(game.get("can_catch", false)):
		target = _seat_name(int(game.get("hider", -1)))
	_panel.set_target(target)
	_panel.show_round(locked(phase, seeker), float(game.get("left", 0.0)), hint_text(phase, seeker))


## 我这一局结束后服务器还留着快照：从里面捡自己那份收益
func _finish() -> void:
	var earned := int((_net.session.get("earned", {}) as Dictionary).get(_net.player_name, 0))
	_release()
	_result_left = 4.0
	if _panel != null:
		_panel.show_result(result_text(earned))


func _seat_name(seat: int) -> String:
	var seats: Array = _net.session.get("seats", [])
	if seat < 0 or seat >= seats.size():
		return ""
	return str((seats[seat] as Dictionary).get("account", ""))


func _on_catch() -> void:
	if _net != null:
		_net.send_input({"catch": true})


## 放弃 = 认输，照常结账（服务器那条路是 NetLobby.forfeit）
func _on_give_up() -> void:
	if _net != null:
		_net.request("leave_room")


## 收局 / 掉线 / 不是这一局：把所有锁和减速还回去（浮层由面板自己收）
func _release() -> void:
	if not _active:
		return
	_active = false
	for node in get_tree().get_nodes_in_group("player"):
		var player := node as Player
		if player == null:
			continue
		player.input_locked = false
		player.speed_scale = 1.0
