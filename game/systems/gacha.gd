class_name Gacha

## 抽卡规则，全是纯函数 + 一次落盘，方便无头测试。
## 币、已拥有、穿戴、保底计数一起写：不会出现扣了钱没发卡。

static var _rng: RandomNumberGenerator


static func rng() -> RandomNumberGenerator:
	if _rng == null:
		_rng = RandomNumberGenerator.new()
		_rng.randomize()
	return _rng


## 保底：`pity` 是「已连续没出夯的抽数」。已经连着满了 50 抽就强制出夯，返回 0~4。
static func pick_rarity(generator: RandomNumberGenerator, pity: int) -> int:
	if pity >= Config.GACHA_PITY - 1:
		return 4
	var roll := generator.randi_range(1, 100)
	var acc := 0
	for rarity in Config.GACHA_WEIGHTS.size():
		acc += Config.GACHA_WEIGHTS[rarity]
		if roll <= acc:
			return rarity
	return 0


## 同档内等概率。
static func pick_skin(generator: RandomNumberGenerator, rarity: int) -> MushroomSkin:
	var pool := SkinCatalog.by_rarity(rarity)
	if pool.is_empty():
		pool = SkinCatalog.all()
	return pool[generator.randi_range(0, pool.size() - 1)]


static func can_pull_one(data: Dictionary) -> bool:
	return not _collected(data) and int(data["coins"]) >= Config.GACHA_PRICE_ONE


static func can_pull_ten(data: Dictionary) -> bool:
	return not _collected(data) and int(data["coins"]) >= Config.GACHA_PRICE_TEN


static func pull(path: String = Save.PATH, generator: RandomNumberGenerator = null) -> Dictionary:
	var data := Save.read(path)
	if not can_pull_one(data):
		return {"ok": false, "coins": int(data["coins"])}
	return _roll(path, Config.GACHA_PRICE_ONE, generator)


static func pull_ten(path: String = Save.PATH, generator: RandomNumberGenerator = null) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var data := Save.read(path)
	if not can_pull_ten(data):
		return results
	# 十连的首次一抽把 450 一次扣清，剩下九抽不再计费
	for i in 10:
		results.append(_roll(path, Config.GACHA_PRICE_TEN if i == 0 else 0, generator))
	return results


static func _collected(data: Dictionary) -> bool:
	return (data["owned"] as PackedStringArray).size() >= SkinCatalog.count()


static func _roll(path: String, charge: int, generator: RandomNumberGenerator) -> Dictionary:
	var data := Save.read(path)
	var owned := data["owned"] as PackedStringArray
	var pity := int(data["pity"])
	var g := generator if generator != null else rng()
	var rarity := pick_rarity(g, pity)
	var skin := pick_skin(g, rarity)
	var duplicate := owned.has(skin.id)
	var refund := Config.GACHA_REFUND[rarity] if duplicate else 0
	# 出了夯（重复的也算）就归零，没出就 +1
	pity = 0 if rarity == 4 else pity + 1
	var equipped := str(data["equipped"])
	if not duplicate:
		owned.append(skin.id)
		# 手上还没有皮肤时顺手穿上，有了就不抢玩家挑好的那顶
		if equipped == "":
			equipped = skin.id
	var coins := int(data["coins"]) - charge + refund
	Save.write(path, {"coins": coins, "owned": owned, "equipped": equipped, "pity": pity})
	return {
		"ok": true,
		"id": skin.id,
		"rarity": rarity,
		"duplicate": duplicate,
		"refund": refund,
		"coins": coins,
	}
