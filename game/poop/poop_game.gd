class_name PoopGame
extends Node

## 森林里那一局扔粑粑：不换场景，按服务器的 SESSION 快照刷面板和准星。
## 弹药、命中、胜负全在服务器：这里只说「我按了扔，方向是这个」，**没有本机冷却也没有本机弹药判断**。
## 这一局没人被冻住、也没有降速，所以不碰任何人的 input_locked / speed_scale。

## 屏幕顶上那一句：我的命中数 / 对方的命中数 / 剩余时间
static func top_text(mine: int, theirs: int, left: float) -> String:
	return "你 %d/%d   他 %d/%d   剩 %s" % [
		mine, Config.POOP_HITS, theirs, Config.POOP_HITS, UIStyle.clock_text(left)
	]


## 结算那一行：赢的 +5、输的 -5、没算钱（掉线 / 到点平局）
static func result_text(earned: int) -> String:
	if earned > 0:
		return "你赢了 +%d 蘑菇币" % earned
	if earned < 0:
		return "你输了 %d 蘑菇币" % absi(earned)
	return "这一局没算钱"


## 扔的方向：相机正前方，俯仰也照抄 —— 和 FPS 一样，准星抬到哪就往哪扔（`_aim_point` 画的就是这条线）。
## 想打平飞就得把镜头放平：相机俯着看人时扔出去的本来就是斜向下的那一发。
static func aim_dir(basis: Basis) -> Vector3:
	var forward := -basis.z
	return forward.normalized() if forward.length() > 0.0 else Vector3.FORWARD


@export var panel_path: NodePath

var _net: NetClient = null
var _panel: PoopPanel = null
var _active := false
## 收局之后结果那行字还留多久（秒）
var _result_left := 0.0


func _ready() -> void:
	if panel_path.is_empty():
		return
	_panel = get_node_or_null(panel_path) as PoopPanel
	if _panel == null:
		return
	_panel.throw_pressed.connect(_on_throw)
	_panel.give_up_pressed.connect(_on_give_up)


func _process(delta: float) -> void:
	if _net == null:
		_net = NetClient.of(get_tree())
		if _net == null:
			return
	if not _net.in_room("poop"):
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
	var seat := _net.seat_index()
	var hits: Array = game.get("hits", [])
	var ammo: Array = game.get("ammo", [])
	_active = true
	if _panel == null:
		return
	_panel.set_aim(_aim_point())
	_panel.show_round(
		top_text(_at(hits, seat), _at(hits, 1 - seat), float(game.get("left", 0.0))),
		_at(ammo, seat)
	)


## 我这一局结束后服务器还留着快照：从里面捡自己那份收益
func _finish() -> void:
	var earned := int((_net.session.get("earned", {}) as Dictionary).get(_net.player_name, 0))
	_active = false
	_result_left = 4.0
	if _panel != null:
		_panel.show_result(result_text(earned))


func _on_throw() -> void:
	if _net == null:
		return
	var dir := _throw_dir()
	_net.send_input({"slot": _owner_slot(), "dirx": dir.x, "diry": dir.y, "dirz": dir.z})


## 镜头现在挂在谁身上就是谁在扔（同屏 2P 谁推摇杆谁带队、谁拿镜头）。
func _owner_slot() -> int:
	var player := _owner()
	return clampi(player.seat, 0, 1) if player != null else 0


func _owner() -> Player:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return null
	var rig := camera.get_parent()
	return (rig.get_parent() if rig != null else null) as Player


## 准星该画在哪：把「粑粑会飞到的那一点」投到屏幕上 —— 从自己的胸口沿扔的方向飞一个射程。
## 出手点在胸口、相机在身后，所以它比正中略低一点；没相机就回 (-1, -1)，面板自己画在正中。
func _aim_point() -> Vector2:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return Vector2(-1.0, -1.0)
	var player := _owner()
	var from: Vector3 = player.global_position if player != null else camera.global_position
	return camera.unproject_position(from + Vector3(0.0, Config.POOP_CHEST, 0.0) + _throw_dir() * Config.POOP_RANGE)


func _throw_dir() -> Vector3:
	var camera := get_viewport().get_camera_3d()
	return aim_dir(camera.global_basis) if camera != null else Vector3.FORWARD


## 放弃 = 认输，照常结账（服务器那条路是 NetLobby.forfeit）
func _on_give_up() -> void:
	if _net != null:
		_net.request("leave_room")


static func _at(values: Array, seat: int) -> int:
	if seat < 0 or seat >= values.size():
		return 0
	return int(values[seat])
