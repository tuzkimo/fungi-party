class_name StartMenu
extends CanvasLayer

## 开机盖在最上面的一层：一个人玩 / 联网。联网走登录表单（服务器地址、昵称、密码）。
## 表单一律用 ASCII 标点提示：系统字体不一定有全角括号（真机是豆腐块）。

signal offline_chosen
signal online_ready

const FORM_PATH := "user://net.cfg"

var _client: NetClient
## 上次登录成功后存在本机的那把密钥：关机重进也不用手输口令。空 = 没登录过。
var _saved_key := ""
## 正在用存下的密钥自动登录（失败时那句提示不一样）
var _auto := false
var _root: Control
var _modes: HBoxContainer
var _form: VBoxContainer
var _host: LineEdit
var _name: LineEdit
var _password: LineEdit
var _status: Label
var _go: Button
var _back: Button


func setup(client: NetClient) -> void:
	_client = client
	_client.logged_in.connect(_on_logged_in)
	_client.failed.connect(_on_failed)


func _ready() -> void:
	_build()
	_load_form()
	show_modes()


## 工具和「联网」按钮共用同一个入口：把表单亮出来。
func show_login() -> void:
	_root.visible = true
	_on_online()


## 填好表单直接点火（截图工具和无触摸测试用）。
func submit(host: String, player_name: String, password: String) -> void:
	_host.text = host
	_name.text = player_name
	_password.text = password
	_on_login()


func client() -> NetClient:
	return _client


func show_modes() -> void:
	_root.visible = true
	_modes.visible = true
	_form.visible = false
	_status.text = ""


func _build() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = UIStyle.theme()
	add_child(_root)

	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.05, 0.07, 0.05, 0.92)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.custom_minimum_size = Vector2(760.0, 0.0)
	panel.add_theme_stylebox_override("panel", UIStyle.panel())
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	panel.add_child(box)

	var title := Label.new()
	title.text = "菌子派对"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 52)
	box.add_child(title)

	_modes = HBoxContainer.new()
	_modes.alignment = BoxContainer.ALIGNMENT_CENTER
	_modes.add_theme_constant_override("separation", 28)
	box.add_child(_modes)

	var solo := Button.new()
	solo.text = "一个人玩"
	solo.custom_minimum_size = Vector2(280.0, 88.0)
	solo.pressed.connect(_on_offline)
	UIStyle.style_button(solo)
	_modes.add_child(solo)

	var online := Button.new()
	online.text = "联网"
	online.custom_minimum_size = Vector2(280.0, 88.0)
	online.pressed.connect(_on_online)
	UIStyle.style_button(online)
	_modes.add_child(online)

	_form = VBoxContainer.new()
	_form.add_theme_constant_override("separation", 12)
	box.add_child(_form)

	_host = _field()
	_host.placeholder_text = "服务器地址 (host:port)"
	_form.add_child(_host)
	_name = _field()
	_name.placeholder_text = "昵称"
	_form.add_child(_name)
	_password = _field()
	_password.placeholder_text = "密码"
	_password.secret = true
	_form.add_child(_password)

	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_color_override("font_color", Color(0.98, 0.72, 0.55))
	_form.add_child(_status)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	_form.add_child(row)

	_back = Button.new()
	_back.text = "返回"
	_back.custom_minimum_size = Vector2(200.0, 72.0)
	_back.pressed.connect(show_modes)
	UIStyle.style_button(_back)
	row.add_child(_back)

	_go = Button.new()
	_go.text = "登录 / 注册"
	_go.custom_minimum_size = Vector2(360.0, 72.0)
	_go.pressed.connect(_on_login)
	UIStyle.style_button(_go)
	row.add_child(_go)


func _field() -> LineEdit:
	var edit := LineEdit.new()
	edit.custom_minimum_size = Vector2(600.0, 68.0)
	edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	edit.add_theme_font_size_override("font_size", 30)
	return edit


## 地址里写 host:port 就照它来，只写 IP 就用默认端口。
static func parse_host(text: String) -> Array:
	var host := text.strip_edges()
	if host.contains(":"):
		var parts := host.split(":")
		return [parts[0].strip_edges(), int(parts[1])]
	return [host, Config.SERVER_PORT]


## 启动时由 main.gd 调一次：上次登录过就直接拿存下的密钥连回去（口令不落盘），
## 连不上再让人自己输密码。截图工具不调它，免得开机就被自动登录盖住登录表单。
func auto_login() -> void:
	var player_name := _name.text.strip_edges()
	if _saved_key == "" or player_name == "":
		return
	var parts := parse_host(_host.text)
	_auto = true
	_go.disabled = true
	show_login()
	_status.text = "自动登录中..."
	_client.connect_with_key(str(parts[0]), int(parts[1]), player_name, _saved_key)


func _on_offline() -> void:
	_root.visible = false
	offline_chosen.emit()


func _on_online() -> void:
	_modes.visible = false
	_form.visible = true
	_status.text = ""


func _on_login() -> void:
	if _client == null:
		return
	var parts := parse_host(_host.text)
	var host := str(parts[0])
	var port := int(parts[1])
	var player_name := _name.text.strip_edges()
	if host == "" or player_name == "" or _password.text == "":
		_status.text = "服务器、昵称、密码都要填"
		return
	_auto = false
	_save_form()
	_go.disabled = true
	_status.text = "连接中..."
	_client.connect_to(host, port, player_name, _password.text)


func _on_logged_in() -> void:
	_go.disabled = false
	_auto = false
	# 登录成功后把这次的密钥记在本机：下次开机不用再输口令
	_saved_key = _client.key_hex
	_save_form()
	if _password != null:
		_password.text = ""
	_root.visible = false
	online_ready.emit()


func _on_failed(reason: String) -> void:
	_go.disabled = false
	_root.visible = true
	_modes.visible = false
	_form.visible = true
	if _auto:
		_auto = false
		if reason == "auth":
			# 存下的密钥服务器不认了（换过密码、存档被删）：忘掉它，让人重新输密码
			_saved_key = ""
			_save_form()
			_status.text = "登录过期了，请重新输入密码"
			return
	_status.text = "连不上：%s" % _reason_text(reason)


## 主动登出：忘掉本机存的那把密钥并断开，回到登录表单（存档在服务器上，一样都没丢）。
func forget() -> void:
	_saved_key = ""
	_auto = false
	_save_form()
	if _client != null:
		_client.close()
	_password.text = ""
	_go.disabled = false
	show_login()


## 服务器来的 reason 是英文短码，翻成玩家看得懂的话
func _reason_text(reason: String) -> String:
	match reason:
		"connect", "timeout":
			return "服务器没回应"
		"auth":
			return "密码不对"
		"name":
			return "昵称不合法 (2-16 字，别带空格和斜杠)"
		"taken":
			return "昵称被占用了"
		"version":
			return "游戏版本和服务器不一致"
		"closed":
			return "和服务器断开了"
		_:
			return reason


func _save_form() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("net", "host", _host.text.strip_edges())
	cfg.set_value("net", "name", _name.text.strip_edges())
	cfg.set_value("net", "key", _saved_key)
	cfg.save(FORM_PATH)


func _load_form() -> void:
	var cfg := ConfigFile.new()
	cfg.load(FORM_PATH)
	_host.text = str(cfg.get_value("net", "host", Config.SERVER_HOST))
	_name.text = str(cfg.get_value("net", "name", ""))
	_saved_key = str(cfg.get_value("net", "key", ""))
