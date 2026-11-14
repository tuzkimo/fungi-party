extends SceneTree

## 桌面看一眼扔粑粑：A 登录并接受 B 的邀请 → 屎壳郎刷出来 → A 走到粪球上抢两发 →
## 站好机位各自扔几发 → 两张截图。
##   godot --path . --script res://tools/net_poop_shot.gd -- --port 7099 --name 粑粑截图
## 输出：shots/poop_field.png（屎壳郎推着粪球、对方替身）、shots/poop_hud.png（准星、命中数、弹药点）

var _port := 7099
var _name := "粑粑截图"
var _password := "password1"
var _other: NetClient


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var i := 0
	while i < args.size() - 1:
		match args[i]:
			"--port":
				_port = int(args[i + 1])
			"--name":
				_name = args[i + 1]
			"--password":
				_password = args[i + 1]
		i += 2
	change_scene_to_file("res://game/main.tscn")
	_run()


func _run() -> void:
	var net := await _login()
	if net == null:
		_quit("登录没成功", 1)
		return
	_other = NetClient.new()
	root.add_child(_other)
	_other.connect_to("127.0.0.1", _port, "%sB" % _name, _password)
	if not await _until(func() -> bool: return _other.ready(), 8.0):
		_quit("第二条连接没登录上", 1)
		return

	# B 发邀请，A 在横幅上按「接受」
	_other.request("invite", {"to": _name, "kind": "poop"})
	await create_timer(0.6).timeout
	var panel := current_scene.get_node("InvitePanel") as InvitePanel
	panel._on_answer_button(true, "")
	if not await _until(func() -> bool: return net.in_room("poop"), 8.0):
		_quit("没能进到扔粑粑这一局：%s" % str(net.session), 1)
		return
	print("进了扔粑粑（座位 %d），场景还是 %s" % [net.seat_index(), str(current_scene.scene_file_path)])

	# A 第一次报位置：服务器就在这儿撒屎壳郎
	var at := Vector3.ZERO
	net.send_move(0, at, 0.0, "red", "")
	if not await _until(func() -> bool: return _beetles(net).size() == Config.POOP_BEETLES, 5.0):
		_quit("屎壳郎没刷出来：%s" % str(net.session.get("game", {})), 1)
		return
	print("屎壳郎 %d 只，第一只推的球在 %s" % [_beetles(net).size(), str(PoopRound.ball_at(_beetles(net)[0]))])

	# 抢两发：一次一次现算最近的粪球再走过去（屎壳郎一直在走，几秒前算的那份已经不对了）
	for i in 6:
		if _my_ammo(net) >= 2:
			break
		var fresh := _nearest_balls(net, 1)
		if fresh.is_empty():
			_quit("没有球可抢了", 1)
			return
		at = await _walk(at, fresh[0] as Vector3)
		await create_timer(0.5).timeout
	print("抢到 %s 发" % str(net.session["game"]["ammo"]))
	var balls := _nearest_balls(net, 1)

	# 站好机位：A 在球后 5 米，B 在球前 3 米、偏开一点（别和 A 排成一条线藏在树干后面）
	var spot: Vector3 = (balls[0] as Vector3) + Vector3(0.0, 0.0, 5.0)
	at = await _walk(at, spot)
	var foe: Vector3 = (balls[0] as Vector3) + Vector3(1.6, 0.0, -3.0)
	_other.send_move(0, foe, PI, "seafood", "")
	# 粪球有可能正好落在某个 POI 的触发圈里（那次落到了猫头鹰树下，一整块面板糊住画面）：
	# 站远几米，POI 的 Area3D 一空就自己收起，然后再拍。
	for attempt in 3:
		await create_timer(0.8).timeout
		if not InvitePanel.poi_overlay_open(self):
			break
		spot += Vector3(0.0, 0.0, 8.0)
		foe += Vector3(0.0, 0.0, 8.0)
		_other.send_move(0, foe, PI, "seafood", "")
		at = await _walk(at, spot)
	var rig := (Player.of_seat(self, 0) as Player).get_node_or_null("CamRig") as CamRig
	if rig != null:
		# 相机压低一点，粪球才看得见
		rig._pitch = -0.30
	# 调试信息条别进截图
	var hud := current_scene.get_node_or_null("DebugHUD") as CanvasLayer
	if hud != null:
		hud.visible = false
	await create_timer(0.6).timeout

	root.get_texture().get_image().save_png("res://shots/poop_field.png")
	print("shots/poop_field.png：准星在 %s，屎壳郎 %d 只" % [
		str((current_scene.get_node("PoopPanel") as PoopPanel)._aim), _beetles(net).size()
	])

	# A 连扔两发，正对 B
	var at_dir := _flat(foe - at)
	for i in 2:
		net.send_input({"dirx": at_dir.x, "diry": 0.0, "dirz": at_dir.z})
		await create_timer(0.7).timeout
	# B 抢一发再扔回来：命中数只能靠真挨打刷出来
	var b_at := await _walk_other(foe, _nearest_balls(net, 1)[0] as Vector3)
	await create_timer(0.5).timeout
	b_at = await _walk_other(b_at, foe)
	await create_timer(0.4).timeout
	var b_dir := _flat(at - b_at)
	_other.send_input({"dirx": b_dir.x, "diry": 0.0, "dirz": b_dir.z})
	await create_timer(1.0).timeout

	var game: Dictionary = net.session.get("game", {})
	var seat := net.seat_index()
	var hits: Array = game.get("hits", [])
	print("命中数 %s（座位 %d 是我）" % [str(hits), seat])
	root.get_texture().get_image().save_png("res://shots/poop_hud.png")
	print("shots/poop_hud.png：顶上 %s" % PoopGame.top_text(
		int(hits[seat]), int(hits[1 - seat]), float(game.get("left", 0.0))
	))
	_quit("", 0)


## 里出生点最近的 n 只「还推着球」的屎壳郎（全是服务器的数据，别在本机另算一份）
func _nearest_beetles(net: NetClient, count: int) -> Array:
	var found: Array = []
	for b in _beetles(net):
		if bool((b as Dictionary).get("ball", false)):
			found.append(b)
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _ball_of(a).length() < _ball_of(b).length())
	return found.slice(0, count)


func _nearest_balls(net: NetClient, count: int) -> Array:
	var spots: Array = []
	for b in _nearest_beetles(net, count):
		spots.append(_ball_of(b as Dictionary))
	return spots


## 第 index 只屎壳郎推的粪球
func _ball_of(beetle: Dictionary) -> Vector3:
	var ball := PoopRound.ball_at(beetle)
	return Vector3(ball.x, 0.0, ball.y)


## 只留水平分量：扔的方向不看俯仰（见 PoopGame.aim_dir）
func _flat(v: Vector3) -> Vector3:
	var out := Vector3(v.x, 0.0, v.z)
	return out.normalized() if out.length() > 0.0 else Vector3.FORWARD


## A 这个人走过去：直接搬玩家节点，位置由 main.gd 每 0.1 秒报给服务器。
## 别在这里自己发 MOVE —— main.gd 也在报同一个 slot，两条路会来回抢。
## 一步 2 米（服务器一步最多认 2.4 米），0.15 秒一步，报得比走得多一点就追得上。
func _walk(from: Vector3, to: Vector3) -> Vector3:
	var player := Player.of_seat(self, 0)
	var at := from
	for i in 40:
		var step := to - at
		step.y = 0.0
		if step.length() <= 0.2:
			break
		at += step.normalized() * minf(2.0, step.length())
		if player != null:
			player.global_position = Vector3(at.x, 0.2, at.z)
		await create_timer(0.15).timeout
	return at


func _walk_other(from: Vector3, to: Vector3) -> Vector3:
	var at := from
	for i in 40:
		var step := to - at
		step.y = 0.0
		if step.length() <= 0.1:
			break
		at += step.normalized() * minf(2.0, step.length())
		_other.send_move(0, at, PI, "seafood", "")
		await create_timer(0.06).timeout
	return at


func _my_ammo(net: NetClient) -> int:
	var ammo: Array = (net.session.get("game", {}) as Dictionary).get("ammo", [])
	var seat := net.seat_index()
	return int(ammo[seat]) if seat < ammo.size() else 0


func _beetles(net: NetClient) -> Array:
	return (net.session.get("game", {}) as Dictionary).get("beetles", [])


func _login() -> NetClient:
	await create_timer(0.4).timeout
	var menu := current_scene.get_node("StartMenu") as StartMenu
	menu.show_login()
	menu.submit("127.0.0.1:%d" % _port, _name, _password)
	var ok := await _until(func() -> bool:
		var net := root.get_node_or_null("Net") as NetClient
		return net != null and net.ready(), 15.0)
	if not ok:
		return null
	return root.get_node_or_null("Net") as NetClient


func _until(cond: Callable, seconds: float) -> bool:
	var left := seconds
	while left > 0.0:
		if bool(cond.call()):
			return true
		await create_timer(0.1).timeout
		left -= 0.1
	return false


func _quit(reason: String, code: int) -> void:
	if reason != "":
		printerr(reason)
	quit(code)
