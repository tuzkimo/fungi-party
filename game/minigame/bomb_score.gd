class_name BombScore
extends RefCounted

## 名次与蘑菇币：名次 = 死亡顺序的倒序，最后活着的第一名。纯静态函数。


## 0 基名次：活着的人第 0，最后死的第 1，最先死的排最后。
static func rank_of(seat: int, death_order: Array, alive: Array) -> int:
	if alive.has(seat):
		return 0
	var index := death_order.find(seat)
	if index < 0:
		return death_order.size()
	return death_order.size() - index


static func coins(rank: int) -> int:
	return int(Config.BOMB_RANK_COINS[clampi(rank, 0, Config.BOMB_RANK_COINS.size() - 1)])


## 结算表：活着的排最前（按 alive 原顺序），然后按死亡顺序倒着列。
static func rows(death_order: Array, alive: Array, names: Array) -> Array:
	var out := []
	for seat in alive:
		out.append({"name": names[seat], "note": "仍在场上"})
	for i in range(death_order.size() - 1, -1, -1):
		out.append({"name": names[death_order[i]], "note": "第 %d 个被炸" % (i + 1)})
	return out
