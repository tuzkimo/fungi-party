class_name RaceScore
extends RefCounted

## 名次与蘑菇币：纯静态函数，玩家和人机混着传都行（字典或带同名字段的对象）。

## 已冲线的按时间排，没冲线的按进度排；完全并列时下标小的在前。
static func ranking(racers: Array) -> Array:
	var order: Array = []
	for i in racers.size():
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool:
		var ra: Variant = racers[a]
		var rb: Variant = racers[b]
		if bool(ra["finished"]) != bool(rb["finished"]):
			return bool(ra["finished"])
		if bool(ra["finished"]):
			var ta := float(ra["finish_time"])
			var tb := float(rb["finish_time"])
			if not is_equal_approx(ta, tb):
				return ta < tb
		else:
			var za := float(ra["z"])
			var zb := float(rb["z"])
			if not is_equal_approx(za, zb):
				return za > zb
		return a < b
	)
	return order


## 前 top 名的名次定死了就不用再等：剩下的人谁先到都挤不进前三。
## 四人赛时「三个冲线」、五人赛时「三个冲线」都成立，所以按 size - top 算。
static func decided(racers: Array, top := 3) -> bool:
	var unfinished := 0
	for racer in racers:
		if not bool(racer["finished"]):
			unfinished += 1
	return unfinished <= maxi(racers.size() - top, 0)


static func coins(rank: int, hits: int) -> int:
	var base: int = Config.RACE_RANK_COINS[clampi(rank, 0, Config.RACE_RANK_COINS.size() - 1)]
	return maxi(0, base - Config.RACE_HIT_PENALTY * hits)
