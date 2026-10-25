class_name BodyCatalog

## 角色体型总表。用显式路径而不是扫目录：DirAccess 对导出的 res:// 不可靠，且顺序要稳定。
## 加一个角色 = 加一个 body/body_xxx.gd + 这里一条。

const DEFAULT_ID := "red"

const BODIES := {
	"red": {"name": "红蘑菇", "path": "res://game/player/body/body_red.gd"},
	"seafood": {"name": "海鲜菇", "path": "res://game/player/body/body_seafood.gd"},
}


static func ids() -> Array[String]:
	var result: Array[String] = []
	for id in BODIES:
		result.append(str(id))
	return result


static func display_name(id: String) -> String:
	return str(BODIES[normalize(id)]["name"])


## 存档里可能写着已经删掉的角色 id：查不到就回落默认，不能崩。
static func normalize(id: String) -> String:
	return id if BODIES.has(id) else DEFAULT_ID


static func create(id: String) -> MushroomBody:
	var key := normalize(id)
	var script := load(str(BODIES[key]["path"])) as GDScript
	if script == null:
		push_error("体型加载失败：%s" % str(BODIES[key]["path"]))
		return BodyRed.new()
	return script.new() as MushroomBody
