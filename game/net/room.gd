class_name NetRoom
extends RefCounted

## 一局的骨架：座位表、时钟、规则模型。服务器只跑这里的 RefCounted 东西，绝不实例化 3D 场景。
## 座位秩序沿用全项目的规矩：真人占 0..n-1（本地优先，由调用方排好），人机从 n 往后补。

## 四款小游戏，和 game/minigame/ 下的场景一一对应
const KINDS: Array[String] = ["classroom", "bomb", "owl", "race"]

var kind := ""
## 长度恒为 Config.SEAT_COUNT，每格 {account: String, npc: bool}；人机格 account 为空
var seats: Array[Dictionary] = []
## 规则模型（StealEat / BombRound / OwlRound / RaceField），房间只负责推它和拍快照
var model: RefCounted = null
var elapsed := 0.0
var over := false
var winner := -1

## 每号座位这一 tick 收到的输入；客户端只说「我按着」，规则在这里算
var _inputs: Array[Dictionary] = []


## 人数超员、账号重复、kind 不认识都返回 null：调用方记日志拒掉，不要「尽量建」。
static func create(kind_value: String, humans: Array[String]) -> NetRoom:
	if not KINDS.has(kind_value) or humans.is_empty() or humans.size() > Config.SEAT_COUNT:
		return null
	var seen := {}
	for h in humans:
		if h.is_empty() or seen.has(h):
			return null
		seen[h] = true
	var room := NetRoom.new()
	room.kind = kind_value
	for i in Config.SEAT_COUNT:
		var human := i < humans.size()
		room.seats.append({"account": humans[i] if human else "", "npc": not human})
		room._inputs.append({})
	return room


func seat_of(account: String) -> int:
	for i in seats.size():
		if not seats[i]["npc"] and seats[i]["account"] == account:
			return i
	return -1


## 输入只认本局的人，外人返回 false 让调用方记日志。过期的输入（已结束）直接丢。
func input(account: String, payload: Dictionary) -> bool:
	var seat := seat_of(account)
	if over or seat < 0:
		return false
	_inputs[seat] = payload
	return true


func tick(delta: float) -> void:
	if over:
		return
	elapsed += maxf(delta, 0.0)


func snapshot() -> Dictionary:
	return {
		"kind": kind,
		"seats": seats.duplicate(true),
		"elapsed": elapsed,
		"over": over,
		"winner": winner,
	}
