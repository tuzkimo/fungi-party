class_name Save

## 本地存档：只有三个字段（币、是否拥有皮肤、是否穿戴）。user://save.cfg 一个 [game] 段。

const PATH := "user://save.cfg"
const SECTION := "game"


static func read(path: String = PATH) -> Dictionary:
	var cfg := ConfigFile.new()
	cfg.load(path)
	return {
		"coins": int(cfg.get_value(SECTION, "coins", 0)),
		"owned": bool(cfg.get_value(SECTION, "owned", false)),
		"equipped": bool(cfg.get_value(SECTION, "equipped", false)),
	}


static func write(path: String, data: Dictionary) -> void:
	var cfg := ConfigFile.new()
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
