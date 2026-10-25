class_name NetOps

## 服务器端的 op 结算：客户端只说「我要干什么」，服务器在这份账号存档上算完再回。
## 规则一律调 Day / Gacha / 目录校验的既有函数，这里只做字典搬运和入参校验。
##
## 入参来自网络，全是信任边界：类型不对、越界、名单外的 op 一律拒，绝不当成 0 处理。

## 客户端能发起的 op。
## shortcut: 一期允许 add_coins，因为四款小游戏还在客户端跑（结算得有个去处）。
## 二期小游戏搬到服务器之后必须把它从这里删掉，否则谁都能自己加币。
const CLIENT_OPS: Array[String] = [
	"pull", "meal", "spend_stamina", "equip", "set_character", "add_coins", "patch_day_time", "sleep",
]

## 一期客户端上报的单次收益上限：最大的赛跑冠军是 70 币，留一倍余量
const MAX_REPORTED_COINS := 200


static func allowed(op: String) -> bool:
	return CLIENT_OPS.has(op)


## 返回 {ok, data, result, error}。data 是新的一份存档（不原地改调用方的字典）。
static func apply(data: Dictionary, op: String, args: Dictionary) -> Dictionary:
	if not allowed(op):
		return {"ok": false, "data": data, "error": "op"}
	var save := Save.normalize(data)
	match op:
		"pull":
			return _pull(save, args)
		"meal":
			return _meal(save)
		"spend_stamina":
			return _spend_stamina(save, args)
		"equip":
			return _equip(save, args)
		"set_character":
			return _set_character(save, args)
		"add_coins":
			return _add_coins(save, args)
		"patch_day_time":
			return _patch_day_time(save, args)
		"sleep":
			return _sleep(save)
	return {"ok": false, "data": save, "error": "op"}


## 抽卡：一抽 50、十连 450。十连只在第一抽上扣钱，和 Gacha.pull_ten 一个规矩。
static func _pull(save: Dictionary, args: Dictionary) -> Dictionary:
	var count := int(args.get("n", 0))
	if count != 1 and count != 10:
		return {"ok": false, "data": save, "error": "args"}
	if count == 1 and not Gacha.can_pull_one(save):
		return {"ok": false, "data": save, "error": "coins"}
	if count == 10 and not Gacha.can_pull_ten(save):
		return {"ok": false, "data": save, "error": "coins"}
	var results: Array[Dictionary] = []
	var full := Config.GACHA_PRICE_TEN if count == 10 else Config.GACHA_PRICE_ONE
	for i in count:
		results.append(Gacha.roll(save, full if i == 0 else 0))
	return {"ok": true, "data": save, "result": {"pulls": results}}


static func _meal(save: Dictionary) -> Dictionary:
	var r := Day.meal(int(save["stamina"]), int(save["meals"]), int(save["coins"]))
	if not bool(r["ok"]):
		return {"ok": false, "data": save, "error": "meal"}
	save["stamina"] = int(r["stamina"])
	save["meals"] = int(r["meals"])
	save["coins"] = int(r["coins"])
	return {"ok": true, "data": save}


static func _spend_stamina(save: Dictionary, args: Dictionary) -> Dictionary:
	var cost := int(args.get("cost", 0))
	if cost <= 0 or cost > Config.STAMINA_MAX:
		return {"ok": false, "data": save, "error": "args"}
	var r := Day.spend_cost(int(save["stamina"]), cost)
	if not bool(r["ok"]):
		return {"ok": false, "data": save, "error": "stamina"}
	save["stamina"] = int(r["stamina"])
	return {"ok": true, "data": save}


static func _equip(save: Dictionary, args: Dictionary) -> Dictionary:
	var skin_id := str(args.get("skin", ""))
	if skin_id != "" and not (save["owned"] as PackedStringArray).has(skin_id):
		return {"ok": false, "data": save, "error": "owned"}
	if skin_id != "" and SkinCatalog.by_id(skin_id) == null:
		return {"ok": false, "data": save, "error": "skin"}
	save["equipped"] = skin_id
	return {"ok": true, "data": save}


static func _set_character(save: Dictionary, args: Dictionary) -> Dictionary:
	var id := str(args.get("id", ""))
	if not BodyCatalog.BODIES.has(id):
		return {"ok": false, "data": save, "error": "body"}
	save["character"] = id
	return {"ok": true, "data": save}


static func _add_coins(save: Dictionary, args: Dictionary) -> Dictionary:
	var amount := int(args.get("amount", 0))
	if amount < 0 or amount > MAX_REPORTED_COINS:
		return {"ok": false, "data": save, "error": "args"}
	save["coins"] = maxi(0, int(save["coins"]) + amount)
	return {"ok": true, "data": save}


## 天色只前进不后退（和 Day.advance_time 一个规矩），联机时这条是客户端唯一能碰的场面状态。
static func _patch_day_time(save: Dictionary, args: Dictionary) -> Dictionary:
	var t := float(args.get("t", -1.0))
	if t < Config.MORNING_TIME or t > Config.DAYTIME_MAX_T + 0.2:
		return {"ok": false, "data": save, "error": "args"}
	save["day_time"] = maxf(float(save["day_time"]), t)
	return {"ok": true, "data": save}


## shortcut: 一期没有世界时钟，睡觉还能随时睡（跟单机一样）。
## 三期接上世界时钟后要加「一天一次」，否则体力门槛失效。
static func _sleep(save: Dictionary) -> Dictionary:
	var r := Day.rollover(int(save["day"]))
	save["stamina"] = int(r["stamina"])
	save["meals"] = int(r["meals"])
	save["day"] = int(r["day"])
	save["day_time"] = float(r["day_time"])
	return {"ok": true, "data": save}
