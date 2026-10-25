extends Node3D

## 森林（主场景）：同屏双人的二号位在这里生灭，别的地方都不管。
## 返回键维持「直接退出游戏」的老行为（赛跑场景自己处理返回键，所以全局关掉了 quit_on_go_back）。

const PLAYER_SCENE := "res://game/player/mushroom.tscn"

var _second: Player = null

@onready var _join_panel: JoinPanel = $JoinPanel
@onready var _forest: Node3D = $Forest


func _ready() -> void:
	_join_panel.join_pressed.connect(_on_join)
	_join_panel.leave_pressed.connect(_on_leave)
	_spawn_second()


func _on_join(body_id: String, skin_id: String) -> void:
	Party.join(body_id, skin_id)
	_spawn_second()


func _on_leave() -> void:
	Party.leave()
	if _second != null:
		_second.queue_free()
		_second = null


## 从任何小游戏回森林时也走这里：Party 还记着二号位，就把他重建出来。
func _spawn_second() -> void:
	if _second != null or not Party.joined():
		return
	var first := get_tree().get_first_node_in_group("player") as Player
	if first == null:
		return
	var second := load(PLAYER_SCENE).instantiate() as Player
	second.name = "Player2"
	second.seat = 1
	# leader 必须在 add_child 之前给：_ready 里靠它决定要不要造相机
	second.leader = first
	# 位置也必须先摆好再入树：先入树会在原点登记碰撞体，第一帧和一号位重叠，
	# 两台一起被顶开 —— 一号位会被顶到二号位头上，然后被一路推着走
	second.position = Player.follow_point(
		first.global_position, first.global_basis,
		Config.PARTY_FOLLOW_GAP, Config.PARTY_FOLLOW_SIDE
	)
	_forest.add_child(second)
	_second = second


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		get_tree().quit()
