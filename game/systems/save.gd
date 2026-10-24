class_name Save

## 本地存档：币、已拥有的皮肤、穿着的皮肤、保底计数、体力、今天的份数与天数、天色水位。
## user://save.cfg 一个 [game] 段。

const PATH := "user://save.cfg"
const SECTION := "game"


static func read(path: String = PATH) -> Dictionary:
	var cfg := ConfigFile.new()
	cfg.load(path)
	# v3 存档里 owned/equipped 是布尔键：直接赋给 PackedStringArray 会报错，
	# str(true) 又得到 "true" 而不是 "blueberry"，所以按类型分支
	var owned := PackedStringArray()
	var raw_owned = cfg.get_value(SECTION, "owned", PackedStringArray())
	if typeof(raw_owned) == TYPE_PACKED_STRING_ARRAY:
		owned = raw_owned
	elif typeof(raw_owned) == TYPE_BOOL and bool(raw_owned):
		owned = PackedStringArray(["blueberry"])
	var equipped := ""
	var raw_equipped = cfg.get_value(SECTION, "equipped", "")
	if typeof(raw_equipped) == TYPE_STRING:
		equipped = raw_equipped
	elif typeof(raw_equipped) == TYPE_BOOL and bool(raw_equipped):
		equipped = "blueberry"
	return {
		"coins": int(cfg.get_value(SECTION, "coins", 0)),
		"owned": owned,
		"equipped": equipped,
		"pity": int(cfg.get_value(SECTION, "pity", 0)),
		"stamina": int(cfg.get_value(SECTION, "stamina", Config.STAMINA_MAX)),
		"meals": int(cfg.get_value(SECTION, "meals", 0)),
		"day": int(cfg.get_value(SECTION, "day", 1)),
		"day_time": float(cfg.get_value(SECTION, "day_time", Config.MORNING_TIME)),
	}


## 只改传入的键：先 load 再 set，别让买皮肤顺手把体力和天色抹回缺省。
static func write(path: String, data: Dictionary) -> void:
	var cfg := ConfigFile.new()
	cfg.load(path)
	for key in data:
		cfg.set_value(SECTION, key, data[key])
	cfg.save(path)


static func add_coins(amount: int, path: String = PATH) -> int:
	var data := read(path)
	var coins := maxi(0, int(data["coins"]) + amount)
	data["coins"] = coins
	write(path, data)
	return coins


static func apply_round(bites: int, is_winner: bool, caught: int, path: String = PATH) -> Dictionary:
	var earned := StealEat.coins(bites, is_winner, caught)
	return {"earned": earned, "coins": add_coins(earned, path)}


## 穿戴状态：`""` 是默认红帽，非空必须是已拥有的 id。摊位和帐篷都走这里，不各写一遍。
static func equip(skin_id: String, path: String = PATH) -> bool:
	var data := read(path)
	if skin_id != "" and not (data["owned"] as PackedStringArray).has(skin_id):
		return false
	write(path, {"equipped": skin_id})
	return true


## 扣一局体力：够才扣（三款小游戏的 _ready 都走这里）。
static func spend_stamina(cost: int, path: String = PATH) -> bool:
	var data := read(path)
	var r := Day.spend_cost(int(data["stamina"]), cost)
	if not bool(r["ok"]):
		return false
	write(path, {"stamina": int(r["stamina"])})
	return true


static func eat_meal(path: String = PATH) -> bool:
	var data := read(path)
	var r := Day.meal(int(data["stamina"]), int(data["meals"]), int(data["coins"]))
	if not bool(r["ok"]):
		return false
	write(path, {
		"stamina": int(r["stamina"]), "meals": int(r["meals"]), "coins": int(r["coins"])
	})
	return true


static func rollover(path: String = PATH) -> void:
	var data := read(path)
	write(path, Day.rollover(int(data["day"])))


static func set_day_time(t: float, path: String = PATH) -> void:
	write(path, {"day_time": t})
