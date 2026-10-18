extends Node3D

## 临时预览壳：摆场地和四个座位，Task 6 会换成真正的场景编排。
## 桌面跑一次顺手把截图存到 shots/v3-bomb-arena.png。

const SEAT_COLORS := [
	Color(0.92, 0.25, 0.22), Color(0.32, 0.55, 0.88), Color(0.86, 0.30, 0.26), Color(0.66, 0.40, 0.86)
]

var _seats: Array[BombSeat] = []
var _frame := 0


func _ready() -> void:
	var camera: Camera3D = $Camera3D
	camera.position = Vector3(0.0, 7.8, 7.0)
	camera.look_at(Vector3(0.0, 0.4, 0.0))

	var arena := BombArena.new()
	arena.name = "Arena"
	add_child(arena)
	arena.build()

	for i in BombRound.SEATS:
		var seat := BombSeat.new()
		seat.name = "Seat%d" % i
		seat.position = BombSeat.seat_position(i)
		add_child(seat)
		seat.setup(SEAT_COLORS[i], i == 0)
		_seats.append(seat)


func _process(delta: float) -> void:
	for i in _seats.size():
		_seats[i].apply(0.25 * float(i), true, delta)
	_frame += 1
	if _frame == 40:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://shots/v3-bomb-arena.png")
		print("截图已存 shots/v3-bomb-arena.png")
