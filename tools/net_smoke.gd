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
	print("SMOKE OK")
	quit(0)


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
