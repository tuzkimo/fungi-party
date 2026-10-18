class_name ShopPanel
extends CanvasLayer

## 走到摊位前才出现的浮层。每帧惰性找 stall：森林与教室来回切之后旧引用都会失效。

var _root: Control
var _coins: Label
var _price: Label
var _buy: Button
var _shown := false


func _ready() -> void:
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UIStyle.theme()
	add_child(root)
	_root = root

	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.03, 0.03, 0.04, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)

	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)

	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.custom_minimum_size = Vector2(620.0, 0.0)
	panel.add_theme_stylebox_override("panel", UIStyle.panel())
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)

	_coins = Label.new()
	box.add_child(_coins)

	_price = Label.new()
	box.add_child(_price)

	_buy = Button.new()
	_buy.custom_minimum_size = Vector2(220.0, 60.0)
	_buy.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_buy.pressed.connect(_on_buy)
	UIStyle.style_button(_buy)
	box.add_child(_buy)

	root.visible = false


func _process(_delta: float) -> void:
	var stall := get_tree().get_first_node_in_group("stall") as Stall
	var show_now: bool = stall != null and stall.player_inside
	_root.visible = show_now
	if show_now and not _shown:
		_refresh()
	_shown = show_now


func _refresh() -> void:
	var data := Save.read()
	var coins := int(data["coins"])
	_coins.text = "蘑菇币 %d" % coins
	var owned := bool(data["owned"])
	if owned:
		_price.text = "蓝莓帽 · 已买下 · 到帐篷里换"
		_buy.visible = false
	else:
		_price.text = "蓝莓帽 · %d 币" % Config.SKIN_PRICE
		_buy.visible = true
		_buy.disabled = coins < Config.SKIN_PRICE
		_buy.text = "买" if coins >= Config.SKIN_PRICE else "还差 %d 币" % (Config.SKIN_PRICE - coins)


## 买一顶皮肤：钱够且还没拥有才成交，返回是否买成。
static func purchase(path: String = Save.PATH) -> bool:
	var data := Save.read(path)
	if bool(data["owned"]) or int(data["coins"]) < Config.SKIN_PRICE:
		return false
	Save.write(path, {"coins": int(data["coins"]) - Config.SKIN_PRICE, "owned": true, "equipped": true})
	return true


func _on_buy() -> void:
	if not purchase():
		return
	_apply_skin_to_player()
	_refresh()


func _apply_skin_to_player() -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	if player != null:
		player.apply_skin()
