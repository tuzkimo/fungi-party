extends SceneTree

## 压一把看清楚「这台服务器能装几个人」：
## 连 K 个假客户端、各自报位置、跑 T 秒，然后打印服务器侧的 CPU 和内存（由外层脚本采）。
##
##   godot --headless --path . --script res://tools/net_load.gd -- --port 7200 --clients 10 --seconds 10

var _host := "127.0.0.1"
var _port := 7200
var _clients := 10
var _seconds := 10.0
var _peer_objs: Array[NetClient] = []
var _elapsed := 0.0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var i := 0
	while i < args.size() - 1:
		match args[i]:
			"--host":
				_host = args[i + 1]
			"--port":
				_port = int(args[i + 1])
			"--clients":
				_clients = int(args[i + 1])
			"--seconds":
				_seconds = float(args[i + 1])
		i += 2
	for k in _clients:
		var client := NetClient.new()
		client.name = "Load%d" % k
		root.add_child(client)
		client.connect_to(_host, _port, "负载%d" % k, "password1")
		_peer_objs.append(client)
	print("拉 %d 个客户端连 %s:%d，跑 %.0f 秒" % [_clients, _host, _port, _seconds])


func _process(delta: float) -> bool:
	_elapsed += delta
	var ready := 0
	for k in _peer_objs.size():
		var client := _peer_objs[k]
		if client.ready():
			ready += 1
			# 每个假人在原地绕圈：位置一直变，和真玩家一样吃广播带宽
			var angle := _elapsed * 0.8 + float(k)
			client.send_move(0, Vector3(cos(angle) * 6.0, 0.0, sin(angle) * 6.0), angle, "red", "")
	if _elapsed >= _seconds:
		var seen := 0
		for client in _peer_objs:
			seen += client.world.size()
		print("登录成功 %d/%d，世界条目合计 %d，每人看见约 %.1f 个" % [
			ready, _clients, seen, float(seen) / maxf(1.0, float(maxi(1, ready)))
		])
		quit(0)
		return true
	return false
