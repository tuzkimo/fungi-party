class_name TentPanel
extends CanvasLayer

## 走到帐篷口才出现的浮层：睡觉、换帽子。每帧惰性找 tent：场景往返后旧引用会失效。

var _root: Control
var _stamina: Label
var _sleep: Button
var _clothes: Button
var _skins: GridContainer
var _built_key := ""


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

	_skins = GridContainer.new()
	_skins.columns = 4
	_skins.add_theme_constant_override("h_separation", 12)
	_skins.add_theme_constant_override("v_separation", 12)
	_skins.visible = false
	box.add_child(_skins)

	root.visible = false


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
	# _process 每帧都调这里，按钮只在已拥有/穿戴变了时才重建
	var key := "%s|%s" % [str(data["owned"]), str(data["equipped"])]
	if _skins.visible and key != _built_key:
		_built_key = key
		_build_skin_buttons(data)


## 已拥有的按档位从高到低排，最前面一个「默认红帽」。
func _build_skin_buttons(data: Dictionary) -> void:
	for child in _skins.get_children():
		child.queue_free()

	var equipped := str(data["equipped"])
	_add_skin_button("默认红帽", "", equipped == "")
	var skins: Array[MushroomSkin] = []
	for skin_id in data["owned"] as PackedStringArray:
		var skin := SkinCatalog.by_id(skin_id)
		if skin != null:
			skins.append(skin)
	skins.sort_custom(func(a, b): return a.rarity > b.rarity)
	for skin in skins:
		_add_skin_button(skin.display_name, skin.id, equipped == skin.id)


func _add_skin_button(text: String, skin_id: String, worn: bool) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(140.0, 52.0)
	button.disabled = worn
	button.pressed.connect(_on_wear.bind(skin_id))
	UIStyle.style_button(button)
	_skins.add_child(button)


func _on_sleep() -> void:
	var day_loop := get_tree().get_first_node_in_group("day_loop") as DayLoop
	if day_loop != null:
		day_loop.sleep()


func _on_clothes() -> void:
	_skins.visible = not _skins.visible
	_built_key = ""
	_refresh()


func _on_wear(skin_id: String) -> void:
	if not Save.equip(skin_id):
		return
	var player := get_tree().get_first_node_in_group("player") as Player
	if player != null:
		player.apply_skin()
	_built_key = ""
	_refresh()
