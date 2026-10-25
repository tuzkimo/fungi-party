extends SceneTree

## 桌面端全链路看一眼：启动菜单 → 登录表单 → 真登录本机服务器 → 回森林（币来自服务器）。
##   godot --path . --script res://tools/net_login_shot.gd -- --port 7099 --name 截图测试
## 输出：shots/login.png、shots/login_online.png

const WARMUP := 20

var _port := 7099
var _name := "截图测试"
var _password := "password1"
var _menu: StartMenu
var _stage := 0
var _frames := 0


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


func _process(_delta: float) -> bool:
	_frames += 1
	match _stage:
		0:
			if _frames > WARMUP:
				_menu = current_scene.get_node("StartMenu") as StartMenu
				_menu.show_login()
				_stage = 1
				_frames = 0
		1:
			# 等表单真的画出来再拍
			if _frames > 10:
				root.get_texture().get_image().save_png("res://shots/login.png")
				_menu.submit("127.0.0.1:%d" % _port, _name, _password)
				_stage = 2
				_frames = 0
		2:
			var client := _menu.client()
			if client != null and client.ready():
				_stage = 3
				_frames = 0
			elif _frames >= 600:
				printerr("登录没成功")
				return true
		3:
			# HUD 每 0.25 秒读一次存档，等它刷过来再拍
			if _frames > 90:
				root.get_texture().get_image().save_png("res://shots/login_online.png")
				var data := Save.read()
				print("联机后存档：币 %d 体力 %d 天数 %d 皮肤 %s" % [
					int(data["coins"]), int(data["stamina"]), int(data["day"]), str(data["owned"])
				])
				print("账号：%s" % _menu.client().me())
				return true
	return false
