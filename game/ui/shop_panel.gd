class_name ShopPanel
extends CanvasLayer

## 走到摊位前才出现的浮层。每帧惰性找 stall：森林与教室来回切之后旧引用都会失效。

var _root: Control
var _coins: Label
var _status: Label
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

	_status = Label.new()
	box.add_child(_status)

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
	_coins.text = "蘑菇币 %d" % int(data["coins"])
	_status.text = "已拥有 %d/%d · 到帐篷里换" % [
		(data["owned"] as PackedStringArray).size(), SkinCatalog.count()
	]


func _apply_skin_to_player() -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	if player != null:
		player.apply_skin()
