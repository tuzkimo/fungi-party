extends SceneTree

## 无头过一遍四款小游戏的「双人」分支：每个场景跑 N 帧再切下一个。
## 只要 stdout / stderr 里没有 ERROR、并且真的停在目标场景上（没被体力不够踢回森林）就算过。
## 时间加速 10 倍，一局能跑到结算面板（结算才是一堆数组下标和 UI 签名真正汇合的地方）。
## 用法：godot --headless --path . --script res://tools/soak_party.gd

const SCENES: Array[String] = [
	"res://game/minigame/classroom.tscn",
	"res://game/minigame/owl.tscn",
	"res://game/minigame/bomb.tscn",
	"res://game/minigame/race.tscn",
]
const FRAMES := 1800

var _index := -1
var _frames := 0
var _failures := 0


func _initialize() -> void:
	Engine.time_scale = 10.0
	Party.join("seafood", "hero")
	print("双人浸泡：%d 人上场" % Party.count())
	_advance()


func _advance() -> void:
	_check()
	_index += 1
	_frames = 0
	if _index >= SCENES.size():
		print("双人浸泡：四个场景都过了一遍，失败 %d" % _failures)
		quit(1 if _failures > 0 else 0)
		return
	# 每个场景都会扣一次体力：先补满，否则一局都开不起来就被踢回森林
	Save.write(Save.PATH, {"stamina": Config.STAMINA_MAX})
	change_scene_to_file(SCENES[_index])


## 跑够帧数后确认场上还是那个场景 —— 被踢回森林就说明脚本没跑起来。
func _check() -> void:
	if _index < 0:
		return
	var current := current_scene.scene_file_path if current_scene != null else ""
	if current != SCENES[_index]:
		printerr("FAIL: %s 没停在场上，当前是 %s" % [SCENES[_index], current])
		_failures += 1
	else:
		print("  %s 跑完 %d 帧" % [SCENES[_index], FRAMES])


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < FRAMES:
		return false
	_advance()
	return false
