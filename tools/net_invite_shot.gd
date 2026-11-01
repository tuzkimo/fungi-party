extends SceneTree

## 桌面看一眼邀请：A 登录，脚本用第二条连接扮演 B 站在旁边并邀请 A，
## 截图里该有「邀请」列表和顶部那条横幅；然后按「接受」，A 应该被拉进这一款小游戏。
##   godot --path . --script res://tools/net_invite_shot.gd -- --port 7099 --name 邀请截图 [--kind owl]
## 输出：shots/invite.png

const WARMUP := 20

var _port := 7099
var _name := "邀请截图"
var _password := "password1"
var _kind := "classroom"
var _menu: StartMenu
var _panel: InvitePanel
var _other: NetClient
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
			"--kind":
				_kind = args[i + 1]
		i += 2
	change_scene_to_file("res://game/main.tscn")


func _process(_delta: float) -> bool:
	_frames += 1
	match _stage:
		0:
			if _frames > WARMUP:
				_menu = current_scene.get_node("StartMenu") as StartMenu
				_panel = current_scene.get_node("InvitePanel") as InvitePanel
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
				_stage = 3
				_frames = 0
		3:
			# B 站在 A 前面，顺手把邀请发过来
			if _other.ready():
				_other.send_move(0, Vector3(0.0, 0.0, -4.0), 3.14, "seafood", "")
			if _frames > 40:
				_other.request("invite", {"to": _name, "kind": _kind})
				_stage = 4
				_frames = 0
		4:
			if _other.ready():
				_other.send_move(0, Vector3(0.0, 0.0, -4.0), 3.14, "seafood", "")
			if _frames > 30:
				_panel._on_toggle()
				# 顺手从这一层发一条邀请出去：「已邀请 X，等他答应」该出现在面板上
				_panel._on_invite_button("%sB" % _name, _kind)
				_stage = 5
				_frames = 0
		5:
			if _other.ready():
				_other.send_move(0, Vector3(0.0, 0.0, -4.0), 3.14, "seafood", "")
			if _frames > 20:
				root.get_texture().get_image().save_png("res://shots/invite.png")
				print("列表里的人：%s，收到的邀请：%s" % [
					str(InvitePanel.invitable(_other_world())), str(_other_invites())
				])
				_panel._on_answer_button(true)
				_stage = 6
				_frames = 0
		6:
			if _frames > 90:
				var kind := ""
				var net := root.get_node_or_null("Net") as NetClient
				if net != null:
					kind = str(net.session.get("kind", ""))
				print("接受之后：场景 %s，这一局 %s" % [str(current_scene.scene_file_path), kind])
				# 猫头鹰：快照已经写进本机的模型（教室那份模型没有关卡，跳过）
				var round: Variant = current_scene.get("_round")
				if round is OwlRound:
					print("局内：第 %d 关、剩 %.1f 秒（快照已生效）" % [int(round.get("level")), float(round.get("time_left"))])
				if round is RaceRound:
					print("局内：倒数 %.1f 秒、0 号在 %.1f 米（快照已生效）" % [
						float(round.get("countdown")), float((round.racers[0] as RaceRacer).z)
					])
				return true
	if _stage >= 1 and _frames >= 900:
		printerr("登录没成功")
		return true
	return false


func _other_world() -> Dictionary:
	var net := root.get_node_or_null("Net") as NetClient
	return net.world if net != null else {}


func _other_invites() -> Array:
	var net := root.get_node_or_null("Net") as NetClient
	return net.invites if net != null else []
