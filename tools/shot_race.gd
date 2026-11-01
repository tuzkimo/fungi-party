extends SceneTree

## 一次性看效果的工具：进赛跑跑一会儿，截几张图（倒数、跑动、结算面板）。
## 用法：godot --path . --script res://tools/shot_race.gd
## 输出：shots/race_start.png / race_run.png / race_result.png（读的是当前存档里的角色和皮肤）

const STEER_FROM := 200
const STEER_TO := 320
const RUN_SHOT := 420
## 人机 40 秒上下跑完，前三名定了就收局（本机不推摇杆会卡在墙上，正好验结算面板）。
## 跑动那张截完就开时间加速，免得等真时间五十秒。
const RESULT_SHOT := 1900

var _frames := 0


func _initialize() -> void:
	Controls.ensure()
	# 只补体力，别的存档字段照旧
	var data := Save.read()
	data["stamina"] = Config.STAMINA_MAX
	Save.write(Save.PATH, data)
	change_scene_to_file(Config.RACE_PATH)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 60:
		_shot("race_start")
	if _frames > STEER_FROM and _frames < STEER_TO:
		Input.action_press("move_left")
	else:
		Input.action_release("move_left")
	if _frames == RUN_SHOT:
		_shot("race_run")
		Engine.time_scale = 8.0
	if _frames < RESULT_SHOT:
		return false
	_shot("race_result")
	print("settled=%s" % str(current_scene.get("_settled")))
	return true


func _shot(name: String) -> void:
	root.get_texture().get_image().save_png("res://shots/%s.png" % name)
	print("saved %s" % name)
