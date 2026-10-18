class_name DayHUD
extends CanvasLayer

## 森林左上角常驻：体力条、蘑菇币、见底提示。
## 0.25 秒读一次存档（Save.read 是读文件，别每帧），睡觉/吃饭后靠 DayLoop.changed 立刻更新。

const REFRESH_SECONDS := 0.25
const WARN_COLOR := Color(1.0, 0.45, 0.40)

var _root: Control
var _stamina: Label
var _bar: ProgressBar
var _coins: Label
var _hint: Label
var _wired := false


func _ready() -> void:
	var panel := PanelContainer.new()
	panel.name = "Root"
	# 往下让出 debug HUD 的 FPS/DRAW/TRI 那一行：真机上要用它记帧率
	panel.position = Vector2(20.0, 64.0)
	panel.custom_minimum_size = Vector2(320.0, 0.0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.theme = UIStyle.theme()
	panel.add_theme_stylebox_override("panel", UIStyle.panel())
	add_child(panel)
	_root = panel

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(box)

	_stamina = Label.new()
	box.add_child(_stamina)

	_bar = ProgressBar.new()
	_bar.min_value = 0.0
	_bar.max_value = float(Config.STAMINA_MAX)
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(260.0, 22.0)
	box.add_child(_bar)

	_coins = Label.new()
	box.add_child(_coins)

	_hint = Label.new()
	_hint.text = "回帐篷睡觉"
	_hint.visible = false
	box.add_child(_hint)

	var timer := Timer.new()
	timer.wait_time = REFRESH_SECONDS
	timer.autostart = true
	timer.timeout.connect(_refresh)
	add_child(timer)

	_refresh()


func _refresh() -> void:
	var day_loop := get_tree().get_first_node_in_group("day_loop") as DayLoop
	if day_loop == null:
		_root.visible = false
		return
	_root.visible = true
	if not _wired:
		day_loop.changed.connect(_refresh)
		_wired = true

	var stamina := day_loop.stamina
	_stamina.text = "体力 %d/%d" % [stamina, Config.STAMINA_MAX]
	_bar.value = float(stamina)
	_coins.text = "蘑菇币 %d" % int(Save.read()["coins"])
	if Day.exhausted(stamina):
		_stamina.add_theme_color_override("font_color", WARN_COLOR)
		_hint.visible = true
	else:
		_stamina.remove_theme_color_override("font_color")
		_hint.visible = false
