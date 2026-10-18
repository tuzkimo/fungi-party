class_name RaceField
extends RefCounted

## 一条赛道的纯数据：障碍组与动物横穿时间表，全部由种子决定。
## 不碰节点；race_course.gd 照着建几何，race_racer.gd 照着绕。

const TALL := 0
const LOW := 1
const BEETLE := 0
const DUNG := 1
const SQUIRREL := 2

const FIRST_GROUP_Z := 22.0
const TRACK_END_MARGIN := 25.0
const EMPTY_SPACING := 0.1
const GAP_INSET := 0.3
const ANIMAL_FIRST_TIME := 3.0
const ANIMAL_TIME_MIN := 4.0
const ANIMAL_TIME_MAX := 7.0
const ANIMAL_Z_MARGIN := 20.0
const WALK_IN := 1.4
const WALK_STOP := 1.2
const WALK_OUT := 1.4
const START_X := 7.0


class Group extends RefCounted:
	var z := 0.0
	var kind := TALL
	var gap_x := 0.0
	var gap_width := 0.0


class Crossing extends RefCounted:
	var time := 0.0
	var side := 1
	var kind := BEETLE
	var z := 0.0


var groups: Array = []
var crossings: Array = []


func _init(seed_value: int = 1) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	_build_groups(rng)
	_build_crossings(rng)


## 动物相对中线的横向位置，elapsed 从本体进场算起：进场 → 停住 → 从另一侧走掉。
static func animal_x(side: int, elapsed: float) -> float:
	if elapsed < WALK_IN:
		return lerpf(START_X * side, 0.0, maxf(elapsed, 0.0) / WALK_IN)
	if elapsed < WALK_IN + WALK_STOP:
		return 0.0
	var t := clampf((elapsed - WALK_IN - WALK_STOP) / WALK_OUT, 0.0, 1.0)
	return lerpf(0.0, -START_X * side, t)


func _build_groups(rng: RandomNumberGenerator) -> void:
	var z := FIRST_GROUP_Z
	while z < Config.RACE_TRACK_LENGTH - TRACK_END_MARGIN:
		# 空档直接重掷，不消耗纵向距离：记录到的组间距必须留在 12~18m
		if rng.randf() < EMPTY_SPACING:
			continue
		var group := Group.new()
		group.z = z
		group.kind = TALL if rng.randf() < Config.RACE_TALL_CHANCE else LOW
		group.gap_width = Config.RACE_TALL_WIDTH if group.kind == TALL else Config.RACE_LOW_WIDTH
		var limit := Config.RACE_TRACK_HALF_WIDTH - GAP_INSET - group.gap_width * 0.5
		group.gap_x = clampf(rng.randf_range(-limit, limit), -limit, limit)
		groups.append(group)
		z += rng.randf_range(Config.RACE_GROUP_MIN_GAP, Config.RACE_GROUP_MAX_GAP)


func _build_crossings(rng: RandomNumberGenerator) -> void:
	# 只在两组障碍中间横穿：离两侧各半条间隔，永远落不到缝上
	var spots := _animal_spots()
	var time := ANIMAL_FIRST_TIME
	for i in Config.RACE_ANIMAL_COUNT:
		var crossing := Crossing.new()
		crossing.time = time
		crossing.side = -1 if rng.randi() % 2 == 0 else 1
		var roll := rng.randf()
		if roll < 0.40:
			crossing.kind = BEETLE
		elif roll < 0.75:
			crossing.kind = DUNG
		else:
			crossing.kind = SQUIRREL
		if spots.is_empty():
			crossing.z = ANIMAL_Z_MARGIN
		else:
			crossing.z = spots.pop_at(rng.randi() % spots.size())
		crossings.append(crossing)
		time += rng.randf_range(ANIMAL_TIME_MIN, ANIMAL_TIME_MAX)


## 可横穿的纵向位置：相邻两组的中间点 + 最后一组到终点之间的中间点。
func _animal_spots() -> Array:
	var spots: Array = []
	for i in range(1, groups.size()):
		spots.append((groups[i - 1].z + groups[i].z) * 0.5)
	if not groups.is_empty():
		spots.append((groups[groups.size() - 1].z + Config.RACE_TRACK_LENGTH) * 0.5)
	return spots
