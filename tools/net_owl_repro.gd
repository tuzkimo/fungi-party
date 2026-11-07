extends SceneTree

## 两台真客户端互相邀请的复现台（一边跑这个脚本，另一边是真手机/另一个进程）。
##   godot --path . --script res://tools/net_owl_repro.gd -- --role host --host 8.134.142.195 --port 7000 --kind owl --seconds 60
##   godot --path . --script res://tools/net_owl_repro.gd -- --role guest --port 7000 --gap 2
## 两个进程都进真场景（main.tscn → 小游戏），每秒打一行状态，看谁先掉。
## host：世界里一有人就邀请他；guest：有人邀请就接受。两端都不点按钮，全自动。

var _role := "host"
var _host := "127.0.0.1"
var _port := 7000
var _password := "password1"
var _gap := 0
var _name := ""
var _kind := "owl"
var _seconds := 12
var _frames := 0
var _stage := 0
var _tick := 0.0
var _elapsed := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var i := 0
	while i < args.size() - 1:
		match args[i]:
			"--role":
				_role = args[i + 1]
			"--host":
				_host = args[i + 1]
			"--port":
				_port = int(args[i + 1])
			"--password":
				_password = args[i + 1]
			"--gap":
				_gap = int(args[i + 1])
			"--kind":
				_kind = args[i + 1]
			"--seconds":
				_seconds = int(args[i + 1])
		i += 2
	_name = "复现%s%d" % [_role, _gap]
	change_scene_to_file("res://game/main.tscn")


func _process(delta: float) -> bool:
	_frames += 1
	_tick += delta
	var net := root.get_node_or_null("Net") as NetClient
	match _stage:
		0:
			if _frames > 20 and current_scene != null:
				var menu := current_scene.get_node("StartMenu") as StartMenu
				menu.show_login()
				menu.submit("%s:%d" % [_host, _port], _name, _password)
				_stage = 1
		1:
			if net != null and net.ready():
				print("%s 登录好了（%s:%d）" % [_role, _host, _port])
				_stage = 2
				_tick = 0.0
			else:
				if _tick > 20.0:
					print("%s 登录失败：%s" % [_role, str(net.state) if net != null else "没有 Net 节点"])
					return true
		2:
			if _role == "host":
				if _tick > 2.0:
					var target := _other_name()
					if target == "":
						print("host：世界里没人（等手机登录）")
						_tick = 0.0
						return false
					print("host 邀请 %s 玩 %s" % [target, _kind])
					current_scene.get_node("InvitePanel")._on_invite_button(target, _kind)
					_stage = 3
			else:
				if not net.invites.is_empty():
					print("guest 收到邀请 %s，接受" % str(net.invites[0]))
					current_scene.get_node("InvitePanel")._on_answer_button(true)
					_stage = 3
				elif _tick > 60.0:
					print("guest 一直没收到邀请")
					return true
		3:
			# 邀请被拒 / 过期了就再来一次：手机那边补个体力再点接受也能接上
			if net.session.is_empty() and _tick >= 5.0:
				print("host：这一局还没开成（%s），重发邀请" % str(net.last_result.get("error", "")))
				_stage = 2
				_tick = 0.0
				return false
			if _tick >= 1.0:
				_tick = 0.0
				_elapsed += 1
				var result := "" if net.last_result.is_empty() else " 回执=%s/%s" % [
					str(net.last_result.get("op", "")), str(net.last_result.get("error", ""))
				]
				print("%s [%ds] 场景=%s ready=%s 局=%s over=%s 币=%d 体力=%d%s" % [
					_role, _elapsed, String(current_scene.scene_file_path).get_file(),
					str(net != null and net.ready()),
					str(net.session.get("kind", "-")) if net != null else "-",
					str(net.session.get("over", "-")) if net != null else "-",
					int(net.data.get("coins", 0)) if net != null else -1,
					int(net.data.get("stamina", 0)) if net != null else -1,
					result,
				])
				if _elapsed >= _seconds:
					print("%s 收工" % _role)
					return true
	return false


## 世界里除自己以外的人（手机登录后就出现在这儿）
func _other_name() -> String:
	var net := root.get_node_or_null("Net") as NetClient
	if net == null:
		return ""
	var names: Array[String] = []
	for key in net.world:
		var name := str(key)
		if not name.contains("|"):
			names.append(name)
	names.sort()
	return names[0] if not names.is_empty() else ""
