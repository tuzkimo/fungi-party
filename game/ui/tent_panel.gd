class_name TentPanel
extends CanvasLayer

## 走到帐篷口才出现的浮层：睡觉、换角色、换帽子。每帧惰性找 tent：场景往返后旧引用会失效。
## 二号位加入后多一行座位按钮：换的是他那个人的形象（只活在这次运行里，不写盘）。

var _root: Control
var _stamina: Label
var _sleep: Button
var _clothes: Button
var _seats: HBoxContainer
var _skins: VBoxContainer
var _characters: HBoxContainer
var _seat := 0
var _built_key := ""
var _character_key := ""


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

	# 座位行：单人时不出现；双人就选「换谁的形象」
	_seats = HBoxContainer.new()
	_seats.add_theme_constant_override("separation", 10)
	_seats.alignment = BoxContainer.ALIGNMENT_CENTER
	for seat in Party.MAX:
		var button := Button.new()
		button.text = Party.name_of(seat)
		button.custom_minimum_size = Vector2(120.0, 48.0)
		button.pressed.connect(_on_pick_seat.bind(seat))
		UIStyle.style_button(button)
		_seats.add_child(button)
	box.add_child(_seats)

	_sleep = Button.new()
	_sleep.text = "睡到早上"
	_sleep.custom_minimum_size = Vector2(240.0, 56.0)
	_sleep.pressed.connect(_on_sleep)
	UIStyle.style_button(_sleep)

	_clothes = Button.new()
	_clothes.text = "换衣服"
	_clothes.custom_minimum_size = Vector2(240.0, 56.0)
	_clothes.pressed.connect(_on_clothes)
	UIStyle.style_button(_clothes)

	# 两个动作并排：衣柜展开后已经很满，再分两行最后一档皮肤就出屏了
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 12)
	actions.add_child(_sleep)
	actions.add_child(_clothes)
	box.add_child(actions)

	# 角色不折叠：它跟皮肤不是一个东西（皮肤是收藏，角色是「我是谁」），藏在二级菜单里会找不到
	_characters = HBoxContainer.new()
	_characters.add_theme_constant_override("separation", 10)
	_characters.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(_characters)

	# 一行一个档位：档位名在行首，后面跟这一档已拥有的皮肤。
	# 不用「标题 + 一行按钮」那种分组，720 高的屏幕放不下六组。
	_skins = VBoxContainer.new()
	_skins.add_theme_constant_override("separation", 8)
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
	_sync_seats()
	var look := Party.look(_seat)
	var character_key := "%d|%s" % [_seat, str(look["body"])]
	if character_key != _character_key:
		_character_key = character_key
		_build_character_buttons(str(look["body"]))
	# _process 每帧都调这里，按钮只在已拥有/穿戴/座位变了时才重建
	var key := "%d|%s|%s" % [_seat, str(data["owned"]), str(look["skin"])]
	if _skins.visible and key != _built_key:
		_built_key = key
		_build_skin_buttons(data, str(look["skin"]))


## 二号位不在就藏座位行、回到一号位。
func _sync_seats() -> void:
	_seats.visible = Party.joined()
	if not _seats.visible:
		_seat = 0
	for i in _seats.get_child_count():
		(_seats.get_child(i) as Button).disabled = i == _seat


## 角色一行：免费换，当前的那个按下不动。
func _build_character_buttons(equipped: String) -> void:
	for child in _characters.get_children():
		child.queue_free()
	var label := Label.new()
	label.text = "角色"
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color(0.62, 0.60, 0.64))
	_characters.add_child(label)
	for id in BodyCatalog.ids():
		var button := Button.new()
		button.text = BodyCatalog.display_name(id)
		button.custom_minimum_size = Vector2(132.0, 48.0)
		button.disabled = id == equipped
		button.pressed.connect(_on_pick_character.bind(id))
		UIStyle.style_button(button)
		_characters.add_child(button)


## 一行一档，档位名在行首，按钮带档位描边色。
func _build_skin_buttons(data: Dictionary, equipped: String) -> void:
	for child in _skins.get_children():
		child.queue_free()

	var owned := data["owned"] as PackedStringArray
	_add_skin_button(_skin_row("默认", Color(0.62, 0.60, 0.64)), "红帽", "", true, equipped == "")
	for group in SkinCatalog.group_by_rarity():
		var rarity := int(group["rarity"])
		var row := _skin_row(Config.RARITY_NAMES[rarity], Config.RARITY_COLORS[rarity])
		for skin in group["skins"] as Array:
			var has := owned.has(skin.id)
			_add_skin_button(
				row,
				skin.display_name if has else "???",
				skin.id,
				has,
				equipped == skin.id,
			)


## 一行 = 档位名 + 这一档的按钮。
func _skin_row(title: String, color: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_skins.add_child(row)
	var label := Label.new()
	label.text = title
	label.custom_minimum_size = Vector2(72.0, 0.0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", color)
	row.add_child(label)
	return row


## owned 为假的就是还没抽到：显示「???」，点不动，描边减淡。
## 用半角问号：全角 ？ 在真机系统字体上是豆腐块（见 UIStyle.theme）。
func _add_skin_button(row: HBoxContainer, text: String, skin_id: String, has: bool, worn: bool) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(132.0, 48.0)
	button.disabled = worn or not has
	button.pressed.connect(_on_wear.bind(skin_id))
	var border := Color(0.0, 0.0, 0.0, 0.0)
	if has and skin_id != "":
		var color := _rarity_color(skin_id)
		border = color
	UIStyle.style_button(button, border)
	row.add_child(button)


func _rarity_color(skin_id: String) -> Color:
	var skin := SkinCatalog.by_id(skin_id)
	return Config.RARITY_COLORS[skin.rarity] if skin != null else Color(0.0, 0.0, 0.0, 0.0)


func _on_sleep() -> void:
	var day_loop := get_tree().get_first_node_in_group("day_loop") as DayLoop
	if day_loop != null:
		day_loop.sleep()


func _on_clothes() -> void:
	_skins.visible = not _skins.visible
	_built_key = ""
	_refresh()


## 座位变了：角色行和皮肤行都重建成那个人的。
func _on_pick_seat(seat: int) -> void:
	_seat = seat
	_character_key = ""
	_built_key = ""
	_refresh()


func _on_pick_character(character_id: String) -> void:
	if _seat == 0:
		if not Save.set_character(character_id):
			return
	else:
		Party.set_body(character_id)
	_apply_look()
	_character_key = ""
	_refresh()


func _on_wear(skin_id: String) -> void:
	if _seat == 0:
		if not Save.equip(skin_id):
			return
	else:
		Party.set_skin(skin_id)
	_apply_look()
	_built_key = ""
	_refresh()


## 只刷改的那一位的外观：另一个人不该跟着变。
func _apply_look() -> void:
	if not is_inside_tree():
		return
	var player := Player.of_seat(get_tree(), _seat)
	if player != null:
		player.apply_skin()
