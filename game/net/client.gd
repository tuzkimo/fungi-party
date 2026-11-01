class_name NetClient
extends Node

## 客户端网络会话：一根 ENet 连到服务器，握手登录，之后一次一条 op。
## 存档镜像 `data` 就是服务器上那份的副本，`Save` 在联机模式下读它、写它的 op。
##
## 心跳/重连一概没有（设计里一期不做）：掉线就 failed()，客户端回启动菜单。

signal logged_in
signal world_changed
signal changed
## 服务器把我拉进一局了：现在的场景该换成这一款小游戏
signal join_room
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
## 最后一条 op 的服务器回包（商店要拿抽卡结果放演出）
var last_result := {}
## 世界快照：{账号: {x,y,z,yaw,body,skin}}，不含自己
var world := {}
## 服务器给的世界时钟（0~1 的一天）
var clock := Config.MORNING_TIME
## 谁在邀请我：[{from, kind}]，跟着 WORLD 一起来
var invites := []
## 我所在的这一局（服务器发的快照）；空 = 不在局里
var session := {}

var _queue: Array[Dictionary] = []
var _inflight := ""
var _waiting := 0.0
var _connecting := 0.0
## join_room 只在「从不在局里变成在局里」那一下发一次
var _in_room := false


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
	invites = []
	session = {}
	_in_room = false


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


## 我在哪、朝哪、长什么样：森林里每 1/10 秒报一次，别人靠它画我。
func send_move(slot: int, spot: Vector3, yaw: float, body_id: String, skin_id: String) -> void:
	if state != State.READY:
		return
	# 走 MOVE 这条不排队的通道：位置比 op 新，堵在队列后面就没意义了
	_send(NetProtocol.Msg.MOVE, {
		"slot": slot, "x": spot.x, "y": spot.y, "z": spot.z, "yaw": yaw,
		"body": body_id, "skin": skin_id,
	})


func me() -> String:
	return player_name


## 天色：联机时天色由服务器采纳，`Save.write()` 在镜像模式下只推这一个字段。
func push_day_time(t: float) -> void:
	request("patch_day_time", {"t": t})


## 局内输入：和 send_move 一样走独立通道，不排 op 队列——输入比 op 新，堵在后面就是白加延迟。
func send_input(payload: Dictionary) -> void:
	if state != State.READY:
		return
	_send(NetProtocol.Msg.INPUT, payload)


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
	# 处理一条消息时游戏可能就 close() 了（信号是同步回调的），循环条件里得再看一眼
	while _peer != null and _peer.get_available_packet_count() > 0:
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
			NetProtocol.Msg.WORLD:
				world = body.get("players", {})
				# 自己身上那两份（本人 + 同屏 2P）由本地真实玩家画，别重复画
				world.erase(str(body.get("me", player_name)))
				world.erase("%s|1" % str(body.get("me", player_name)))
				clock = float(body.get("clock", clock))
				invites = body.get("invites", [])
				world_changed.emit()
			NetProtocol.Msg.SESSION:
				_on_session(body)
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


## 一局的快照：座位、时钟、结算。`save` 有就顺手刷镜像（成局时体力是服务器扣的）。
func _on_session(body: Dictionary) -> void:
	if body.has("save") and typeof(body["save"]) == TYPE_DICTIONARY:
		data = Save.normalize(body["save"])
		changed.emit()
	session = body
	if bool(body.get("over", false)):
		# 这局收了：快照留着给演出用，但下次被拉进局要能再触发 join_room
		_in_room = false
		return
	if not _in_room:
		_in_room = true
		join_room.emit()


func _on_result(body: Dictionary) -> void:
	_inflight = ""
	_waiting = 0.0
	last_result = body
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
