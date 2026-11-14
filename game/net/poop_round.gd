class_name PoopRound
extends RefCounted

## 森林扔粑粑的服务器规则：屎壳郎推粪球、抢粪、粑粑直线飞、三次命中、180 秒超时判。
## 位置由 server_main 从 MOVE 喂进来（同屏 2P 一个账号报两份 slot），命中 / 抢粪都按账号记。
## 不碰节点、不碰存档：写盘在 NetLobby._settle。
## 服务器没有 3D：粑粑会穿树，掩体遮挡是已知取舍。

var left := Config.POOP_SECONDS
var over := false
var winner := -1
var humans := 2
## 座位（账号）→ 挨了几下 / 手上几发
var hits := {}
var ammo := {}
## 屎壳郎：{x, z, yaw, ball: bool, timer, refill}；粪球位置从它派生（`ball_at`），不单独存
var beetles: Array[Dictionary] = []
## 飞着的粑粑：{owner, x, y, z, dx, dy, dz, left}
var shots: Array[Dictionary] = []

var _rng := RandomNumberGenerator.new()
## 座位 → {slot: Vector3}
var _pos := {}
var _center := Vector3.ZERO
var _anchored := false


func _init(humans_value := 2, seed_value := 0) -> void:
	humans = clampi(humans_value, 0, Config.SEAT_COUNT)
	for seat in humans:
		hits[seat] = 0
		ammo[seat] = 0
	_rng.seed = seed_value


## 第一个 MOVE 到了才知道屎壳郎撒在哪：只在第一次调用时撒，之后幂等。
func anchor(center: Vector3) -> void:
	if _anchored or not center.is_finite():
		return
	_anchored = true
	_center = center
	for i in Config.POOP_BEETLES:
		var angle := _rng.randf() * TAU
		# sqrt 让点在圆盘里均匀分布，不然全挤在中点
		var radius := sqrt(_rng.randf()) * Config.POOP_SPAWN_RADIUS
		beetles.append({
			"x": center.x + sin(angle) * radius,
			"z": center.z + cos(angle) * radius,
			"yaw": _rng.randf() * TAU,
			"ball": true,
			"timer": Config.POOP_BEETLE_WANDER,
			"refill": 0.0,
		})


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
	var step := maxf(delta, 0.0)
	left -= step
	if left <= 0.0:
		left = 0.0
		over = true
		var loser := loser_by_hits(_hits_array(), humans)
		winner = -1 if loser < 0 else 1 - loser
		return
	_walk_beetles(step)
	_refill_balls(step)
	_pick_balls()
	_fly_shots(step)
	for seat in humans:
		if int(hits[seat]) >= Config.POOP_HITS:
			over = true
			winner = 1 - seat
			return


## 点一下扔：只验弹药和方向，方向是瞄准不是胜负（服务器自己飞、自己判）。
## `slot` 是客户端报的「现在是谁身上的球」（同屏 2P 谁带队就谁扔），没报过位置就退回别的 slot。
func throw_poop(seat: int, dir: Vector3, slot := 0) -> bool:
	if over or seat < 0 or seat >= humans:
		return false
	if int(ammo.get(seat, 0)) <= 0 or not aim_ok(dir):
		return false
	var origin: Variant = _origin(seat, slot)
	if origin == null:
		return false
	ammo[seat] = int(ammo[seat]) - 1
	var d := dir.normalized()
	shots.append({
		"owner": seat,
		"x": (origin as Vector3).x, "y": (origin as Vector3).y, "z": (origin as Vector3).z,
		"dx": d.x, "dy": d.y, "dz": d.z,
		"left": Config.POOP_RANGE / Config.POOP_THROW_SPEED,
	})
	return true


## 按「放弃」的人认输，对方赢，照常结账（自己认的就得付）。
func forfeit(seat: int) -> bool:
	if over or seat < 0 or seat >= humans:
		return false
	winner = 1 - seat
	over = true
	return true


func coins_for(seat: int) -> int:
	if not over or winner < 0 or seat < 0 or seat >= humans:
		return 0
	return Config.POOP_STAKE if seat == winner else -Config.POOP_STAKE


func snapshot() -> Dictionary:
	var hit_list := []
	var ammo_list := []
	for i in Config.SEAT_COUNT:
		hit_list.append(int(hits.get(i, 0)))
		ammo_list.append(int(ammo.get(i, 0)))
	return {
		"left": left,
		"hits": hit_list,
		"ammo": ammo_list,
		"beetles": beetles.duplicate(true),
		"shots": shots.duplicate(true),
		"over": over,
		"winner": winner,
	}


func _walk_beetles(step: float) -> void:
	for b in beetles:
		b["timer"] = float(b["timer"]) - step
		if float(b["timer"]) <= 0.0:
			b["timer"] = Config.POOP_BEETLE_WANDER
			b["yaw"] = _rng.randf() * TAU
		var yaw := float(b["yaw"])
		var x := float(b["x"]) + sin(yaw) * Config.POOP_BEETLE_SPEED * step
		var z := float(b["z"]) + cos(yaw) * Config.POOP_BEETLE_SPEED * step
		b["x"] = x
		b["z"] = z
		# 弹药得留在战场附近：走出去了就掉头
		if Vector2(x - _center.x, z - _center.z).length() > Config.POOP_SPAWN_RADIUS:
			b["yaw"] = atan2(_center.x - x, _center.z - z)


func _refill_balls(step: float) -> void:
	for b in beetles:
		if bool(b["ball"]):
			continue
		b["refill"] = float(b["refill"]) - step
		if float(b["refill"]) <= 0.0:
			b["ball"] = true


## 抢粪：按座位顺序（座位小的先拿），谁有 slot 够得着就归谁；槽满不动球，留给缺的人。
func _pick_balls() -> void:
	for seat in humans:
		for b in beetles:
			if int(ammo[seat]) >= Config.POOP_AMMO_MAX:
				break
			if not bool(b["ball"]):
				continue
			if _nearest_slot(seat, ball_at(b)) > Config.POOP_PICK_RANGE:
				continue
			ammo[seat] = int(ammo[seat]) + 1
			b["ball"] = false
			b["refill"] = Config.POOP_BALL_REFILL


## 每 tick 从旧坐标往新坐标扫一段：一步 0.7 米，点判会从人身上穿过去。
func _fly_shots(step: float) -> void:
	for i in range(shots.size() - 1, -1, -1):
		var shot := shots[i]
		var from := Vector3(float(shot["x"]), float(shot["y"]), float(shot["z"]))
		var to := from + Vector3(float(shot["dx"]), float(shot["dy"]), float(shot["dz"])) * Config.POOP_THROW_SPEED * step
		shot["x"] = to.x
		shot["y"] = to.y
		shot["z"] = to.z
		var owner := int(shot["owner"])
		var struck := -1
		for seat in humans:
			if seat == owner:
				continue
			for chest in _chests(seat):
				if segment_hit(from, to, chest, Config.POOP_HIT_RADIUS):
					struck = seat
					break
			if struck >= 0:
				break
		if struck >= 0:
			hits[struck] = int(hits[struck]) + 1
			shots.remove_at(i)
			continue
		shot["left"] = float(shot["left"]) - step
		if float(shot["left"]) <= 0.0:
			shots.remove_at(i)


## 出手点：客户端报的那个 slot（同屏 2P 谁带队就谁扔），没报过再退回 slot 0 / 1。
func _origin(seat: int, slot := 0) -> Variant:
	var slots: Variant = _pos.get(seat, null)
	if slots == null:
		return null
	for want in [slot, 0, 1]:
		if (slots as Dictionary).has(want):
			return ((slots as Dictionary)[want] as Vector3) + Vector3(0.0, Config.POOP_CHEST, 0.0)
	return null


func _chests(seat: int) -> Array:
	var out := []
	for spot in _slot_values(seat):
		out.append((spot as Vector3) + Vector3(0.0, Config.POOP_CHEST, 0.0))
	return out


func _slot_values(seat: int) -> Array:
	var found: Variant = _pos.get(seat, null)
	if found == null:
		return []
	return (found as Dictionary).values()


## 这个座位有没有哪个 slot 和粪球在同一高度面上够得着（服务器不知道人的朝向）。
func _nearest_slot(seat: int, ball: Vector2) -> float:
	var best := INF
	for spot in _slot_values(seat):
		var v: Vector3 = spot
		best = minf(best, Vector2(v.x, v.z).distance_to(ball))
	return best


func _hits_array() -> Array:
	var out := []
	for seat in humans:
		out.append(int(hits.get(seat, 0)))
	return out


static func aim_ok(dir: Vector3) -> bool:
	return dir.is_finite() and dir.length() > 0.0


## 线段 vs 球：一步的扫掠段和胸口那个球挨上就算命中。
static func segment_hit(from: Vector3, to: Vector3, chest: Vector3, radius: float) -> bool:
	var closest := Geometry3D.get_closest_point_to_segment(chest, from, to)
	return closest.distance_to(chest) <= radius


## 粪球推在屎壳郎身前（节点自己的 -Z）；yaw 0 时球在 z 更小的那一侧。
static func ball_at(beetle: Dictionary) -> Vector2:
	var yaw := float(beetle.get("yaw", 0.0))
	return Vector2(
		float(beetle["x"]) - sin(yaw) * Config.POOP_BALL_AHEAD,
		float(beetle["z"]) - cos(yaw) * Config.POOP_BALL_AHEAD
	)


## 超时判：挨得最多的那个座位，平了 -1（谁也不付钱）。
static func loser_by_hits(hits_list: Array, humans_value: int) -> int:
	var worst := -1
	var most := -1
	var tied := false
	for i in humans_value:
		var n := int(hits_list[i]) if i < hits_list.size() else 0
		if n > most:
			most = n
			worst = i
			tied = false
		elif n == most:
			tied = true
	return -1 if tied else worst
