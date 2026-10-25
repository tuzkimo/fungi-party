extends SceneTree

## 桌面看一眼共享森林：A 登录后，脚本用第二条连接扮演 B 在旁边走，看 A 的画面里有没有替身和名字牌。
##   godot --path . --script res://tools/net_world_shot.gd -- --port 7099 --name 世界截图
## 输出：shots/world.png

const WARMUP := 20

var _port := 7099
var _name := "世界截图"
var _password := "password1"
var _menu: StartMenu
var _other: NetClient
var _stage := 0
var _frames := 0
var _t := 0.0


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


func _process(delta: float) -> bool:
	_frames += 1
	_t += delta
	match _stage:
		0:
			if _frames > WARMUP:
				_menu = current_scene.get_node("StartMenu") as StartMenu
				_menu.show_login()
				_menu.submit("127.0.0.1:%d" % _port, _name, _password)
				_stage = 1
				_frames = 0
		1:
			if _menu.client() != null and _menu.client().ready():
				_other = NetClient.new()
				root.add_child(_other)
				_other.connect_to("127.0.0.1", _port, "%sB" % _name, _password)
				_stage = 2
				_frames = 0
		2:
			if _other.ready():
				# B 在 A 前面绕圈走，A 应该看得见
				var spot := Vector3(cos(_t) * 2.5, 0.0, -3.5 + sin(_t) * 1.2)
				_other.send_move(0, spot, -_t, "seafood", "")
				_other.send_move(1, spot + Vector3(1.4, 0.0, 0.8), -_t, "red", "cherry")
				_stage = 3
				_frames = 0
		3:
			if _other.ready():
				var spot := Vector3(cos(_t) * 2.5, 0.0, -3.5 + sin(_t) * 1.2)
				_other.send_move(0, spot, -_t, "seafood", "")
				_other.send_move(1, spot + Vector3(1.4, 0.0, 0.8), -_t, "red", "cherry")
			if _frames > 120:
				root.get_texture().get_image().save_png("res://shots/world.png")
				var ghosts := 0
				for node in current_scene.get_node("Forest").get_children():
					if node is RemotePlayer:
						ghosts += 1
				print("森林里的替身：%d 个" % ghosts)
				return true
	if _stage >= 2 and _frames >= 900:
		printerr("登录没成功")
		return true
	return false
