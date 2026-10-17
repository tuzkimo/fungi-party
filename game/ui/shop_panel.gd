class_name ShopPanel
extends CanvasLayer

## 走到摊位前才出现的浮层。每帧惰性找 stall：森林与教室来回切之后旧引用都会失效。

var _panel: Panel
var _coins: Label
var _price: Label
var _buy: Button
var _shown := false


func _ready() -> void:
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = _make_theme()
	add_child(root)

	_panel = Panel.new()
	_panel.name = "Panel"
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = -280.0
	_panel.offset_right = 280.0
	_panel.offset_top = -300.0
	_panel.offset_bottom = -60.0
	_panel.visible = false
	root.add_child(_panel)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	_panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)

	_coins = Label.new()
	box.add_child(_coins)

	_price = Label.new()
	box.add_child(_price)

	_buy = Button.new()
	_buy.custom_minimum_size = Vector2(220.0, 60.0)
	_buy.pressed.connect(_on_buy)
	box.add_child(_buy)


func _process(_delta: float) -> void:
	# 只在「刚走近」时读一次存档：站着看菜单时每帧开一次 user:// 文件是白花的
	var stall := get_tree().get_first_node_in_group("stall") as Stall
	var show_now: bool = stall != null and stall.player_inside
	_panel.visible = show_now
	if show_now and not _shown:
		_refresh()
	_shown = show_now


func _refresh() -> void:
	var data := Save.read()
	var coins := int(data["coins"])
	_coins.text = "蘑菇币 %d" % coins
	if bool(data["owned"]):
		_price.text = "蓝莓帽 · 已戴上"
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
	var player := get_tree().get_first_node_in_group("player") as Player
	if player != null:
		player.apply_skin()
	_refresh()


func _make_theme() -> Theme:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Noto Sans CJK SC", "Noto Sans SC", "Droid Sans Fallback", "sans-serif"])
	font.allow_system_fallback = true
	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 28
	return theme
