class_name TentPanel
extends CanvasLayer

## 走到帐篷口才出现的浮层：睡觉、换帽子。每帧惰性找 tent：场景往返后旧引用会失效。

var _root: Control
var _stamina: Label
var _sleep: Button
var _clothes: Button
var _skins: HBoxContainer
var _wear_default: Button
var _wear_skin: Button


func _ready() -> void:
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UIStyle.theme()
	add_child(root)
	_root = root

	# 靠右上角摆、不压暗场景：吃饭动画和换帽子都在玩家身上，面板挡住就白做了
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.custom_minimum_size = Vector2(620.0, 0.0)
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_right = -24.0
	panel.offset_top = 24.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.grow_vertical = Control.GROW_DIRECTION_END
	panel.add_theme_stylebox_override("panel", UIStyle.panel())
	root.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)

	var title := Label.new()
	title.text = "帐篷"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 38)
	box.add_child(title)

	_stamina = Label.new()
	_stamina.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_stamina)

	_sleep = Button.new()
	_sleep.text = "睡到早上"
	_sleep.custom_minimum_size = Vector2(240.0, 64.0)
	_sleep.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_sleep.pressed.connect(_on_sleep)
	UIStyle.style_button(_sleep)
	box.add_child(_sleep)

	_clothes = Button.new()
	_clothes.text = "换衣服"
	_clothes.custom_minimum_size = Vector2(240.0, 64.0)
	_clothes.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_clothes.pressed.connect(_on_clothes)
	UIStyle.style_button(_clothes)
	box.add_child(_clothes)

	_skins = HBoxContainer.new()
	_skins.alignment = BoxContainer.ALIGNMENT_CENTER
	_skins.add_theme_constant_override("separation", 20)
	_skins.visible = false
	box.add_child(_skins)

	_wear_default = _skin_button("默认红帽", false)
	_wear_skin = _skin_button("蓝莓帽", true)

	root.visible = false


func _skin_button(text: String, blueberry: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(180.0, 60.0)
	button.pressed.connect(_on_wear.bind(blueberry))
	UIStyle.style_button(button)
	_skins.add_child(button)
	return button


func _process(_delta: float) -> void:
	var tent := get_tree().get_first_node_in_group("tent") as Tent
	var day_loop := get_tree().get_first_node_in_group("day_loop") as DayLoop
	var sleeping := day_loop != null and day_loop.sleeping
	_root.visible = tent != null and tent.player_inside and not sleeping
	if _root.visible:
		_refresh()


func _refresh() -> void:
	var data := Save.read()
	_stamina.text = "体力 %d/%d" % [int(data["stamina"]), Config.STAMINA_MAX]
	var owned := bool(data["owned"])
	var equipped := bool(data["equipped"])
	_wear_skin.visible = owned
	_wear_default.disabled = not equipped
	_wear_skin.disabled = equipped


func _on_sleep() -> void:
	var day_loop := get_tree().get_first_node_in_group("day_loop") as DayLoop
	if day_loop != null:
		day_loop.sleep()


func _on_clothes() -> void:
	_skins.visible = not _skins.visible


func _on_wear(blueberry: bool) -> void:
	if not Save.equip(blueberry):
		return
	var player := get_tree().get_first_node_in_group("player") as Player
	if player != null:
		player.apply_skin()
	_refresh()
