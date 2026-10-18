class_name MealPanel
extends CanvasLayer

## 走到饭店门口才出现的浮层：花 20 币吃一份，回 25 体力，一天三份。
## 见底之后打烊——「吃不吃」要在太阳落山前决定。每帧惰性找 restaurant。

var _root: Control
var _stamina: Label
var _coins: Label
var _meals: Label
var _eat: Button
var _busy := false


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
	title.text = "饭店"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 38)
	box.add_child(title)

	_stamina = Label.new()
	_stamina.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_stamina)

	_coins = Label.new()
	_coins.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_coins)

	_meals = Label.new()
	_meals.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_meals)

	_eat = Button.new()
	_eat.custom_minimum_size = Vector2(260.0, 64.0)
	_eat.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_eat.pressed.connect(_on_eat)
	UIStyle.style_button(_eat)
	box.add_child(_eat)

	root.visible = false


func _process(_delta: float) -> void:
	var restaurant := get_tree().get_first_node_in_group("restaurant") as Restaurant
	_root.visible = restaurant != null and restaurant.player_inside
	if _root.visible:
		_refresh()


func _refresh() -> void:
	var day_loop := get_tree().get_first_node_in_group("day_loop") as DayLoop
	if day_loop == null:
		return
	var stamina := day_loop.stamina
	var meals := day_loop.meals
	var coins := int(Save.read()["coins"])
	_stamina.text = "体力 %d/%d" % [stamina, Config.STAMINA_MAX]
	_coins.text = "蘑菇币 %d" % coins
	_meals.text = "今天第 %d/%d 份" % [mini(meals + 1, Config.MEALS_PER_DAY), Config.MEALS_PER_DAY]

	var ok := bool(Day.meal(stamina, meals, coins)["ok"])
	_eat.disabled = _busy or not ok
	if ok:
		_eat.text = "吃一份（%d 币）" % Config.MEAL_COINS
	elif meals >= Config.MEALS_PER_DAY:
		_eat.text = "今天吃够了"
	elif coins < Config.MEAL_COINS:
		_eat.text = "还差 %d 币" % (Config.MEAL_COINS - coins)
	elif stamina >= Config.STAMINA_MAX:
		_eat.text = "还饱着"
	else:
		_eat.text = "打烊了，明天再来"


func _on_eat() -> void:
	if _busy:
		return
	if not Save.eat_meal():
		return
	_busy = true
	_eat.disabled = true

	var player := get_tree().get_first_node_in_group("player") as Player
	if player != null:
		player.chew()
		var bowl := MealBowl.create()
		bowl.position = Vector3(0.0, 0.9, 0.9)
		player.add_child(bowl)
		bowl.play()

	var day_loop := get_tree().get_first_node_in_group("day_loop") as DayLoop
	if day_loop != null:
		day_loop.refresh()
	_refresh()

	await get_tree().create_timer(Config.MEAL_ANIMATION_SECONDS).timeout
	_busy = false
	_refresh()
