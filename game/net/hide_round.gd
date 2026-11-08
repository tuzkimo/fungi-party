class_name HideRound
extends RefCounted

## 森林捉迷藏的服务器规则：角色、30 秒藏 / 120 秒找、捉到的距离判定、谁赔谁 5 币。
## 位置由 server_main 从 MOVE 喂进来，同屏 2P 一个账号报两份（slot 0/1），
## 距离一律取「两边所有 slot 两两最小」。不碰节点、不碰存档：写盘在 NetLobby._settle。

const COUNTDOWN := "countdown"
const SEEKING := "seeking"
const OVER := "over"

var phase := COUNTDOWN
var seeker_seat := 0
var hider_seat := 1
var left := 0.0
## 藏的人一旦进过 HIDE_REVEAL 就锁存：找的人之后一直看得见（不会追两步又跟丢）
var revealed := false
var caught := false
var over := false
var winner := -1

## 座位 → {slot: Vector3}
var _pos := {}


func _init() -> void:
	left = Config.HIDE_COUNTDOWN


## 谁藏谁找：接受邀请那个人选的（NetLobby.answer 的 role）。
func assign(hider: int, seeker: int) -> void:
	hider_seat = hider
	seeker_seat = seeker


## 位置也是信任边界：槽位越界、非有限数都不采信。
func feed(seat: int, slot: int, spot: Vector3) -> void:
	if slot < 0 or slot > 1 or not spot.is_finite():
		return
	if not _pos.has(seat):
		_pos[seat] = {}
	(_pos[seat] as Dictionary)[slot] = spot


func tick(delta: float) -> void:
	if over:
		return
	left -= maxf(delta, 0.0)
	if phase == COUNTDOWN and left <= 0.0:
		phase = SEEKING
		left = Config.HIDE_SEEK_SECONDS
	elif phase == SEEKING and left <= 0.0:
		left = 0.0
		phase = OVER
		over = true
		winner = hider_seat
		return
	if not revealed and reveal_ok(_slots(seeker_seat), _slots(hider_seat)):
		revealed = true


func can_catch() -> bool:
	if phase != SEEKING:
		return false
	return nearest_distance(_slots(seeker_seat), _slots(hider_seat)) <= Config.HIDE_CATCH


func catch(seat: int) -> bool:
	if over or seat != seeker_seat or not can_catch():
		return false
	over = true
	winner = seat
	caught = true
	return true


## 按「放弃」的人判负，对方赢，照常结账（自己认的就得付）。
func forfeit(seat: int) -> bool:
	if over or (seat != seeker_seat and seat != hider_seat):
		return false
	winner = hider_seat if seat == seeker_seat else seeker_seat
	over = true
	return true


func coins_for(seat: int) -> int:
	if not over or (seat != seeker_seat and seat != hider_seat):
		return 0
	return Config.HIDE_STAKE if seat == winner else -Config.HIDE_STAKE


func snapshot() -> Dictionary:
	return {
		"phase": phase,
		"left": left,
		"seeker": seeker_seat,
		"hider": hider_seat,
		"caught": caught,
		"revealed": revealed,
		"can_catch": can_catch(),
		"over": over,
		"winner": winner,
	}


func _slots(seat: int) -> Array:
	var found: Variant = _pos.get(seat, null)
	if found == null:
		return []
	return (found as Dictionary).values()


static func flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))


## 两边所有 slot 的两两最小距离；任一边没坐标就是 INF（判不了就别判）。
static func nearest_distance(a: Array, b: Array) -> float:
	var best := INF
	for pa in a:
		var va: Vector3 = pa
		for pb in b:
			var vb: Vector3 = pb
			best = minf(best, flat_distance(va, vb))
	return best


static func reveal_ok(seeker: Array, hider: Array) -> bool:
	return nearest_distance(seeker, hider) <= Config.HIDE_REVEAL


## 一个账号在世界快照里占两份：本人 + 同屏 2P。
static func hide_keys(account: String) -> Array[String]:
	var out: Array[String] = []
	if account == "":
		return out
	out.append(account)
	out.append("%s|1" % account)
	return out
