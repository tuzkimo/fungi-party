class_name DayLoop
extends Node

## 森林侧唯一持有「今天」的地方：读存档、驱动天色、编排睡觉。
## 小游戏场景不感知体力（扣费在它们自己的 _ready 里，切回森林重建时重新读）。

signal changed

const FADE_IN := 0.5      # 淡到黑
const FADE_OUT := 0.7     # 黑到早上
const LIE_SECONDS := 0.4  # 走到床前躺下
const SUNSET_SECONDS := 1.2  # 见底后太阳压到落山的时长

@export var daynight_path: NodePath

var stamina := Config.STAMINA_MAX
var meals := 0
var day := 1
var time_of_day := Config.MORNING_TIME
var sleeping := false

var _daynight: DayNight
var _fade: ColorRect
var _sunset := -1.0
var _sunset_from := 0.0
var _save_timer := 0.0


func _ready() -> void:
	add_to_group("day_loop")
	_daynight = get_node_or_null(daynight_path) as DayNight
	refresh()
	_push_time()

	var layer := CanvasLayer.new()
	layer.name = "Fade"
	layer.layer = 100
	add_child(layer)
	_fade = ColorRect.new()
	_fade.name = "Black"
	_fade.color = Color(0.02, 0.02, 0.03)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.modulate.a = 0.0
	layer.add_child(_fade)


func _process(delta: float) -> void:
	if sleeping:
		return

	if Day.exhausted(stamina):
		# 见底：太阳不再按体力算，压到落山后就停在那儿
		if _sunset < 0.0:
			_sunset = 0.0
			_sunset_from = time_of_day
		_sunset = minf(_sunset + delta, SUNSET_SECONDS)
		time_of_day = maxf(time_of_day, lerpf(_sunset_from, Config.NIGHT_TIME, _sunset / SUNSET_SECONDS))
	else:
		_sunset = -1.0
		time_of_day = Day.advance_time(time_of_day, stamina)
	_push_time()

	_save_timer += delta
	if _save_timer >= Config.DAY_SAVE_INTERVAL:
		_save_timer = 0.0
		Save.set_day_time(time_of_day)


## 体力可能被吃饭改掉：改动的面板负责调这里，不在这里轮询。
## 天色拿存档里的水位当前提——不能用成员 time_of_day，那会把 0.71 盖回 0.28。
func refresh() -> void:
	var data := Save.read()
	stamina = int(data["stamina"])
	meals = int(data["meals"])
	day = int(data["day"])
	time_of_day = Day.advance_time(float(data["day_time"]), stamina)
	_push_time()
	changed.emit()


func sleep() -> void:
	if sleeping:
		return
	sleeping = true
	changed.emit()

	var players: Array[Node3D] = []
	for body in get_tree().get_nodes_in_group("player"):
		var node := body as Node3D
		if node != null:
			players.append(node)
	var tent := get_tree().get_first_node_in_group("tent") as Tent
	var touch := get_tree().get_first_node_in_group("touch_controls") as CanvasItem
	if touch != null:
		touch.visible = false
	if tent != null:
		var tween := create_tween().set_parallel(true)
		# 双人就并排躺：二号位这时候可能正在带队，他也不能继续走
		for i in players.size():
			players[i].set_physics_process(false)
			var bed := tent.bed_global_position() + Vector3(0.45 * float(i), 0.35, 0.0)
			tween.tween_property(players[i], "global_position", bed, LIE_SECONDS)
			tween.tween_property(players[i], "rotation:z", -PI / 2.0, LIE_SECONDS)
		await tween.finished

	await get_tree().create_timer(0.3).timeout
	await _fade_to(1.0, FADE_IN)

	Save.rollover()
	time_of_day = Config.MORNING_TIME
	refresh()

	if tent != null:
		for i in players.size():
			players[i].global_position = tent.global_position + Vector3(0.45 * float(i), 0.3, 1.2)
			players[i].rotation.z = 0.0
			players[i].set_physics_process(true)
	if touch != null:
		touch.visible = true

	await _fade_to(0.0, FADE_OUT)
	sleeping = false
	changed.emit()


func _fade_to(alpha: float, seconds: float) -> void:
	var tween := create_tween()
	tween.tween_property(_fade, "modulate:a", alpha, seconds)
	await tween.finished


func _push_time() -> void:
	if _daynight != null and absf(_daynight.time_of_day - time_of_day) > 0.0005:
		_daynight.time_of_day = time_of_day
		_daynight.apply()
