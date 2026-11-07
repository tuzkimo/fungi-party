class_name ShopPanel
extends CanvasLayer

## 走到摊位前才出现的浮层。每帧惰性找 stall：森林与教室来回切之后旧引用都会失效。

const PANEL_WIDTH := 900.0
const CARD_SIZE := Vector2(168.0, 150.0)
const CARD_COLUMNS := 5

var _root: Control
var _coins: Label
var _status: Label
var _one: Button
var _ten: Button
var _results: GridContainer
var _shown := false
## 正等服务器回几个抽（0 = 没在等）：联机时币和皮肤都归服务器，本机的 Gacha 只改镜像
var _awaiting := 0
## 发 op 之前的那份回执：用它认出「新到的那一条」，别把上一次抽卡的结果再演出一遍
var _seen_result: Dictionary = {}


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
	panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
	panel.add_theme_stylebox_override("panel", UIStyle.panel())
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)

	_coins = Label.new()
	_coins.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_coins)

	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_status)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 24)
	box.add_child(buttons)

	_one = Button.new()
	_one.custom_minimum_size = Vector2(260.0, 60.0)
	_one.pressed.connect(_on_pull_one)
	UIStyle.style_button(_one)
	buttons.add_child(_one)

	_ten = Button.new()
	_ten.custom_minimum_size = Vector2(260.0, 60.0)
	_ten.pressed.connect(_on_pull_ten)
	UIStyle.style_button(_ten)
	buttons.add_child(_ten)

	_results = GridContainer.new()
	_results.columns = CARD_COLUMNS
	_results.add_theme_constant_override("h_separation", 12)
	_results.add_theme_constant_override("v_separation", 12)
	box.add_child(_results)

	root.visible = false


func _process(_delta: float) -> void:
	if _awaiting > 0:
		_take_online_pull()
	var stall := get_tree().get_first_node_in_group("stall") as Stall
	var show_now: bool = stall != null and stall.player_inside
	_root.visible = show_now
	if show_now != _shown:
		_shown = show_now
		if show_now:
			_refresh()
		else:
			_clear_results()


## 只在进入摊位和抽完之后调，不每帧刷。
func _refresh() -> void:
	var data := Save.read()
	var coins := int(data["coins"])
	_coins.text = "蘑菇币 %d" % coins
	if (data["owned"] as PackedStringArray).size() >= SkinCatalog.count():
		_status.text = "已集齐 %d/%d" % [SkinCatalog.count(), SkinCatalog.count()]
		_one.disabled = true
		_ten.disabled = true
		_one.text = "已集齐"
		_ten.text = "已集齐"
		return
	_status.text = "已拥有 %d/%d" % [(data["owned"] as PackedStringArray).size(), SkinCatalog.count()]
	if _awaiting > 0:
		# 等服务器回执：币是服务器扣的，这时候再点没意义
		_one.disabled = true
		_ten.disabled = true
		_one.text = "抽卡中..."
		_ten.text = "抽卡中..."
		return
	_one.text = "单抽 · %d 币" % Config.GACHA_PRICE_ONE
	if coins < Config.GACHA_PRICE_ONE:
		_one.text = "还差 %d 币" % (Config.GACHA_PRICE_ONE - coins)
	_one.disabled = coins < Config.GACHA_PRICE_ONE
	_ten.text = "十连 · %d 币" % Config.GACHA_PRICE_TEN
	if coins < Config.GACHA_PRICE_TEN:
		_ten.text = "还差 %d 币" % (Config.GACHA_PRICE_TEN - coins)
	_ten.disabled = coins < Config.GACHA_PRICE_TEN


func _on_pull_one() -> void:
	_pull(1)


func _on_pull_ten() -> void:
	_pull(10)


## 联机时币和已拥有都在服务器上，本机那份只读：走本机 Gacha 等于白抽（不扣钱、皮肤也不算数），
## 所以一律发 op，等 OP_RESULT 里的结果再放演出。
func _pull(count: int) -> void:
	if _awaiting > 0:
		return
	var net := Save.remote as NetClient
	if net != null:
		_awaiting = count
		_seen_result = net.last_result
		net.request("pull", {"n": count})
		_refresh()
		return
	if count == 1:
		var one := Gacha.pull()
		if not bool(one["ok"]):
			return
		_show_results([one])
	else:
		var ten := Gacha.pull_ten()
		if ten.is_empty():
			return
		_show_results(ten)
	_after_pull()


## 服务器的回执到了才算到账：币是服务器扣的，这里只负责把结果画出来。
func _take_online_pull() -> void:
	var net := Save.remote as NetClient
	if net == null:
		_awaiting = 0
		return
	var result: Dictionary = net.last_result
	if is_same(result, _seen_result):
		return
	_awaiting = 0
	_seen_result = result
	var pulls: Array = (result.get("result", {}) as Dictionary).get("pulls", [])
	if not bool(result.get("ok", false)) or pulls.is_empty():
		_refresh()
		return
	_show_results(pulls)
	_after_pull()


func _after_pull() -> void:
	_apply_skin_to_player()
	_refresh()


func _apply_skin_to_player() -> void:
	if not is_inside_tree():
		return
	var player := get_tree().get_first_node_in_group("player") as Player
	if player != null:
		player.apply_skin()


func _clear_results() -> void:
	for child in _results.get_children():
		_results.remove_child(child)
		child.queue_free()


func _show_results(results: Array) -> void:
	_clear_results()
	for result in results:
		_results.add_child(_make_card(result))


## 一张结果卡：档位色描边 + 皮肤帽色底 + 名字 + 档位名，重复的补一行退币。
func _make_card(result: Dictionary) -> Control:
	var skin := SkinCatalog.by_id(str(result["id"]))
	var rarity := int(result["rarity"])
	var color: Color = Config.RARITY_COLORS[rarity]

	var panel := PanelContainer.new()
	panel.custom_minimum_size = CARD_SIZE
	var style := StyleBoxFlat.new()
	style.bg_color = skin.tint_cap.darkened(0.6) if skin != null else Color(0.2, 0.2, 0.2)
	style.border_color = color
	style.set_border_width_all(4 if rarity == 4 else 2)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(10.0)
	panel.add_theme_stylebox_override("panel", style)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)

	var name_label := Label.new()
	name_label.text = skin.display_name if skin != null else str(result["id"])
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_font_size_override("font_size", 24)
	box.add_child(name_label)

	var rarity_label := Label.new()
	rarity_label.text = Config.RARITY_NAMES[rarity]
	rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity_label.add_theme_font_size_override("font_size", 20)
	rarity_label.add_theme_color_override("font_color", color)
	box.add_child(rarity_label)

	if bool(result["duplicate"]):
		var refund_label := Label.new()
		refund_label.text = "重复 +%d 币" % int(result["refund"])
		refund_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		refund_label.add_theme_font_size_override("font_size", 18)
		refund_label.add_theme_color_override("font_color", Color(0.75, 0.73, 0.70))
		box.add_child(refund_label)

	return panel
