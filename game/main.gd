extends Node3D

## 森林（主场景）：同屏双人的二号位在这里生灭，别的地方都不管。
## 两个人谁推摇杆谁带队：领队自由走、另一个人跟在他身后，镜头跟着领队。
## 返回键维持「直接退出游戏」的老行为（赛跑场景自己处理返回键，所以全局关掉了 quit_on_go_back）。

const PLAYER_SCENE := "res://game/player/mushroom.tscn"

var _first: Player = null
var _second: Player = null

@onready var _join_panel: JoinPanel = $JoinPanel
@onready var _invite_panel: InvitePanel = $InvitePanel
@onready var _forest: Node3D = $Forest
@onready var _start_menu: StartMenu = $StartMenu

## 联网会话挂在根上，不随场景一起换掉（进小游戏再回森林也还在）
var _net: NetClient = null
## 森林里别人的替身：账号 → RemotePlayer
var _ghosts := {}
var _move_timer := 0.0


func _ready() -> void:
	_join_panel.join_pressed.connect(_on_join)
	_join_panel.leave_pressed.connect(_on_leave)
	_invite_panel.invite_pressed.connect(_on_invite)
	_invite_panel.answer_pressed.connect(_on_answer)
	_invite_panel.logout_pressed.connect(_on_logout)
	_first = Player.of_seat(get_tree(), 0)
	_spawn_second()
	_net = _ensure_net()
	_net.join_room.connect(_on_join_room)
	if _net.ready():
		# 从小游戏转回来：联网会话还在，不用再登录
		_start_menu.visible = false
		_go_online()
	else:
		Save.remote = null
		_start_menu.setup(_net)
		_start_menu.auto_login()
		_start_menu.online_ready.connect(_on_online_ready)


## 根上已经有一个就复用：换场景不会把它带走，重登会多出一个来抢同一份存档。
func _ensure_net() -> NetClient:
	var existing := get_tree().root.get_node_or_null("Net")
	if existing is NetClient:
		return existing
	var net := NetClient.new()
	net.name = "Net"
	# 启动时引擎正在往 root 里装初始场景，那一刻 root 是 blocked 的，直接 add_child 会失败
	# （Parent node is busy setting up children）——Net 就一直不在树里，_process 不跑，联网等于死。
	get_tree().root.add_child.call_deferred(net)
	return net


## 服务器把我拉进一局了：换到那一款小游戏。
## shortcut: 只有森林接 join_room —— 能「接受邀请」的也只有这里那层浮层；
## 哪天小游戏里也能收邀请，这层得挪到常驻的 Net 上。
func _on_join_room() -> void:
	if _net == null:
		return
	var path := NetRoom.scene_path(str(_net.session.get("kind", "")))
	if path == "":
		push_error("服务器给的 kind 不认识：%s" % str(_net.session.get("kind", "")))
		return
	get_tree().change_scene_to_file(path)


func _on_online_ready() -> void:
	_go_online()


## 联网之后森林里才有一套：存档镜像、别人的替身、邀请浮层、服务器的消息。
## 登录成功和从小游戏转回来都走这里。
func _go_online() -> void:
	Save.remote = _net
	_refresh_looks()
	# 登出再登录会走第二遍：已经连过的信号不能重连，否则替身每帧重建两遍
	if not _net.world_changed.is_connected(_on_world):
		_net.world_changed.connect(_on_world)
	if not _net.changed.is_connected(_on_net_changed):
		_net.changed.connect(_on_net_changed)
	_invite_panel.set_online(true)
	_invite_panel.sync(_net.world, _net.invites)


## 主动登出：断开连接、清掉别处替身，回到登录表单（存档在服务器上，一样都没丢）。
func _on_logout() -> void:
	Save.remote = null
	for key in _ghosts.keys():
		(_ghosts[key] as Node).queue_free()
	_ghosts.clear()
	_invite_panel.set_online(false)
	_start_menu.visible = true
	_start_menu.forget()


func _on_invite(to: String, kind: String) -> void:
	_invite_panel.set_status("")
	_net.request("invite", {"to": to, "kind": kind})


func _on_answer(from: String, kind: String, accept: bool) -> void:
	_invite_panel.set_status("")
	_net.request("answer", {"from": from, "kind": kind, "accept": accept})


## 邀请被拒（体力不够 / 对方下线 / 已经有一局在开）要说一声，不然按下去像没反应。
func _on_net_changed() -> void:
	var op := str(_net.last_result.get("op", ""))
	# 皮肤和角色是服务器改的：镜像刚刚刷新过，本机这个人的外观跟着重刷（否则自己看着还是旧的）
	if bool(_net.last_result.get("ok", false)) and op in ["equip", "set_character", "pull"]:
		_refresh_looks()
	if op != "invite" and op != "answer":
		return
	if bool(_net.last_result.get("ok", false)):
		if op == "invite":
			_invite_panel.set_status("已邀请 %s，等他答应" % _invite_panel.waiting_for())
		return
	_invite_panel.set_status(InvitePanel.error_text(str(_net.last_result.get("error", ""))))


## 联网时把自己（和同屏的 2P）报上去，别人才能看见
func _process(delta: float) -> void:
	if _net == null or not _net.ready():
		return
	_move_timer += delta
	if _move_timer >= 1.0 / Config.NET_MOVE_HZ:
		_move_timer = 0.0
		_report_position(0, _first)
		_report_position(1, _second)
	_animate_ghosts(delta)


func _report_position(slot: int, player: Player) -> void:
	if player == null:
		return
	var look := Party.look(slot)
	_net.send_move(
		slot, player.global_position, player.rotation.y,
		str(look["body"]), str(look["skin"])
	)


## 服务器说世界变了：新建、更新、删掉替身
func _on_world() -> void:
	if _forest == null or _net == null:
		return
	for key in _net.world:
		if _ghosts.has(key):
			continue
		var state: Dictionary = _net.world[key]
		var ghost := RemotePlayer.new()
		ghost.name = "Ghost_%s" % str(key).replace("|", "_")
		_forest.add_child(ghost)
		ghost.setup(str(state.get("name", key)), str(state.get("body", "")), str(state.get("skin", "")))
		ghost.apply(state, 0.0, true)
		_ghosts[key] = ghost
	for key in _ghosts.keys():
		if not _net.world.has(key):
			(_ghosts[key] as Node).queue_free()
			_ghosts.erase(key)
	_invite_panel.sync(_net.world, _net.invites)


func _animate_ghosts(delta: float) -> void:
	for key in _ghosts:
		var ghost: RemotePlayer = _ghosts[key]
		var state: Dictionary = _net.world.get(key, {})
		if state.is_empty():
			continue
		var before := ghost.global_position
		ghost.apply(state, delta)
		ghost.bob(delta, before.distance_to(ghost.global_position) > 0.002)


func _refresh_looks() -> void:
	for node in get_tree().get_nodes_in_group("player"):
		var player := node as Player
		if player != null:
			player.refresh_look()


## 领队没推摇杆、另一个人推了，就把方向盘交出去（镜头一并换到新领队身上）。
func _physics_process(_delta: float) -> void:
	if _first == null or _second == null:
		return
	var lead := _lead()
	var other := _second if lead == _first else _first
	if Player.should_swap(lead.wants_to_lead(), other.wants_to_lead()):
		lead.leader = other
		lead.set_leading(false)
		other.leader = null
		other.set_leading(true)


func _lead() -> Player:
	return _second if _first.leader != null else _first


func _on_join(body_id: String, skin_id: String) -> void:
	Party.join(body_id, skin_id)
	_spawn_second()


func _on_leave() -> void:
	Party.leave()
	if _second != null:
		# 二号位可能正在带队：把方向盘和镜头还给一号位
		if _first != null:
			_first.leader = null
			_first.set_leading(true)
		_second.queue_free()
		_second = null


## 从任何小游戏回森林时也走这里：Party 还记着二号位，就把他重建出来。
func _spawn_second() -> void:
	if _second != null or not Party.joined():
		return
	var first := Player.of_seat(get_tree(), 0)
	if first == null:
		return
	_first = first
	var second := load(PLAYER_SCENE).instantiate() as Player
	second.name = "Player2"
	second.seat = 1
	# leader 必须在 add_child 之前给：_ready 里靠它决定拿不拿镜头
	second.leader = first
	# 位置也必须先摆好再入树：先入树会在原点登记碰撞体，第一帧和一号位重叠，
	# 两台一起被顶开 —— 一号位会被顶到二号位头上，然后被一路推着走
	second.position = Player.follow_point(
		first.global_position, first.global_basis,
		Config.PARTY_FOLLOW_GAP, Config.PARTY_FOLLOW_SIDE
	)
	_forest.add_child(second)
	_second = second


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		get_tree().quit()
