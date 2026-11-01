extends SceneTree

## 联机冒烟：连真服务器 → 注册 → 加币 → 抽一抽 → 断开重连验证存档在服务器上。
## 不做断言库那一套，输出以 SMOKE OK 结尾就算过（scripts/net_smoke.sh 会检查）。
##
##   godot --headless --path . --script res://tools/net_smoke.gd -- --host 127.0.0.1 --port 7099 --name 冒烟

const WATCHDOG_SECONDS := 30.0

var _client: NetClient
var _host := "127.0.0.1"
var _port := 7099
var _name := "冒烟"
var _password := "password1"
## join_room 信号收到过的人（信号回调改不了局部变量，记在这里）
var _joined := {}


func _initialize() -> void:
	_parse_args(OS.get_cmdline_user_args())
	_client = NetClient.new()
	_client.failed.connect(_on_failed)
	root.add_child(_client)
	_watchdog()
	_run()


func _run() -> void:
	print("连 %s:%d 账号 %s" % [_host, _port, _name])
	_client.connect_to(_host, _port, _name, _password)
	await _client.logged_in
	print("登录成功 币 %d 体力 %d" % [int(_client.data["coins"]), int(_client.data["stamina"])])

	await _op("add_coins", {"amount": 200})
	if int(_client.data["coins"]) != 200:
		_die("加币后币不对：%d" % int(_client.data["coins"]))
	print("加币 200 之后 币 %d" % int(_client.data["coins"]))

	await _op("pull", {"n": 1})
	if int(_client.data["coins"]) == 200:
		_die("抽卡没扣钱")
	print("抽一抽之后 币 %d，皮肤 %s" % [
		int(_client.data["coins"]), str(_client.data["owned"])
	])

	await _op("equip", {"skin": str(_client.data["equipped"])})
	await _op("sleep", {})
	if int(_client.data["stamina"]) != Config.STAMINA_MAX:
		_die("睡觉没回体力")
	print("睡觉之后 体力 %d 第 %d 天" % [int(_client.data["stamina"]), int(_client.data["day"])])

	var coins_before := int(_client.data["coins"])
	var owned_before := (_client.data["owned"] as PackedStringArray).size()
	_client.close()
	_client.connect_to(_host, _port, _name, _password)
	await _client.logged_in
	if int(_client.data["coins"]) != coins_before:
		_die("重连后币变了：%d -> %d" % [coins_before, int(_client.data["coins"])])
	if (_client.data["owned"] as PackedStringArray).size() != owned_before:
		_die("重连后皮肤数量变了")
	print("重连后 币 %d 皮肤 %d 顶：存档在服务器上" % [coins_before, owned_before])

	await _same_account_two_devices()
	await _world_check()
	await _invite_check()
	print("SMOKE OK")
	quit(0)


## 共享森林：两个人互相看得见，同屏的 2P 也是世界里的一份子。
func _world_check() -> void:
	var other := NetClient.new()
	other.failed.connect(_on_failed)
	root.add_child(other)
	other.connect_to(_host, _port, "%sB" % _name, _password)
	await other.logged_in
	_client.send_move(0, Vector3(1.0, 0.0, 2.0), 0.5, "red", "")
	_client.send_move(1, Vector3(2.0, 0.0, 3.0), 0.5, "seafood", "")
	other.send_move(0, Vector3(-5.0, 0.0, 6.0), 1.0, "seafood", "")
	# 世界每 1/10 秒广播一次，等它轮到下一次
	await create_timer(0.5).timeout
	if not other.world.has(_name):
		_die("B 看不见 A（世界：%s）" % str(other.world.keys()))
	if not other.world.has("%s|1" % _name):
		_die("B 看不见 A 的同屏 2P")
	if other.world[_name].get("z") != 2.0:
		_die("B 拿到的 A 的位置不对：%s" % str(other.world[_name]))
	if (other.world["%s|1" % _name] as Dictionary).get("name") != "%s 2P" % _name:
		_die("2P 的名字不对：%s" % str(other.world["%s|1" % _name]))
	if not _client.world.has("%sB" % _name):
		_die("A 看不见 B")
	print("共享森林：A 看见 %d 份（含 2P），B 看见 A 和 A 的 2P" % _client.world.size())
	other.close()


## 邀请：两个人进同一局，各扣自己的体力；有人掉线这一局就收了。
func _invite_check() -> void:
	var guest := NetClient.new()
	guest.failed.connect(_on_failed)
	root.add_child(guest)
	var guest_name := "%sC" % _name
	guest.connect_to(_host, _port, guest_name, _password)
	await guest.logged_in
	# 信号只在「从不在局里变成在局里」那一下发，两个人都得收到
	_client.join_room.connect(func() -> void: _joined[_name] = true)
	guest.join_room.connect(func() -> void: _joined[guest_name] = true)

	await _op("invite", {"to": guest_name, "kind": "classroom"})
	if not bool(_client.last_result.get("ok", false)):
		_die("邀请被拒：%s" % str(_client.last_result.get("error", "")))
	await create_timer(0.5).timeout
	if guest.invites.size() != 1:
		_die("对方没收到邀请：%s" % str(guest.invites))
	if str(guest.invites[0].get("from", "")) != _name or str(guest.invites[0].get("kind", "")) != "classroom":
		_die("邀请内容不对：%s" % str(guest.invites[0]))

	guest.request("answer", {"from": _name, "kind": "classroom", "accept": true})
	await guest.changed
	await create_timer(0.3).timeout
	for who in [guest, _client]:
		if str(who.session.get("kind", "")) != "classroom":
			_die("%s 没进到这一局：%s" % [who.me(), str(who.session)])
	if not _joined.has(_name) or not _joined.has(guest_name):
		_die("join_room 信号没发：%s" % str(_joined))
	var seats: Array = _client.session.get("seats", [])
	if seats.size() != Config.SEAT_COUNT:
		_die("座位数不对：%d" % seats.size())
	if str(seats[0].get("account", "")) != _name or str(seats[1].get("account", "")) != guest_name:
		_die("座位顺序不对（发起的坐 0 号）：%s" % str(seats))
	var cost := Config.STAMINA_COST_CLASSROOM
	if int(_client.data["stamina"]) != Config.STAMINA_MAX - cost:
		_die("邀请方体力没扣：%d" % int(_client.data["stamina"]))
	if int(guest.data["stamina"]) != Config.STAMINA_MAX - cost:
		_die("被邀请方体力没扣：%d" % int(guest.data["stamina"]))

	guest.close()
	await create_timer(0.5).timeout
	if not bool(_client.session.get("over", false)):
		_die("对方掉线后这一局没收：%s" % str(_client.session))
	print("邀请：两人进同一间教室，各扣 %d 体力，掉线收局" % cost)


## 两台设备同一个账号：后一台的镜像是旧的，钱必须还是服务器的账本说了算。
func _same_account_two_devices() -> void:
	var before := int(_client.data["coins"])
	var refunded := 0
	_client.request("pull", {"n": 1})
	await _client.changed
	refunded += int((_client.last_result.get("result", {}) as Dictionary).get("pulls", [{}])[0].get("refund", 0))
	# 同一个账号再开一条连接：它连上时拿到的已经是扣过钱的那份
	var second := NetClient.new()
	second.failed.connect(_on_failed)
	root.add_child(second)
	second.connect_to(_host, _port, _name, _password)
	await second.logged_in
	if int(second.data["coins"]) != before - Config.GACHA_PRICE_ONE + refunded:
		_die("第二条连接拿到的不是服务器上的账：%d" % int(second.data["coins"]))
	second.request("pull", {"n": 1})
	await second.changed
	refunded += int((second.last_result.get("result", {}) as Dictionary).get("pulls", [{}])[0].get("refund", 0))
	if int(second.data["coins"]) != before - Config.GACHA_PRICE_ONE * 2 + refunded:
		_die("两台设备连抽之后账不对：%d" % int(second.data["coins"]))
	if int(_client.data["coins"]) == int(second.data["coins"]):
		pass
	print("两台设备同账号：服务器账本一致，抽两抽后币 %d" % int(second.data["coins"]))
	second.close()


## 发一条 op 并等服务器回来（失败/超时都会被 failed 或看门狗兜住）。
func _op(op: String, args: Dictionary) -> void:
	_client.request(op, args)
	await _client.changed


func _on_failed(reason: String) -> void:
	_die("失败：%s" % reason)


func _die(reason: String) -> void:
	printerr("SMOKE FAIL: %s" % reason)
	quit(1)


func _watchdog() -> void:
	await create_timer(WATCHDOG_SECONDS).timeout
	printerr("SMOKE FAIL: 超时 %d 秒" % int(WATCHDOG_SECONDS))
	quit(2)


func _parse_args(args: PackedStringArray) -> void:
	var i := 0
	while i < args.size() - 1:
		match args[i]:
			"--host":
				_host = args[i + 1]
			"--port":
				_port = int(args[i + 1])
			"--name":
				_name = args[i + 1]
			"--password":
				_password = args[i + 1]
		i += 2
