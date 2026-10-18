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


static func coins(rank: int, hits: int) -> int:
	var base: int = Config.RACE_RANK_COINS[clampi(rank, 0, Config.RACE_RANK_COINS.size() - 1)]
	return maxi(0, base - Config.RACE_HIT_PENALTY * hits)
