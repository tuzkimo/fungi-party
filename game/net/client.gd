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
## 这次登录用的那份凭证（口令派生的密钥，服务器上存的就是它）。自动登录只认它，口令本身不落盘。
var key_hex := ""

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
## 世界上第几天：服务器给，只当天色的一部分（体力恢复跟它没关系了）
var day := 1
## 服务器的 unix 秒：睡觉 / 吃饭的冷却按它算，本机钟说了不算
var now := 0.0
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
	_start(host, port, name)
	_password = password


## 自动登录：用上次存下的密钥，不再问口令。服务器不认就走 failed("auth")。
func connect_with_key(host: String, port: int, name: String, saved_key: String) -> void:
	_start(host, port, name)
	key_hex = saved_key


func _start(host: String, port: int, name: String) -> void:
	close()
	player_name = name
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
	now = 0.0
	_in_room = false
	key_hex = ""


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


## 场景里拿「那一个」Net 节点：启动菜单建的，名字固定叫 Net。
static func of(tree: SceneTree) -> NetClient:
	return tree.root.get_node_or_null("Net") as NetClient


## 服务器把我拉进这一款了吗：进场景时问一次就定下本局走服务器还是本机。
## over 之后快照还留着给演出用，所以不能拿「有没有 session」当条件。
func in_room(kind: String) -> bool:
	return ready() and str(session.get("kind", "")) == kind and not bool(session.get("over", false))


## 我在这一局的座位号（座位表由服务器给；不在表里就当 0 号）
func seat_index() -> int:
	var seats: Array = session.get("seats", [])
	for i in seats.size():
		if str((seats[i] as Dictionary).get("account", "")) == player_name:
			return i
	return 0


## 服务器现在几点（unix 秒）。还没收到 WORLD 就退回本机时间：只用来画倒计时，
## 真正的门槛在服务器上（`NetOps` 用的是服务器注入的那份 now）。
func server_now() -> float:
	return now if now > 0.0 else Time.get_unix_time_from_system()


## 局内输入：和 send_move 一样走独立通道，不排 op 队列——输入比 op 新，堵在后面就是白加延迟。
func send_input(payload: Dictionary) -> void:
	if state != State.READY:
		return
	_send(NetProtocol.Msg.INPUT, payload)


## 局内事件只该被消费一次：快照 20 Hz、场景 60 Hz，不抹掉的话同一批会被重放三遍（音效连发、飞行重启）。
## 会话字典是本机镜像，吃掉不算改存档。
func take_events() -> Array:
	var game: Dictionary = session.get("game", {})
	var out: Array = game.get("events", [])
	if not out.is_empty():
		game.erase("events")
	return out


func _process(delta: float) -> void:
	if _peer == null:
		return
	_peer.poll()
	_drain()
	if _peer == null:
		return
	if state != State.CONNECTING and _peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		# 被服务器踢了（同名账号在别处登录）或者服务器重启了：早点认，别装还在线
		_dead("closed")
		return
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
				day = int(body.get("day", day))
				now = float(body.get("now", now))
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
	key_hex = key_for(key_hex, _password, _salt)
	var key := NetAuth.unhex(key_hex)
	if _exists:
		_send(NetProtocol.Msg.PROOF, {"proof": NetAuth.hex(NetAuth.proof(key, NetAuth.unhex(_nonce)))})
	else:
		_send(NetProtocol.Msg.PROOF, {"key": key_hex})
	_password = ""


## 这次登录用哪把密钥：存过就直接用（自动登录），否则拿口令和服务器给的盐现算。
## 加密那一万来轮迭代只在这一处，别在调用方各写一遍。
static func key_for(saved_key: String, password: String, salt_hex: String) -> String:
	if saved_key != "":
		return saved_key
	return NetAuth.hex(NetAuth.derive(password, NetAuth.unhex(salt_hex)))


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
		print("这一局收了：%s 币 %s" % [str(session.get("kind", "")), str(session.get("earned", {}))])
		return
	if not _in_room:
		_in_room = true
		print("服务器把我拉进这一局：%s（座位 %d）" % [str(session.get("kind", "")), seat_index()])
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
	# 掉线原因要留一句日志：局中无端回森林，事后只能靠这一行对（adb logcat -s godot）
	print("和服务器断开：%s" % reason)
	state = State.DEAD
	_queue.clear()
	# 连接要真的关掉：留着的话服务器那边还挂着一个同名会话，下次登录会被它抢走自己那一局的快照
	if _peer != null:
		_peer.close()
		_peer = null
	failed.emit(reason)
