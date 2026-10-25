extends SceneTree

## 一次性看效果的工具：进森林跑一小会儿，截一张真机同款视角的图。
## 用法：godot --path . --script res://tools/shot_ingame.gd
## 输出：shots/ingame.png（读的是当前存档里的角色和皮肤）

const FRAMES := 90


func _initialize() -> void:
	change_scene_to_file("res://game/main.tscn")


func _process(_delta: float) -> bool:
	if Engine.get_process_frames() < FRAMES:
		return false
	root.get_texture().get_image().save_png("res://shots/ingame.png")
	print("saved ingame")
	return true
