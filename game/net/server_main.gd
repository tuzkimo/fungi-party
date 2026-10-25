extends SceneTree

## 无头服务器：一根 ENet 监听，收原始字节包（不走节点 RPC），一个连接一份会话。
##
##   godot --headless --path . --script res://game/net/server_main.gd -- --port 7000 --saves /var/lib/fungi/saves --max 32
##
## 服务器只认白名单 op，算完立刻落盘再回包 —— 客户端拿到的永远是服务器上那份。

const AUTH_TIMEOUT_SECONDS := 30.0
const DEFAULT_PORT := 7000
const DEFAULT_SAVES := "user://accounts"
const DEFAULT_MAX := 32

var _peer: ENetMultiplayerPeer
var _save_dir := DEFAULT_SAVES
## peer_id -> {name, nonce, salt, authed, since}
var _sessions := {}


func _initialize() -> void:
	var opts := _parse_args(OS.get_cmdline_user_args())
	var port := int(opts.get("port", DEFAULT_PORT))
	_save_dir = str(opts.get("saves", DEFAULT_SAVES))
	_peer = ENetMultiplayerPeer.new()
	var err := _peer.create_server(port, int(opts.get("max", DEFAULT_MAX)))
	if err != OK:
		printerr("监听失败：%s（端口 %d）" % [error_string(err), port])
		quit(1)
		return
	_peer.peer_disconnected.connect(_on_disconnect)
	print("菌子派对服务器 协议 v%d 端口 %d 存档 %s" % [NetProtocol.VERSION, port, _save_dir])


func _process(_delta: float) -> bool:
	if _peer == null:
		return true
	_peer.poll()
	while _peer.get_available_packet_count() > 0:
		var from := _peer.get_packet_peer()
		_handle(from, _peer.get_packet())
	_drop_silent_peers()
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


func _send(to: int, kind: int, body: Dictionary) -> void:
	var packet := NetProtocol.pack(kind, body)
	if packet.is_empty():
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
		print("%s 断开" % str(_sessions[id].get("name", "?")))
		_sessions.erase(id)


func _now() -> float:
	return float(Time.get_ticks_msec()) / 1000.0


## `-- --port 7000 --saves /x --max 32`
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
