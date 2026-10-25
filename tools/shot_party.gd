extends SceneTree

## 一次性看同屏双人的效果：让二号位加入，进森林跑一小会儿，截一张两人同框的图。
## 用法：godot --path . --script res://tools/shot_party.gd
## 输出：shots/party.png

const FRAMES := 150


func _initialize() -> void:
	Party.join("seafood", "")
	change_scene_to_file("res://game/main.tscn")


func _process(_delta: float) -> bool:
	if Engine.get_process_frames() < FRAMES:
		return false
	for node in root.get_tree().get_nodes_in_group("player"):
		var player := node as Player
		print("%s 座位 %d 位置 %s 跟随 %s" % [
			player.name, player.seat, str(player.global_position), str(player.is_follower())
		])
	root.get_texture().get_image().save_png("res://shots/party.png")
	print("saved party")
	return true
