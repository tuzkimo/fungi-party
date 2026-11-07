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
		"day": 1,
		"day_time": Config.MORNING_TIME,
		# 上次睡觉的 unix 秒（0 = 没做过，立刻能睡）：单机睡觉有冷却，不看世界第几天
		"sleep_at": 0.0,
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
	data["day"] = int(raw.get("day", 1))
	data["day_time"] = float(raw.get("day_time", Config.MORNING_TIME))
	data["sleep_at"] = float(raw.get("sleep_at", 0.0))
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
		"day": cfg.get_value(SECTION, "day", 1),
		"day_time": float(cfg.get_value(SECTION, "day_time", Config.MORNING_TIME)),
		"sleep_at": float(cfg.get_value(SECTION, "sleep_at", 0.0)),
	})


## 只改传入的键：先 load 再 set，别让买皮肤顺手把体力和天色抹回缺省。
## 联机模式下不写盘：所有改动都得走 op（天色也归服务器世界时钟）。
static func write(path: String, data: Dictionary) -> void:
	if remote != null:
		return
	var cfg := ConfigFile.new()
	cfg.load(path)
	for key in data:
		cfg.set_value(SECTION, key, data[key])
	cfg.save(path)


## 联机模式下账本是服务器的：本机只把这一笔报上去，返回值仅是乐观估计。
static func add_coins(amount: int, path: String = PATH) -> int:
	if remote != null:
		remote.call("request", "add_coins", {"amount": amount})
		var mirrored: Dictionary = remote.call("mirror")
		return maxi(0, int(mirrored["coins"]) + amount)
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
	if remote != null:
		remote.call("request", "equip", {"skin": skin_id})
		return true
	write(path, {"equipped": skin_id})
	return true


## 换角色：id 必须在 BodyCatalog 里，否则不写盘。
static func set_character(id: String, path: String = PATH) -> bool:
	if not BodyCatalog.BODIES.has(id):
		return false
	if remote != null:
		remote.call("request", "set_character", {"id": id})
		return true
	write(path, {"character": id})
	return true


## 扣一局体力：够才扣（四款小游戏的 _ready 都走这里）。
## **联机不扣**：一帮朋友里只要有一个人体力见底，那一局就开不起来，所以联网模式随便玩。
static func spend_stamina(cost: int, path: String = PATH) -> bool:
	if remote != null:
		return true
	var data := read(path)
	var r := Day.spend_cost(int(data["stamina"]), cost)
	if not bool(r["ok"]):
		return false
	write(path, {"stamina": int(r["stamina"])})
	return true


## 吃一份：只服务单机 —— 联机不扣体力，也就没东西要补（见 NetLobby 顶上那段）。
static func eat_meal(path: String = PATH) -> bool:
	if remote != null:
		return false
	var data := read(path)
	var r := Day.meal(int(data["stamina"]), int(data["coins"]))
	if not bool(r["ok"]):
		return false
	write(path, {"stamina": int(r["stamina"]), "coins": int(r["coins"])})
	return true


## 睡一觉：只服务单机（联机天色归服务器时钟，体力也不扣）。冷却记在 sleep_at 上。
static func rollover(path: String = PATH) -> void:
	if remote != null:
		return
	var data := read(path)
	if not Day.ready(_now(), float(data["sleep_at"]), Config.SLEEP_COOLDOWN_SECONDS):
		return
	var rolled := Day.rollover(int(data["day"]))
	rolled["sleep_at"] = _now()
	write(path, rolled)


## 下一觉还要等几秒（0 = 现在就能）：帐篷的置灰和睡觉的门槛看同一个数
static func sleep_wait(path: String = PATH) -> float:
	return Day.wait_left(_now(), float(read(path)["sleep_at"]), Config.SLEEP_COOLDOWN_SECONDS)


## 现在几点（unix 秒）：体力恢复只在单机判，本机钟就够了
static func _now() -> float:
	return Time.get_unix_time_from_system()


static func set_day_time(t: float, path: String = PATH) -> void:
	write(path, {"day_time": t})
