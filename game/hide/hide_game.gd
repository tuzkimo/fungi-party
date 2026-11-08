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


var _net: NetClient = null
var _active := false


func _process(_delta: float) -> void:
	if _net == null:
		_net = NetClient.of(get_tree())
		if _net == null:
			return
	# 名字要给全森林都藏起来（观战的人没有 SESSION，只能读 WORLD 里那个标记）
	NameTag.hidden = _net.hide_round
	if not _net.in_room("hide"):
		_release()
		return
	var phase := str((_net.session.get("game", {}) as Dictionary).get("phase", ""))
	var seeker := is_seeker(_net.session, _net.seat_index())
	_active = true
	for node in get_tree().get_nodes_in_group("player"):
		var player := node as Player
		if player == null:
			continue
		player.input_locked = locked(phase, seeker)
		player.speed_scale = speed_scale(phase, not seeker)


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
