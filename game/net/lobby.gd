class_name NetLobby
extends RefCounted

## 邀请配对 + 「同时只开一间房」的规矩。
## 服务器侧纯逻辑：存档由调用方注入读写（服务器给 Accounts，测试给字典），这里不碰文件、不碰节点。
##
## 体力规矩是「谁玩谁付自己的」：邀请时只查发起人的，接受时再查双方的，成局那一下才各扣一次；
## 拒绝、过期、中途离开一分不扣。

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

var _read: Callable  # (name: String) -> Dictionary


func _init(read_save: Callable) -> void:
	_read = read_save


static func cost_of(kind: String) -> int:
	return int(COSTS.get(kind, 0))


## 发邀请：只查不动账。返回 {ok, error}。
func invite(from: String, to: String, kind: String, online: PackedStringArray, now: float) -> Dictionary:
	if not COSTS.has(kind):
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
	room = NetRoom.create(kind, [from, to])
	if room == null:
		return {"ok": false, "error": "room"}
	room.session_seed = randi()
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


## 这个人下线：他发出和收到的邀请都作废；他在局里就把这一局收了。
func drop(name: String) -> void:
	_clear_invites(name)
	if room != null and room.seat_of(name) >= 0:
		room.over = true


## 推进这一局。
## shortcut: 二期还没有结算，只有超过硬顶才收房；第 3 步起由模型自己置 over。
func tick(delta: float) -> void:
	if room == null or room.over:
		return
	room.tick(delta)
	if room.elapsed >= Config.NET_ROOM_MAX_SECONDS:
		room.over = true


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
