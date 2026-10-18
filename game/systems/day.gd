class_name Day

## 体力与天色的唯一一套公式：别处不许再算天色，扣体力只在小游戏 _ready 一处。
## 全部静态、不碰节点、不碰文件。


## 满体力 = 清晨，体力见底 = 天黑。
static func day_time(stamina: int) -> float:
	var left := 1.0 - clampf(float(stamina) / float(Config.STAMINA_MAX), 0.0, 1.0)
	return lerpf(Config.MORNING_TIME, Config.DAYTIME_MAX_T, left)


## 天色只前进不后退：吃完饭回体力，太阳不会倒回上午。
static func advance_time(saved_t: float, stamina: int) -> float:
	return maxf(saved_t, day_time(stamina))


static func can_play(stamina: int, cost: int) -> bool:
	return stamina >= cost


static func spend_cost(stamina: int, cost: int) -> Dictionary:
	if not can_play(stamina, cost):
		return {"ok": false, "stamina": stamina}
	return {"ok": true, "stamina": stamina - cost}


static func entry_label(stamina: int, cost: int) -> String:
	if not can_play(stamina, cost):
		return "太累了，明天再来"
	return "体力 −%d · 剩 %d" % [cost, stamina - cost]


## 拒绝顺序：份数用完 → 钱不够 → 还饱着 → 打烊（体力见底）。拒绝时原样返回。
static func meal(stamina: int, meals: int, coins: int) -> Dictionary:
	var no := {"ok": false, "stamina": stamina, "meals": meals, "coins": coins}
	if meals >= Config.MEALS_PER_DAY:
		return no
	if coins < Config.MEAL_COINS:
		return no
	if stamina >= Config.STAMINA_MAX:
		return no
	if stamina < Config.STAMINA_MIN_COST:
		return no
	return {
		"ok": true,
		"stamina": mini(Config.STAMINA_MAX, stamina + Config.MEAL_STAMINA),
		"meals": meals + 1,
		"coins": coins - Config.MEAL_COINS,
	}


static func rollover(day: int) -> Dictionary:
	return {
		"stamina": Config.STAMINA_MAX,
		"meals": 0,
		"day": day + 1,
		"day_time": Config.MORNING_TIME,
	}


static func exhausted(stamina: int) -> bool:
	return stamina < Config.STAMINA_MIN_COST
