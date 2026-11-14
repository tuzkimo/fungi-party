extends SceneTree

## 复现「从小游戏回森林，别人一直看见他定在门口」：换场景 = 坐标从门口跳到出生点（原点）。
## 服务器 `_on_move` 有一步距离上限，跳过去的 MOVE 会被拒；被拒的那一份不进服务端，
## 下一条又拿同一份旧坐标比 —— 于是这个人永远卡在旧点上。
##
##   godot --headless --path . --script res://tools/net_move_repro.gd -- --port 7099 --name 卡位
##
## 输出最后一行 `STUCK 门口` = 复现了；`OK 新坐标` = 已经好了。

const WATCHDOG_SECONDS := 60.0
## 校门口（(0,0,-14)）→ 森林出生点（原点）：换场景回来就是这么一跳
const DOOR := Vector3(0.0, 0.0, -14.0)
const SPAWN := Vector3(0.0, 0.0, 0.0)

var _observer: NetClient
var _subject: NetClient
var _host := "127.0.0.1"
var _port := 7099
var _name := "卡位"
var _password := "password1"


func _initialize() -> void:
	_parse_args(OS.get_cmdline_user_args())
	_observer = NetClient.new()
	_subject = NetClient.new()
	root.add_child(_observer)
	root.add_child(_subject)
	_watchdog()
	_run()


func _run() -> void:
	_observer.connect_to(_host, _port, "%sA" % _name, _password)
	_subject.connect_to(_host, _port, "%sB" % _name, _password)
	await _observer.logged_in
	await _subject.logged_in

	# 站在门口报一次：这一份服务器是收的
	_subject.send_move(0, DOOR, 0.0, "red", "")
	await create_timer(0.4).timeout
	# 换场景回来：人在原点。这一条离上一份 14 米，超出一步的上限 —— 服务器按 24 m/s 往过追
	_subject.send_move(0, SPAWN, 0.0, "red", "")
	# 回来之后照常站着（10 Hz 报位置），等服务器追上
	for i in 12:
		await create_timer(0.1).timeout
		_subject.send_move(0, SPAWN, 0.0, "red", "")

	var seen: Dictionary = _observer.world.get(_subject.me(), {})
	if seen.is_empty():
		print("SMOKE FAIL 观察者世界里根本没这个人")
		quit(1)
		return
	var at := Vector3(float(seen["x"]), float(seen["y"]), float(seen["z"]))
	print("观察者看到 %s 在 %s" % [_subject.me(), str(at)])
	if at.distance_to(SPAWN) > 1.0:
		print("STUCK 门口：服务器没跟上换场景之后的坐标")
		quit(1)
		return

	# 追上来之后就是正常的 10 Hz 跟随：走 4 米，观察者也该跟到
	for i in 7:
		await create_timer(0.1).timeout
		_subject.send_move(0, SPAWN + Vector3(0.0, 0.0, 0.6 * float(i + 1)), 0.0, "red", "")
	await create_timer(0.2).timeout
	seen = _observer.world.get(_subject.me(), {})
	at = Vector3(float(seen["x"]), float(seen["y"]), float(seen["z"]))
	if at.distance_to(SPAWN + Vector3(0.0, 0.0, 4.2)) > 1.0:
		print("STUCK 跟上之后又不走了：观察者看到 %s" % str(at))
		quit(1)
		return
	print("OK 换场景之后位置跟上了（%s）" % str(at))
	quit(0)


func _on_failed(reason: String) -> void:
	print("SMOKE FAIL 掉线 %s" % reason)
	quit(1)


func _watchdog() -> void:
	await create_timer(WATCHDOG_SECONDS).timeout
	print("SMOKE FAIL 超时")
	quit(1)


func _parse_args(args: PackedStringArray) -> void:
	var i := 0
	while i < args.size():
		var key := args[i]
		if key.begins_with("--") and i + 1 < args.size():
			match key.substr(2):
				"host":
					_host = args[i + 1]
				"port":
					_port = int(args[i + 1])
				"name":
					_name = args[i + 1]
			i += 2
		else:
			i += 1
