class_name Save

## 本地存档：币、已拥有的皮肤、穿着的皮肤、保底计数、体力、今天的份数与天数、天色水位。
## user://save.cfg 一个 [game] 段。

const PATH := "user://save.cfg"
const SECTION := "game"

## 非空 = 联机模式：存档在服务器上，本机只是镜像（见 game/net/client.gd）。
static var remote: Node = null


static func online() -> bool:
	return remote != null


## 一份崭新存档的全部字段。服务器上的账号记录也用这一份，别在两处各写一遍缺省值。
static func defaults() -> Dictionary:
	return {
		"coins": 0,
		"owned": PackedStringArray(),
		"equipped": "",
		"character": BodyCatalog.DEFAULT_ID,
		"pity": 0,
		"stamina": Config.STAMINA_MAX,
		"meals": 0,
		"day": 1,
		"day_time": Config.MORNING_TIME,
	}


## 存档字典的字段类型统一在这里收口：JSON 存一遍再读回来，整数会变成浮点、
## PackedStringArray 会变成 Array，`as PackedStringArray` 直接拿到 null。
static func normalize(raw: Dictionary) -> Dictionary:
	var data := defaults()
	data["coins"] = int(raw.get("coins", 0))
	data["owned"] = PackedStringArray(raw.get("owned", []))
	data["equipped"] = str(raw.get("equipped", ""))
	data["character"] = str(raw.get("character", BodyCatalog.DEFAULT_ID))
	data["pity"] = int(raw.get("pity", 0))
	data["stamina"] = int(raw.get("stamina", Config.STAMINA_MAX))
	data["meals"] = int(raw.get("meals", 0))
	data["day"] = int(raw.get("day", 1))
	data["day_time"] = float(raw.get("day_time", Config.MORNING_TIME))
	return data


static func read(path: String = PATH) -> Dictionary:
	if remote != null:
		return remote.call("mirror")
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
	return Save.normalize({
		"coins": cfg.get_value(SECTION, "coins", 0),
		"owned": owned,
		"equipped": equipped,
		"character": cfg.get_value(SECTION, "character", BodyCatalog.DEFAULT_ID),
		"pity": cfg.get_value(SECTION, "pity", 0),
		"stamina": cfg.get_value(SECTION, "stamina", Config.STAMINA_MAX),
		"meals": cfg.get_value(SECTION, "meals", 0),
		"day": cfg.get_value(SECTION, "day", 1),
		"day_time": float(cfg.get_value(SECTION, "day_time", Config.MORNING_TIME)),
	})


## 只改传入的键：先 load 再 set，别让买皮肤顺手把体力和天色抹回缺省。
## 联机模式下只有天色是本机说了算的（世界时钟到三期才收到服务器上）。
static func write(path: String, data: Dictionary) -> void:
	if remote != null:
		if data.has("day_time"):
			remote.call("push_day_time", float(data["day_time"]))
		return
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


## 换角色：id 必须在 BodyCatalog 里，否则不写盘。
static func set_character(id: String, path: String = PATH) -> bool:
	if not BodyCatalog.BODIES.has(id):
		return false
	write(path, {"character": id})
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
