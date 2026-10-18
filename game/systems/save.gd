class_name Save

## 本地存档：币、皮肤、体力、今天的份数与天数、天色水位。user://save.cfg 一个 [game] 段。

const PATH := "user://save.cfg"
const SECTION := "game"


static func read(path: String = PATH) -> Dictionary:
	var cfg := ConfigFile.new()
	cfg.load(path)
	return {
		"coins": int(cfg.get_value(SECTION, "coins", 0)),
		"owned": bool(cfg.get_value(SECTION, "owned", false)),
		"equipped": bool(cfg.get_value(SECTION, "equipped", false)),
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


## 穿戴状态：已拥有才能换。摊位和帐篷都走这里，不各写一遍。
static func equip(blueberry: bool, path: String = PATH) -> bool:
	var data := read(path)
	if not bool(data["owned"]):
		return false
	write(path, {"equipped": blueberry})
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
