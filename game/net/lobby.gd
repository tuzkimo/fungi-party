class_name NetLobby
extends RefCounted

## 邀请配对 + 「同时只开一间房」的规矩。
## 服务器侧纯逻辑：存档由调用方注入读写（服务器给 Accounts，测试给字典），这里不碰文件、不碰节点。
##
## 体力规矩是「谁玩谁付自己的」：邀请时只查发起人的，接受时再查双方的，成局那一下才各扣一次；
## 拒绝、过期、中途离开一分不扣。

## 已经搬上服务器的几款：只有这些能开局。其余几款还在客户端跑单机逻辑，
## 邀进去等于扣两次体力、还白占着「同时 1 房」。每搬完一款往这里加一条。
const MODELLED: Array[String] = ["classroom", "bomb", "owl", "race"]

## kind → 开局体力。和 NetRoom.KINDS 一一对应。
const COSTS := {
	"classroom": Config.STAMINA_COST_CLASSROOM,
	"bomb": Config.STAMINA_COST_BOMB,
	"owl": Config.STAMINA_COST_OWL,
	"race": Config.STAMINA_COST_RACE,
}

## 被邀请人账号 → {from, kind, at}。同一时刻只留最新的一条，重发即覆盖。
var pending := {}
## 同时只开一间：二期这台机器只够森林 + 1 房
var room: NetRoom = null

## 这一局结过账了没有：一次结束只结算一次
var settled := false

var _read: Callable   # (name: String) -> Dictionary
var _write: Callable  # (name: String, data: Dictionary) -> void


func _init(read_save: Callable, write_save: Callable) -> void:
	_read = read_save
	_write = write_save


static func cost_of(kind: String) -> int:
	return int(COSTS.get(kind, 0))


## 发邀请：只查不动账。返回 {ok, error}。
func invite(from: String, to: String, kind: String, online: PackedStringArray, now: float) -> Dictionary:
	if not MODELLED.has(kind):
		return {"ok": false, "error": "kind"}
	if to == from:
		return {"ok": false, "error": "self"}
	if not online.has(to):
		return {"ok": false, "error": "offline"}
	if room != null:
		return {"ok": false, "error": "busy"}
	if not Day.can_play(_stamina(from), cost_of(kind)):
		return {"ok": false, "error": "stamina"}
	pending[to] = {"from": from, "kind": kind, "at": now}
	return {"ok": true}


## 回答邀请。接受时两人各扣一次体力并成局，返回 {ok, error, result, room, saves}。
## saves 是两边的新存档：调用方要落盘，并把各自的发给各自（被邀请人那份也会随 op 回执走）。
func answer(from: String, to: String, kind: String, accept: bool, online: PackedStringArray, now: float) -> Dictionary:
	var found: Variant = pending.get(to, null)
	if found == null:
		return {"ok": false, "error": "invite"}
	var invitation: Dictionary = found
	if str(invitation["from"]) != from or str(invitation["kind"]) != kind:
		return {"ok": false, "error": "invite"}
	pending.erase(to)
	if now - float(invitation["at"]) > Config.NET_INVITE_SECONDS:
		return {"ok": false, "error": "expired"}
	if not accept:
		return {"ok": true, "result": {"accepted": false}}
	if room != null:
		return {"ok": false, "error": "busy"}
	if not online.has(from):
		return {"ok": false, "error": "offline"}
	var cost := cost_of(kind)
	var mine := Day.spend_cost(_stamina(to), cost)
	var theirs := Day.spend_cost(_stamina(from), cost)
	if not bool(mine["ok"]) or not bool(theirs["ok"]):
		return {"ok": false, "error": "stamina"}
	room = NetRoom.create(kind, [from, to], randi())
	if room == null:
		return {"ok": false, "error": "room"}
	settled = false
	_clear_invites(from)
	_clear_invites(to)
	var saves := {}
	saves[to] = _charged(to, int(mine["stamina"]))
	saves[from] = _charged(from, int(theirs["stamina"]))
	return {"ok": true, "result": {"accepted": true}, "room": room, "saves": saves}


## 下发给某个人的待处理邀请（WORLD 里那一格）。顺手把过期和发起人已掉线的清掉。
func invites_for(name: String, online: PackedStringArray, now: float) -> Array:
	if room != null:
		return []
	var out := []
	for to in pending.keys():
		if str(to) != name:
			continue
		var invitation: Dictionary = pending[to]
		if now - float(invitation["at"]) > Config.NET_INVITE_SECONDS or not online.has(str(invitation["from"])):
			pending.erase(to)
			continue
		out.append({"from": str(invitation["from"]), "kind": str(invitation["kind"])})
	return out


## 这个人下线或者主动回森林：他发出和收到的邀请都作废；他在局里就把这一局收了。
## settle = false 是「主动走」：炸弹按名次结账，两人还都活着时退出等于白拿第一名的币，所以一分不给。
func leave(name: String, settle: bool = true) -> void:
	_clear_invites(name)
	if room != null and room.seat_of(name) >= 0:
		room.over = true
		if not settle:
			settled = true


## 掉线（不是主动走）：别人还在这一局里就让他那格空着打完，一个不剩了才收局结账。
## 一个人手机掉网不能把另一个人的一局瞬间结算掉 —— 真机上就是这么丢了整局。
func drop(name: String, online: PackedStringArray) -> void:
	_clear_invites(name)
	if room == null or room.seat_of(name) < 0:
		return
	for seat in room.seats:
		if not bool(seat["npc"]) and online.has(str(seat["account"])):
			return
	leave(name, true)


## 推进这一局；模型说结束（或者到了硬顶）就结账，只结一次。
func tick(delta: float) -> void:
	if room == null:
		return
	room.tick(delta)
	if room.elapsed >= Config.NET_ROOM_MAX_SECONDS:
		room.over = true
	if room.over and not settled:
		_settle()


## 按各人的口数把币写进存档（规则在 NetRoom.payouts / 模型里，这里只搬）。
func _settle() -> void:
	settled = true
	# 刚开局就被收掉的局不结账：否则「邀请 → 立刻走人」能白刷底薪那几币
	if room.elapsed < Config.NET_SETTLE_MIN_SECONDS:
		return
	var payouts := room.payouts()
	for name in payouts:
		var save := (_read.call(str(name)) as Dictionary).duplicate(true)
		save["coins"] = int(save.get("coins", 0)) + int(payouts[name])
		_write.call(str(name), save)
	# 写完了才算「结了账」：快照里的收益和存档里的币必须是同一份
	room.paid = true


func _clear_invites(name: String) -> void:
	pending.erase(name)
	for to in pending.keys():
		if str((pending[to] as Dictionary)["from"]) == name:
			pending.erase(to)


func _stamina(name: String) -> int:
	return int((_read.call(name) as Dictionary).get("stamina", 0))


func _charged(name: String, stamina: int) -> Dictionary:
	var save := (_read.call(name) as Dictionary).duplicate(true)
	save["stamina"] = stamina
	return save
