extends SceneTree

## 真机那个「同意邀请就掉局」的复现台：一台机器跑两个真客户端（两个进程各一份）。
##   godot --path . --script res://tools/net_owl_repro.gd -- --role host --port 7099 --gap 1
##   godot --path . --script res://tools/net_owl_repro.gd -- --role guest --port 7099 --gap 2
## 两个进程都进真场景（main.tscn → 猫头鹰），每秒打一行状态，看谁先掉。

var _role := "host"
var _port := 7099
var _gap := 0
var _name := ""
var _password := "password1"
var _kind := "owl"
var _frames := 0
var _stage := 0
var _tick := 0.0
var _seconds := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var i := 0
	while i < args.size() - 1:
		match args[i]:
			"--role":
				_role = args[i + 1]
			"--port":
				_port = int(args[i + 1])
			"--gap":
				_gap = int(args[i + 1])
			"--kind":
				_kind = args[i + 1]
		i += 2
	_name = "复现%s%d" % [_role, _gap]
	change_scene_to_file("res://game/main.tscn")


func _process(delta: float) -> bool:
	_frames += 1
	_tick += delta
	var net := root.get_node_or_null("Net") as NetClient
	match _stage:
		0:
			if _frames > 20:
				var menu := current_scene.get_node("StartMenu") as StartMenu
				menu.show_login()
				menu.submit("127.0.0.1:%d" % _port, _name, _password)
				_stage = 1
		1:
			if net != null and net.ready():
				print("%s 登录好了" % _role)
				_stage = 2
				_tick = 0.0
		2:
			if _role == "host":
				if _tick > 3.0:
					var target := _other_name()
					if target == "":
						print("host：世界里没人，再等")
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
				elif _tick > 30.0:
					print("guest 一直没收到邀请")
					return true
		3:
			if _tick >= 1.0:
				_tick = 0.0
				_seconds += 1
				print("%s [%ds] 场景=%s ready=%s 局=%s 币=%d 体力=%d" % [
					_role, _seconds, String(current_scene.scene_file_path).get_file(),
					str(net != null and net.ready()),
					str(net.session.get("kind", "-")) if net != null else "-",
					int(net.data.get("coins", 0)) if net != null else -1,
					int(net.data.get("stamina", 0)) if net != null else -1,
				])
				if _seconds >= 12:
					print("%s 收工" % _role)
					return true
	return false


func _other_name() -> String:
	var net := root.get_node_or_null("Net") as NetClient
	if net == null:
		return ""
	for key in net.world:
		return str(key)
	return ""
