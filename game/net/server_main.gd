extends SceneTree

## 无头服务器：一根 ENet 监听，收原始字节包（不走节点 RPC），一个连接一份会话。
##
##   godot --headless --path . --script res://game/net/server_main.gd -- --port 7000 --saves /var/lib/fungi/saves --max 8
##
## 服务器只认白名单 op，算完立刻落盘再回包 —— 客户端拿到的永远是服务器上那份。

const AUTH_TIMEOUT_SECONDS := 30.0
const DEFAULT_PORT := 7000
const DEFAULT_SAVES := "user://accounts"
## 上限 8 人：5 Mbps 带宽下 8 人全量广播约 1.1 Mbps，留足余量给小游戏
const DEFAULT_MAX := 8
## 房间类 op：它们要看会话/房间状态，所以不走 NetOps（那是对存档的纯函数）
const ROOM_OPS: Array[String] = ["invite", "answer", "leave_room"]

var _peer: ENetMultiplayerPeer
var _save_dir := DEFAULT_SAVES
## peer_id -> {name, nonce, salt, authed, since}
var _sessions := {}
## 邀请配对 + 同时只开一间房
var _lobby: NetLobby = null
var _room_timer := 0.0
## 世界时钟（三分之一个真实日）：天色由它给，三期接上客户端
var _world_clock := Config.MORNING_TIME
var _world_timer := 0.0


func _initialize() -> void:
	var opts := _parse_args(OS.get_cmdline_user_args())
	var port := int(opts.get("port", DEFAULT_PORT))
	_save_dir = str(opts.get("saves", DEFAULT_SAVES))
	_peer = ENetMultiplayerPeer.new()
	var err := _peer.create_server(port, int(opts.get("max", DEFAULT_MAX)))
	if err != OK:
		printerr("监听失败：%s（端口 %d）" % [error_string(err), port])
		# 把 _peer 抹掉，否则 _process 还会拿着一个没起来的 host 继续 poll
		_peer = null
		quit(1)
		return
	_peer.peer_disconnected.connect(_on_disconnect)
	_lobby = NetLobby.new(
		func(name: String) -> Dictionary:
			return Accounts.read(_save_dir, name),
		func(name: String, data: Dictionary) -> void:
			Accounts.write(_save_dir, name, data)
	)
	print("菌子派对服务器 协议 v%d 端口 %d 存档 %s" % [NetProtocol.VERSION, port, _save_dir])


func _process(_delta: float) -> bool:
	if _peer == null:
		return true
	_peer.poll()
	while _peer.get_available_packet_count() > 0:
		var from := _peer.get_packet_peer()
		_handle(from, _peer.get_packet())
	_drop_silent_peers()
	_world_timer += _delta
	if _world_timer >= 1.0 / Config.NET_WORLD_HZ:
		_world_timer = 0.0
		_broadcast_world()
	_lobby.tick(_delta)
	_room_timer += _delta
	if _lobby.room != null and _room_timer >= 1.0 / Config.NET_ROOM_HZ:
		_room_timer = 0.0
		_broadcast_session()
		if _lobby.room.over:
			# 最后一帧已经带着 over 发出去了，房位腾给下一局
			_lobby.room = null
	return false


func _handle(from: int, packet: PackedByteArray) -> void:
	var env := NetProtocol.unpack(packet)
	if not bool(env["ok"]):
		_send(from, NetProtocol.Msg.ERROR, {"reason": env["reason"]})
		return
	if not _sessions.has(from):
		_sessions[from] = {"name": "", "nonce": "", "salt": "", "authed": false, "since": _now()}
	var session: Dictionary = _sessions[from]
	var body := env["body"] as Dictionary
	match int(env["kind"]):
		NetProtocol.Msg.HELLO:
			_on_hello(from, session, body)
		NetProtocol.Msg.PROOF:
			_on_proof(from, session, body)
		NetProtocol.Msg.OP:
			_on_op(from, session, body)
		NetProtocol.Msg.MOVE:
			_on_move(session, body)
		NetProtocol.Msg.INPUT:
			_on_input(session, body)
		_:
			_send(from, NetProtocol.Msg.ERROR, {"reason": "kind"})


## 第一步：报名字。服务器发一份盐和这次连接的 nonce（新名字也发，注册要用同一份盐）。
func _on_hello(from: int, session: Dictionary, body: Dictionary) -> void:
	var player_name := str(body.get("name", ""))
	var challenge := Accounts.challenge(_save_dir, player_name)
	if not bool(challenge["ok"]):
		_send(from, NetProtocol.Msg.ERROR, {"reason": "name"})
		return
	var nonce := NetAuth.hex(NetAuth.random_bytes(16))
	session["name"] = player_name
	session["salt"] = str(challenge["salt"])
	session["nonce"] = nonce
	session["authed"] = false
	_send(from, NetProtocol.Msg.CHALLENGE, {
		"exists": bool(challenge["exists"]),
		"salt": str(challenge["salt"]),
		"nonce": nonce,
	})


## 第二步：老账号证明自己知道口令（proof），新账号把派生密钥交上来当凭据。
func _on_proof(from: int, session: Dictionary, body: Dictionary) -> void:
	var player_name := str(session.get("name", ""))
	if player_name == "":
		_send(from, NetProtocol.Msg.ERROR, {"reason": "state"})
		return
	if Accounts.exists(_save_dir, player_name):
		if not Accounts.verify(_save_dir, player_name, str(body.get("proof", "")), str(session["nonce"])):
			print("%s 登录失败" % player_name)
			_send(from, NetProtocol.Msg.ERROR, {"reason": "auth"})
			return
	else:
		var made := Accounts.register(_save_dir, player_name, str(session["salt"]), str(body.get("key", "")))
		if not bool(made["ok"]):
			_send(from, NetProtocol.Msg.ERROR, {"reason": str(made.get("error", "auth"))})
			return
		print("%s 注册成功" % player_name)
	session["authed"] = true
	session["nonce"] = ""
	_send(from, NetProtocol.Msg.WELCOME, {
		"name": player_name,
		"save": Accounts.read(_save_dir, player_name),
	})


func _on_op(from: int, session: Dictionary, body: Dictionary) -> void:
	if not bool(session.get("authed", false)):
		_send(from, NetProtocol.Msg.ERROR, {"reason": "auth"})
		return
	var player_name := str(session["name"])
	var op := str(body.get("op", ""))
	var args: Variant = body.get("args", {})
	if typeof(args) != TYPE_DICTIONARY:
		_send(from, NetProtocol.Msg.OP_RESULT, {"op": op, "ok": false, "error": "args"})
		return
	if ROOM_OPS.has(op):
		_on_room_op(from, player_name, op, args as Dictionary)
		return
	var result := NetOps.apply(Accounts.read(_save_dir, player_name), op, args as Dictionary)
	if bool(result["ok"]):
		Accounts.write(_save_dir, player_name, result["data"] as Dictionary)
	_send(from, NetProtocol.Msg.OP_RESULT, {
		"op": op,
		"ok": bool(result["ok"]),
		"error": str(result.get("error", "")),
		"result": result.get("result", {}),
		"save": result["data"],
	})


## 别人的位置：这是唯一一条不落盘、不回包的消息，只往世界里广播。
## 位置是信任边界，但作弊后果只有「他飘到别处」：非有限数、飞天、瞬移一律不采信。
func _on_move(session: Dictionary, body: Dictionary) -> void:
	if not bool(session.get("authed", false)):
		return
	# slot 0 = 这台手机的主人，slot 1 = 同屏的 2P（两个人共用一个账号，各报各的）
	var slot := int(body.get("slot", 0))
	if slot < 0 or slot > 1:
		return
	var spot := Vector3(float(body.get("x", 0.0)), float(body.get("y", 0.0)), float(body.get("z", 0.0)))
	if not spot.is_finite():
		return
	spot.y = clampf(spot.y, 0.0, 6.0)
	var slots: Dictionary = session.get("slots", {})
	var last: Variant = slots.get(slot, null)
	if last != null and (spot - Vector3((last as Dictionary)["pos"])).length() > Config.NET_MOVE_MAX_STEP * 2.0:
		return
	var skin := str(body.get("skin", ""))
	slots[slot] = {
		"pos": spot,
		"yaw": float(body.get("yaw", 0.0)),
		"body": BodyCatalog.normalize(str(body.get("body", ""))),
		"skin": skin if SkinCatalog.by_id(skin) != null else "",
	}
	session["slots"] = slots


## 邀请 / 回答邀请。这两条也要回 OP_RESULT：客户端的 _inflight 只认它，不回就是 10 秒后掉线。
func _on_room_op(from: int, me: String, op: String, args: Dictionary) -> void:
	var online := _online()
	var now := _now()
	var result: Dictionary
	match op:
		"invite":
			result = _lobby.invite(me, str(args.get("to", "")), str(args.get("kind", "")), online, now)
		"answer":
			result = _lobby.answer(
				str(args.get("from", "")), me, str(args.get("kind", "")),
				bool(args.get("accept", false)), online, now
			)
		_:
			# leave_room：主动回森林，房腾出来（收益照结算）
			_lobby.leave(me)
			result = {"ok": true}
	var saves: Dictionary = result.get("saves", {})
	for name in saves:
		Accounts.write(_save_dir, str(name), saves[name] as Dictionary)
	if not saves.is_empty():
		_push_session(result)
	_send(from, NetProtocol.Msg.OP_RESULT, {
		"op": op,
		"ok": bool(result["ok"]),
		"error": str(result.get("error", "")),
		"result": result.get("result", {}),
		"save": saves.get(me, Accounts.read(_save_dir, me)),
	})


## 成局：房快照 + 各自扣完体力那份存档，各发一份（邀请方的那份只能这样送到）
func _push_session(result: Dictionary) -> void:
	var room: NetRoom = result["room"]
	var saves: Dictionary = result["saves"]
	# 快照只拍一次：传炸弹的快照会把「上次之后发生的事」清掉，每人一份不能靠重复拍
	var base := room.snapshot()
	for name in saves:
		var id := _peer_of(str(name))
		if id == 0:
			continue
		var body := base.duplicate(true)
		body["save"] = saves[name]
		_send(id, NetProtocol.Msg.SESSION, body)


## 每 1/20 秒把这一局的快照发给局里的真人（人机没连接，跳过）
func _broadcast_session() -> void:
	var room := _lobby.room
	if room == null:
		return
	var base := room.snapshot()
	for seat in room.seats:
		if bool(seat["npc"]):
			continue
		var id := _peer_of(str(seat["account"]))
		if id == 0:
			continue
		var body := base.duplicate(true)
		if room.over:
			# 结算已经落盘：每人配一份刚入账的存档，客户端 HUD 才看得见币
			body["save"] = Accounts.read(_save_dir, str(seat["account"]))
		_send(id, NetProtocol.Msg.SESSION, body)


## 局内输入：只看在不在局里，输入本身由规则模型在 tick 里消化；不回包。
func _on_input(session: Dictionary, body: Dictionary) -> void:
	if not bool(session.get("authed", false)) or _lobby.room == null:
		return
	_lobby.room.input(str(session["name"]), body)


## 每 1/10 秒给每个登录的人一份世界快照（各自一份：邀请是发给具体某个人的）。
func _broadcast_world() -> void:
	var players := {}
	for id in _sessions:
		var session: Dictionary = _sessions[id]
		if not bool(session.get("authed", false)):
			continue
		var account := str(session["name"])
		var slots: Dictionary = session.get("slots", {})
		for slot in slots:
			var state: Dictionary = slots[slot]
			var spot: Vector3 = state["pos"]
			var key := account if int(slot) == 0 else "%s|1" % account
			players[key] = {
				"x": spot.x, "y": spot.y, "z": spot.z,
				"yaw": float(state["yaw"]),
				"body": str(state["body"]),
				"skin": str(state["skin"]),
				"name": account if int(slot) == 0 else "%s 2P" % account,
			}
	for id in _sessions:
		var session: Dictionary = _sessions[id]
		if not bool(session.get("authed", false)):
			continue
		_send(int(id), NetProtocol.Msg.WORLD, {
			"clock": _world_clock,
			"players": players,
			"me": str(session["name"]),
			"invites": _lobby.invites_for(str(session["name"]), _online(), _now()),
		})


## 此刻登录着的人：邀请校验和广播都用得着
func _online() -> PackedStringArray:
	var out := PackedStringArray()
	for id in _sessions:
		var session: Dictionary = _sessions[id]
		if bool(session.get("authed", false)):
			out.append(str(session["name"]))
	return out


## 账号 → 连接。不在线返回 0（peer id 不会是 0）。
func _peer_of(player_name: String) -> int:
	for id in _sessions:
		var session: Dictionary = _sessions[id]
		if bool(session.get("authed", false)) and str(session["name"]) == player_name:
			return int(id)
	return 0


func _send(to: int, kind: int, body: Dictionary) -> void:
	var packet := NetProtocol.pack(kind, body)
	if packet.is_empty():
		# 超长包会被静默丢掉，看起来像「服务器突然不广播了」：宁可刷日志也别装没事
		push_error("打包失败：kind %d 超过 %d 字节，这封没发出去" % [kind, NetProtocol.MAX_PACKET])
		return
	_peer.set_target_peer(to)
	_peer.put_packet(packet)


## 连着不登录的挂机连接：占着名额不干活，到点踢掉
func _drop_silent_peers() -> void:
	var deadline: Array[int] = []
	for id in _sessions:
		var session: Dictionary = _sessions[id]
		if not bool(session.get("authed", false)) and _now() - float(session.get("since", 0.0)) > AUTH_TIMEOUT_SECONDS:
			deadline.append(int(id))
	for id in deadline:
		_sessions.erase(id)
		_peer.disconnect_peer(id)


func _on_disconnect(id: int) -> void:
	if _sessions.has(id):
		var player_name := str(_sessions[id].get("name", "?"))
		print("%s 断开" % player_name)
		_sessions.erase(id)
		_lobby.leave(player_name)


func _now() -> float:
	return float(Time.get_ticks_msec()) / 1000.0


## `-- --port 7000 --saves /x --max 8`
func _parse_args(args: PackedStringArray) -> Dictionary:
	var out := {}
	var i := 0
	while i < args.size():
		var key := args[i]
		if key.begins_with("--") and i + 1 < args.size():
			out[key.substr(2)] = args[i + 1]
			i += 2
		else:
			i += 1
	return out
