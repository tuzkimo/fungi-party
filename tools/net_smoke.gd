extends SceneTree

## 联机冒烟：连真服务器 → 注册 → 加币 → 抽一抽 → 断开重连验证存档在服务器上。
## 不做断言库那一套，输出以 SMOKE OK 结尾就算过（scripts/net_smoke.sh 会检查）。
##
##   godot --headless --path . --script res://tools/net_smoke.gd -- --host 127.0.0.1 --port 7099 --name 冒烟

const WATCHDOG_SECONDS := 60.0

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

	# 世界时钟一天只能睡一次：第二次得被拒，但照样得回 OP_RESULT（不回就 timeout 掉线）
	var day_before := int(_client.data["day"])
	await _op("sleep", {})
	if bool(_client.last_result.get("ok", true)):
		_die("同一天睡了第二次")
	if str(_client.last_result.get("error", "")) != "slept":
		_die("第二次睡觉的拒绝原因不对：%s" % str(_client.last_result.get("error", "")))
	if int(_client.data["day"]) != day_before:
		_die("被拒的睡觉改了天数：%d -> %d" % [day_before, int(_client.data["day"])])
	print("同一天再睡被拒（error: slept），天数还是 %d" % day_before)

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
	await _bomb_check()
	await _owl_check()
	await _race_check()
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


## 邀请：两个人进同一局，各扣自己的体力；一个人掉线这一局还得留着给另一个人打完。
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

	# 教室这一局的规则在服务器上跑：快照要带局内状态，按下去得算数
	await create_timer(0.3).timeout
	var game: Dictionary = _client.session.get("game", {})
	if game.is_empty() or (game.get("seats", []) as Array).size() != Config.SEAT_COUNT:
		_die("没收到教室快照：%s" % str(_client.session))
	if game.get("gaze", {}).is_empty():
		_die("教室快照里没有视线")
	await create_timer(ClassroomRound.COUNTDOWN + 0.3).timeout
	_client.send_input({"press": true})
	guest.send_input({"press": true})
	await create_timer(2.5).timeout
	var states: Array = (_client.session.get("game", {}) as Dictionary).get("seats", [])
	var moved := 0
	for i in 2:
		moved += int((states[i] as Dictionary)["bites"]) + int((states[i] as Dictionary)["caught"])
	if moved == 0:
		_die("两个人按了 2.5 秒，服务器没算出一口也没抓到人：%s" % str(states))

	var coins_before := int(_client.data["coins"])
	guest.close()
	await create_timer(0.5).timeout
	if bool(_client.session.get("over", false)):
		_die("一个人掉线就把两个人的局收了：%s" % str(_client.session))
	await _settle_and_reconnect()
	if int(_client.data["coins"]) <= coins_before:
		_die("收局没结账：%d -> %d" % [coins_before, int(_client.data["coins"])])
	print("邀请：两人进同一间教室各扣 %d 体力，服务器判吃口，收局结账 %d 币" % [
		cost, int(_client.data["coins"]) - coins_before
	])


## 传炸弹：邀请 → 两边各扣 25 → 服务器判炸弹 → 主动离开收局，各拿各的币。
## 不等着自然打完：一整局要几十秒，看门狗不够。
func _bomb_check() -> void:
	var guest := NetClient.new()
	guest.failed.connect(_on_failed)
	root.add_child(guest)
	var guest_name := "%sD" % _name
	guest.connect_to(_host, _port, guest_name, _password)
	await guest.logged_in
	var coins_before := int(_client.data["coins"])
	await _op("invite", {"to": guest_name, "kind": "bomb"})
	if not bool(_client.last_result.get("ok", false)):
		_die("传炸弹邀请被拒：%s" % str(_client.last_result.get("error", "")))
	await create_timer(0.3).timeout
	guest.request("answer", {"from": _name, "kind": "bomb", "accept": true})
	await guest.changed
	await create_timer(0.4).timeout
	for who in [guest, _client]:
		if str(who.session.get("kind", "")) != "bomb":
			_die("%s 没进到传炸弹：%s" % [who.me(), str(who.session)])
	if int(guest.data["stamina"]) != Config.STAMINA_MAX - Config.STAMINA_COST_BOMB:
		_die("被邀请方体力没扣：%d" % int(guest.data["stamina"]))

	# 规则在服务器上：快照带局内状态，两个人看到的是同一局
	var game: Dictionary = _client.session.get("game", {})
	if game.is_empty() or not game.has("holder") or (game.get("alive", []) as Array).size() != 4:
		_die("没收到传炸弹快照：%s" % str(_client.session))

	# 人坐的位子不会自己出手（只有人机才会自动扔）：看到真人扔的，就说明本机 INPUT 到了服务器。
	# 飞行只有 0.2 秒、快照 20 Hz，所以两边都看：thrower 字段 + 这一帧里的事件。
	var threw := false
	for i in 150:
		_client.send_input({"throw": -1})
		guest.send_input({"throw": 1})
		await create_timer(0.1).timeout
		var state: Dictionary = _client.session.get("game", {})
		if int(state.get("thrower", -1)) in [0, 1] or _human_throw(state.get("events", [])):
			threw = true
			break
	if not threw:
		_die("两个人扔了 15 秒，服务器一次都没算（INPUT 没接上）")

	# 结算门槛是 5 秒：等够再走，否则这局不结账
	await create_timer(Config.NET_SETTLE_MIN_SECONDS).timeout
	guest.close()
	await create_timer(0.6).timeout
	if bool(_client.session.get("over", false)):
		_die("一个人掉线就把两个人的局收了：%s" % str(_client.session))
	await _settle_and_reconnect()
	if int(_client.data["coins"]) <= coins_before:
		_die("传炸弹收局没结账：%d -> %d" % [coins_before, int(_client.data["coins"])])
	print("传炸弹：两人同局各扣 %d 体力，服务器判投掷，收局结账 %d 币" % [
		Config.STAMINA_COST_BOMB, int(_client.data["coins"]) - coins_before
	])


## 猫头鹰：邀请 → 两边各扣 30 → 服务器推三关 → 按住有分（或者吃到屎出局，两条都证明 INPUT 到了服务器）
## → 主动离开收局结账。一整局 150 秒太长，不等着自然打完。
func _owl_check() -> void:
	var guest := NetClient.new()
	guest.failed.connect(_on_failed)
	root.add_child(guest)
	var guest_name := "%sE" % _name
	guest.connect_to(_host, _port, guest_name, _password)
	await guest.logged_in
	var coins_before := int(_client.data["coins"])
	await _op("invite", {"to": guest_name, "kind": "owl"})
	if not bool(_client.last_result.get("ok", false)):
		_die("猫头鹰邀请被拒：%s" % str(_client.last_result.get("error", "")))
	await create_timer(0.3).timeout
	guest.request("answer", {"from": _name, "kind": "owl", "accept": true})
	await guest.changed
	await create_timer(0.4).timeout
	for who in [guest, _client]:
		if str(who.session.get("kind", "")) != "owl":
			_die("%s 没进到猫头鹰：%s" % [who.me(), str(who.session)])
	if int(guest.data["stamina"]) != Config.STAMINA_MAX - Config.STAMINA_COST_OWL:
		_die("被邀请方体力没扣：%d" % int(guest.data["stamina"]))

	var game: Dictionary = _client.session.get("game", {})
	if game.is_empty() or (game.get("seats", []) as Array).size() != OwlRound.SEATS or not game.has("level"):
		_die("没收到猫头鹰快照：%s" % str(_client.session))

	# 人机自己会张嘴，所以要看真人那一格：涨分或吃到屎出局都证明本机 INPUT 到了服务器
	var judged := false
	for i in 120:
		_client.send_input({"press": true})
		await create_timer(0.1).timeout
		var states: Array = (_client.session.get("game", {}) as Dictionary).get("seats", [])
		if not states.is_empty():
			var mine: Dictionary = states[0]
			if int(mine.get("score", 0)) > 0 or bool(mine.get("out", false)):
				judged = true
				break
	if not judged:
		_die("按了 12 秒，服务器一次都没判（INPUT 没接上）")

	# 结算门槛是 5 秒：等够再走，否则这局不结账
	await create_timer(Config.NET_SETTLE_MIN_SECONDS).timeout
	guest.close()
	await create_timer(0.6).timeout
	if bool(_client.session.get("over", false)):
		_die("一个人掉线就把两个人的局收了：%s" % str(_client.session))
	await _settle_and_reconnect()
	if int(_client.data["coins"]) <= coins_before:
		_die("猫头鹰收局没结账：%d -> %d" % [coins_before, int(_client.data["coins"])])
	print("猫头鹰：两人同局各扣 %d 体力，服务器判吃口，收局结账 %d 币" % [
		Config.STAMINA_COST_OWL, int(_client.data["coins"]) - coins_before
	])


## 赛跑：邀请 → 两边各扣 20 → 服务器推赛道、判摇杆 → 对方掉线收局。
## 一局 220 米要几十秒，看门狗不够，所以不等着跑完。
func _race_check() -> void:
	var guest := NetClient.new()
	guest.failed.connect(_on_failed)
	root.add_child(guest)
	var guest_name := "%sF" % _name
	guest.connect_to(_host, _port, guest_name, _password)
	await guest.logged_in
	var coins_before := int(_client.data["coins"])
	await _op("invite", {"to": guest_name, "kind": "race"})
	if not bool(_client.last_result.get("ok", false)):
		_die("赛跑邀请被拒：%s" % str(_client.last_result.get("error", "")))
	await create_timer(0.3).timeout
	guest.request("answer", {"from": _name, "kind": "race", "accept": true})
	await guest.changed
	await create_timer(0.4).timeout
	for who in [guest, _client]:
		if str(who.session.get("kind", "")) != "race":
			_die("%s 没进到赛跑：%s" % [who.me(), str(who.session)])
	if int(guest.data["stamina"]) != Config.STAMINA_MAX - Config.STAMINA_COST_RACE:
		_die("被邀请方体力没扣：%d" % int(guest.data["stamina"]))

	var game: Dictionary = _client.session.get("game", {})
	if game.is_empty() or (game.get("racers", []) as Array).size() != Config.SEAT_COUNT:
		_die("没收到赛跑快照：%s" % str(_client.session))

	# 倒数在模型里：等它走完再推摇杆，服务器把 0 号座位推走了就说明 INPUT 到了。
	await create_timer(RaceRound.COUNTDOWN + 0.5).timeout
	var judged := false
	for i in 80:
		_client.send_input({"move": -1.0})
		await create_timer(0.1).timeout
		var states: Array = (_client.session.get("game", {}) as Dictionary).get("racers", [])
		if not states.is_empty() and float((states[0] as Dictionary).get("x", -9.0)) > 0.0:
			judged = true
			break
	if not judged:
		_die("推了 8 秒摇杆，服务器一次都没算（INPUT 没接上）")

	# 结算门槛是 5 秒：等够再走，否则这局不结账
	await create_timer(Config.NET_SETTLE_MIN_SECONDS).timeout
	guest.close()
	await create_timer(0.6).timeout
	if bool(_client.session.get("over", false)):
		_die("一个人掉线就把两个人的局收了：%s" % str(_client.session))
	await _settle_and_reconnect()
	print("赛跑：两人同局各扣 %d 体力，服务器判摇杆，收局结账 %d 币" % [
		Config.STAMINA_COST_RACE, int(_client.data["coins"]) - coins_before
	])


## 收局结账：最后一个人也走人 → 服务器收局写币 → 重连拿回新存档。
## 一个人掉线不再收局（见 NetLobby.drop），所以想验结账就得把两个人都走掉。
func _settle_and_reconnect() -> void:
	var old := _client
	old.close()
	await create_timer(0.8).timeout
	_client = NetClient.new()
	_client.failed.connect(_on_failed)
	root.add_child(_client)
	_client.connect_to(_host, _port, _name, _password)
	await _client.logged_in
	old.queue_free()


## 事件里有没有「真人扔的」：人机的 from 是 2/3，真人是 0/1。
func _human_throw(events: Array) -> bool:
	for event in events:
		if str((event as Dictionary).get("kind", "")) == "throw" and int((event as Dictionary).get("from", -1)) in [0, 1]:
			return true
	return false


## 同一账号再登录（换设备 / 重开客户端）：新连接接管账号，旧连接被踢，镜像还是服务器那份账本。
func _same_account_two_devices() -> void:
	var before := int(_client.data["coins"])
	var refunded := 0
	_client.request("pull", {"n": 1})
	await _client.changed
	refunded += int((_client.last_result.get("result", {}) as Dictionary).get("pulls", [{}])[0].get("refund", 0))
	# 旧连接被踢是预期行为，不是失败
	_client.failed.disconnect(_on_failed)
	var second := NetClient.new()
	second.failed.connect(_on_failed)
	root.add_child(second)
	second.connect_to(_host, _port, _name, _password)
	await second.logged_in
	if int(second.data["coins"]) != before - Config.GACHA_PRICE_ONE + refunded:
		_die("第二条连接拿到的不是服务器上的账：%d" % int(second.data["coins"]))
	for i in 20:
		if not _client.ready():
			break
		await create_timer(0.05).timeout
	if _client.ready():
		_die("同一账号第二次登录没把旧连接踢掉")
	print("两台设备同账号：新连接接管账号、旧连接被踢，账是服务器的 %d" % int(second.data["coins"]))
	_client.queue_free()
	_client = second


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
