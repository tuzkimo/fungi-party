class_name NetClient
extends Node

## 客户端网络会话：一根 ENet 连到服务器，握手登录，之后一次一条 op。
## 存档镜像 `data` 就是服务器上那份的副本，`Save` 在联机模式下读它、写它的 op。
##
## 心跳/重连一概没有（设计里一期不做）：掉线就 failed()，客户端回启动菜单。

signal logged_in
signal changed
signal failed(reason: String)

const CONNECT_TIMEOUT := 10.0
const REPLY_TIMEOUT := 10.0

enum State { IDLE, CONNECTING, AUTH, READY, DEAD }

## 服务器上那份存档的镜像
var data := {}
var player_name := ""
var state := State.IDLE

var _peer: ENetMultiplayerPeer
var _password := ""
var _nonce := ""
var _salt := ""
var _exists := false
var _queue: Array[Dictionary] = []
var _inflight := ""
var _waiting := 0.0
var _connecting := 0.0


## 登录（名字不存在就是注册，服务器自己认）。结果走 logged_in / failed。
func connect_to(host: String, port: int, name: String, password: String) -> void:
	close()
	player_name = name
	_password = password
	_peer = ENetMultiplayerPeer.new()
	var err := _peer.create_client(host, port)
	if err != OK:
		_dead("connect")
		return
	state = State.CONNECTING
	_connecting = 0.0


func close() -> void:
	if _peer != null:
		_peer.close()
		_peer = null
	state = State.IDLE
	_queue.clear()
	_inflight = ""
	data = {}


func ready() -> bool:
	return state == State.READY


## 服务器上那份存档的副本：调用方随便改，改了不算数（要改得发 op）。
func mirror() -> Dictionary:
	return data.duplicate(true) if not data.is_empty() else Save.defaults()


## 发一条 op。服务器回包后镜像更新并 emit changed。
func request(op: String, args: Dictionary = {}) -> void:
	if state != State.READY:
		return
	_queue.append({"op": op, "args": args})


func me() -> String:
	return player_name


func _process(delta: float) -> void:
	if _peer == null:
		return
	_peer.poll()
	_drain()
	if state == State.CONNECTING:
		_connecting += delta
		if _peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
			state = State.AUTH
			_send(NetProtocol.Msg.HELLO, {"name": player_name})
		elif _connecting > CONNECT_TIMEOUT:
			_dead("timeout")
	elif state == State.AUTH:
		_connecting += delta
		if _connecting > CONNECT_TIMEOUT:
			_dead("timeout")
	if state == State.READY and _inflight != "":
		_waiting += delta
		if _waiting > REPLY_TIMEOUT:
			_dead("timeout")
	_pump()


func _drain() -> void:
	while _peer.get_available_packet_count() > 0:
		var env := NetProtocol.unpack(_peer.get_packet())
		if not bool(env["ok"]):
			_dead(str(env["reason"]))
			return
		var body := env["body"] as Dictionary
		match int(env["kind"]):
			NetProtocol.Msg.CHALLENGE:
				_on_challenge(body)
			NetProtocol.Msg.WELCOME:
				_on_welcome(body)
			NetProtocol.Msg.OP_RESULT:
				_on_result(body)
			NetProtocol.Msg.ERROR:
				_dead(str(body.get("reason", "error")))


## 服务器发来盐和 nonce：老账号证明知道口令，新账号把派生密钥交上去当凭据。
func _on_challenge(body: Dictionary) -> void:
	_salt = str(body.get("salt", ""))
	_nonce = str(body.get("nonce", ""))
	_exists = bool(body.get("exists", false))
	var key := NetAuth.derive(_password, NetAuth.unhex(_salt))
	if _exists:
		_send(NetProtocol.Msg.PROOF, {"proof": NetAuth.hex(NetAuth.proof(key, NetAuth.unhex(_nonce)))})
	else:
		_send(NetProtocol.Msg.PROOF, {"key": NetAuth.hex(key)})
	_password = ""


func _on_welcome(body: Dictionary) -> void:
	data = Save.normalize(body.get("save", {}))
	if player_name == "":
		player_name = str(body.get("name", ""))
	state = State.READY
	logged_in.emit()


func _on_result(body: Dictionary) -> void:
	_inflight = ""
	_waiting = 0.0
	if body.has("save") and typeof(body["save"]) == TYPE_DICTIONARY:
		data = Save.normalize(body["save"])
	if not bool(body.get("ok", false)):
		print("服务器拒绝了 %s：%s" % [str(body.get("op", "")), str(body.get("error", ""))])
	changed.emit()


func _pump() -> void:
	if state != State.READY or _inflight != "" or _queue.is_empty():
		return
	var next: Dictionary = _queue.pop_front()
	_inflight = str(next["op"])
	_waiting = 0.0
	_send(NetProtocol.Msg.OP, {"op": _inflight, "args": next["args"]})


func _send(kind: int, body: Dictionary) -> void:
	var packet := NetProtocol.pack(kind, body)
	if packet.is_empty():
		return
	_peer.set_target_peer(MultiplayerPeer.TARGET_PEER_SERVER)
	_peer.put_packet(packet)


func _dead(reason: String) -> void:
	if state == State.DEAD:
		return
	state = State.DEAD
	_queue.clear()
	failed.emit(reason)
