# 森林赛跑（第二款小游戏）实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 森林里加一条 220m 直道赛跑：玩家 + 3 个人机，绕开固定障碍与横穿赛道的小动物，先到终点者赢，名次换蘑菇币；每局地形随机。

**Architecture:** 「赛道生成」「人机跑法」「名次与币」写成不依赖节点的 `RefCounted` 纯模型（`RaceField` / `RaceRacer` / `RaceScore`），无头测试直接 `new()` 跑；玩家是真实 `CharacterBody3D`（复用 `Movement` 的加减速数学与 `MushroomMesh` 外观），障碍与小动物是 `StaticBody3D` / `AnimatableBody3D`。`race.gd` 只做编排：按种子建赛道、摆四个人、驱动 HUD 与结算。教室那套「POI 浮层 → 3-2-1 倒数 → 自包含场景 → 结算面板」原样复用。

**Tech Stack:** Godot 4.7.2（Mobile 渲染器）、GDScript、`bash scripts/test.sh`、adb 真机验收。

**Spec:** `docs/superpowers/specs/2026-10-17-race-minigame-design.md`（父文档：`docs/superpowers/specs/2026-10-17-fungi-party-design.md`）

## Global Constraints

- Godot 锁 **4.7.2**，渲染器 `mobile`，横屏，`canvas_items` + `expand`；不新增依赖。
- 可调数字全部进 `game/config.gd` 的 `const`。
- 纯逻辑模型不 `preload` 场景、不引用节点；`class_name` + `static func` 优先。
- 浮层字体/面板/按钮统一用 `game/ui/ui_style.gd`；教室已有的 `ClassroomUI`、`DoorPanel` 是抄写模板。
- 场景内部用 `$` 直接引用；森林侧的跨场景引用每帧惰性 `get_first_node_in_group`，不在 `_ready` 里查。
- **每局必须重新掷种子**：`RaceField.new(randi())`、「再来一局」= `reload_current_scene()`；不许出现写死的种子（v2 栽过）。
- 提交信息用中文。
- 测试命令统一 `bash scripts/test.sh`。

## Review Focus

1. **每局是同一张图**：种子写死 / 「再来一局」复用旧 `RaceField` → 障碍与动物时刻逐帧复刻。落点 Task 6 验收：连跑两局截图对比。
2. **动物从画面外撞人**：影子预警必须提前 1 秒出现在赛道上、且从它将要进场的那一侧来。落点 Task 5。
3. **撞了之后失控**：弹开 1.5m + 冻结 0.6 秒期间，摇杆输入不能累积（否则解冻瞬间窜出去），镜头不能抖。落点 Task 4/5。
4. **手机上跑不起来**：手机没有 shift 键，赛跑速度必须自带（基础 6 m/s），不能沿用森林里「走 3 / 跑 6」的双速。落点 Task 4。
5. **连跑三局后有残留**：`reload_current_scene()` 后旧动物/计时/HUD 不能叠加（freed instance）。落点 Task 7 真机三局 + logcat。

---

### Task 1: 赛道生成模型 `RaceField`

**Files:**
- Modify: `game/config.gd`
- Create: `game/minigame/race_field.gd`、`tests/test_race_field.gd`

**Interfaces:**
- Consumes: `Config`
- Produces:
  - `RaceField`（`class_name RaceField extends RefCounted`）
  - 内部类 `Group`：`z: float`（赛道纵向位置）、`kind: int`（`RaceField.TALL` / `RaceField.LOW`）、`gap_x: float`（缝中心，相对中线）、`gap_width: float`
  - 内部类 `Crossing`：`time: float`（**影子出现**的时刻，秒）、`side: int`（`-1` 左 / `+1` 右）、`kind: int`（`BEETLE` / `DUNG` / `SQUIRREL`）、`z: float`
  - `RaceField.new(seed_value: int)`；字段 `groups: Array`、`crossings: Array`
  - `static func animal_x(side: int, elapsed: float) -> float` — 动物相对中线的横向位置，`elapsed` 从**本体进场**算起
  - 常量 `TALL`、`LOW`、`BEETLE`、`DUNG`、`SQUIRREL`

- [ ] **Step 1: `game/config.gd` 加 v3 常量**

```gdscript
# v3 森林赛跑
const RACE_TRACK_LENGTH := 220.0
const RACE_TRACK_HALF_WIDTH := 4.5
const RACE_BASE_SPEED := 6.0
const RACE_DASH_SPEED := 12.0
const RACE_DASH_SECONDS := 0.3
const RACE_DASH_COOLDOWN := 3.0
const RACE_HIT_PUSH := 1.5
const RACE_HIT_FREEZE := 0.6
const RACE_GROUP_MIN_GAP := 12.0
const RACE_GROUP_MAX_GAP := 18.0
const RACE_TALL_CHANCE := 0.7
const RACE_LOW_CHANCE := 0.2
const RACE_TALL_WIDTH := 2.6
const RACE_LOW_WIDTH := 3.4
const RACE_ANIMAL_COUNT := 6
const RACE_ANIMAL_WARN := 1.0
const RACE_ANIMAL_CLEAR := 8.0
const RACE_RANK_COINS := [70, 50, 35, 20]
const RACE_HIT_PENALTY := 5
const RACE_TIME_LIMIT := 120.0
const RACE_PATH := "res://game/minigame/race.tscn"
```

- [ ] **Step 2: 写失败测试 `tests/test_race_field.gd`**

```gdscript
extends TestBase

func test_same_seed_same_course() -> void:
	var a := RaceField.new(7)
	var b := RaceField.new(7)
	check_eq(a.groups.size(), b.groups.size(), "同一种子组数相同")
	for i in a.groups.size():
		check(absf(a.groups[i].z - b.groups[i].z) < 0.001, "同一种子位置相同")

func test_different_seed_different_course() -> void:
	var a := RaceField.new(7)
	var b := RaceField.new(8)
	var diff := false
	for i in mini(a.groups.size(), b.groups.size()):
		if absf(a.groups[i].z - b.groups[i].z) > 0.001 or a.groups[i].kind != b.groups[i].kind:
			diff = true
	check(diff, "换种子应当换地图")

func test_group_spacing_and_bounds() -> void:
	var f := RaceField.new(3)
	check(f.groups.size() >= 8, "220m 的赛道至少 8 组障碍（实得 %d）" % f.groups.size())
	for i in f.groups.size():
		check(f.groups[i].z < Config.RACE_TRACK_LENGTH - 15.0, "每组都离终点留 15m")
		if i == 0:
			continue
		var gap: float = f.groups[i].z - f.groups[i - 1].z
		check(gap >= Config.RACE_GROUP_MIN_GAP - 0.001 and gap <= Config.RACE_GROUP_MAX_GAP + 0.001,
			"组间距 12~18m（实得 %f）" % gap)

func test_gap_inside_track() -> void:
	var f := RaceField.new(11)
	for g in f.groups:
		check(absf(g.gap_x) + g.gap_width * 0.5 <= Config.RACE_TRACK_HALF_WIDTH - 0.3, "缝整条落在赛道内")
		check(g.gap_width >= 2.4, "缝至少 2.4m 宽，人能过去（实得 %f）" % g.gap_width)

func test_kind_ratio() -> void:
	var tall := 0
	var low := 0
	for seed_value in range(1, 41):
		for g in RaceField.new(seed_value).groups:
			tall += 1 if g.kind == RaceField.TALL else 0
			low += 1 if g.kind == RaceField.LOW else 0
	var ratio := float(tall) / float(tall + low)
	check(ratio > 0.6 and ratio < 0.8, "高障碍约占七成（实得 %.2f）" % ratio)

func test_crossings_clear_of_groups() -> void:
	var f := RaceField.new(5)
	check_eq(f.crossings.size(), Config.RACE_ANIMAL_COUNT, "每局六只动物")
	var last := 0.0
	for c in f.crossings:
		check(c.time > last, "出场时刻递增")
		last = c.time
		check(c.side == -1 or c.side == 1, "从一侧进")
		for g in f.groups:
			check(absf(c.z - g.z) >= Config.RACE_ANIMAL_CLEAR, "动物横穿处离障碍组至少 8m（实得 %f）" % absf(c.z - g.z))

func test_animal_x_walks_in_stops_leaves() -> void:
	# 侧面进场 → 停在中间 → 从另一侧离开
	var mid := RaceField.animal_x(1, 1.4 + 0.6)
	check(absf(mid) < 0.001, "进场 1.4 秒后停在赛道中间")
	check(RaceField.animal_x(1, 0.0) > 6.0, "开始时在赛道外")
	check(RaceField.animal_x(1, 4.0) < -6.0, "最后从另一侧离开")
	check(RaceField.animal_x(-1, 0.0) < -6.0, "side=-1 从左进")
```

- [ ] **Step 3: 跑测试确认失败**

Run: `bash scripts/test.sh`
Expected: FAIL（`RaceField` 未定义，`test_race_field.gd` 无法加载）

- [ ] **Step 4: 实现 `game/minigame/race_field.gd`**

生成规则（`_init(seed_value)` 里用 `RandomNumberGenerator`，`seed = seed_value`）：
- 从 `z = 22.0` 开始，每组间隔 `randf_range(12, 18)`，直到 `z > RACE_TRACK_LENGTH - 25.0` 停止。
- 每组掷一次：`< 0.7` → `TALL`；`< 0.9` → `LOW`；剩下 10% 这组**不放**（继续下一个 z，即空档）。
- `gap_width` = `RACE_TALL_WIDTH` / `RACE_LOW_WIDTH`；`gap_x = clampf(randf_range(-3.0, 3.0), -3.0, 3.0)` 后按「缝必须整条在赛道内」夹一次。
- 动物：`RACE_ANIMAL_COUNT` 只，时刻从 3 秒起按 `randf_range(4.0, 7.0)` 递增（保证递增且落在 40 秒内）；`side` 交替随机；`kind` 按 40/35/25 权重掷。
- 动物的 `z`：`randf_range(20, TRACK_LENGTH - 20)` 后逐个检查，离任一组的 `z` 不足 `RACE_ANIMAL_CLEAR` 就重掷（最多 50 次，失败就平移到最近的合法位置）。
- `animal_x(side, elapsed)`：0→1.4s 从 `7*side` 走到 0；1.4→2.6s 停在 0；2.6→4.0s 走到 `-7*side`；区间外钳在两端。

- [ ] **Step 5: 跑测试确认通过**

Run: `bash scripts/test.sh`
Expected: 全部 PASS

- [ ] **Step 6: 提交**

```bash
git add game/config.gd game/minigame/race_field.gd tests/test_race_field.gd
git commit -m "赛跑赛道生成：按种子排障碍组与动物横穿时间表"
```

---

### Task 2: 人机跑法 `RaceRacer`

**Files:**
- Create: `game/minigame/race_racer.gd`、`tests/test_race_racer.gd`

**Interfaces:**
- Consumes: `Config`、`RaceField`
- Produces（`class_name RaceRacer extends RefCounted`）：
  - `enum Style { STEADY, HUGGER, DASHER }`（稳中 / 贴边抄近道 / 冲动）
  - `RaceRacer.new(style: int, seed_value: int)`
  - 字段 `z: float`、`x: float`、`hits: int`、`finished: bool`、`finish_time: float`、`dash_left: float`、`freeze: float`
  - `advance(delta: float, field: RaceField, elapsed: float) -> void` — 推进一帧（内部把 delta 夹到 1/30）
  - `static func animal_x(...)` 由 `RaceField` 提供，不重复实现

- [ ] **Step 1: 写失败测试 `tests/test_race_racer.gd`**

```gdscript
extends TestBase

func test_runs_forward() -> void:
	var r := RaceRacer.new(RaceRacer.Style.STEADY, 1)
	var f := RaceField.new(1)
	for i in 60:
		r.advance(1.0 / 60.0, f, i / 60.0)
	check(r.z > 5.0 and r.z < 7.0, "一秒约跑 6 米（实得 %f）" % r.z)

func test_stays_on_track() -> void:
	var r := RaceRacer.new(RaceRacer.Style.HUGGER, 2)
	var f := RaceField.new(2)
	for i in 600:
		r.advance(1.0 / 60.0, f, i / 60.0)
		check(absf(r.x) <= Config.RACE_TRACK_HALF_WIDTH, "不出赛道（x=%f）" % r.x)

func test_hits_and_freezes() -> void:
	var f := RaceField.new(4)
	var g: RaceField.Group = f.groups[0]
	var r := RaceRacer.new(RaceRacer.Style.STEADY, 4)
	r.z = g.z - 1.0
	r.x = g.gap_x + g.gap_width * 0.5 + 1.5   # 故意站在墙里
	r.advance(1.0 / 60.0, f, 0.0)
	check_eq(r.hits, 1, "撞上障碍记一次")
	check(r.z < g.z - 1.0, "撞了往后退")
	check(r.freeze > 0.0, "撞了有硬直")

func test_freezes_block_movement() -> void:
	var f := RaceField.new(4)
	var r := RaceRacer.new(RaceRacer.Style.STEADY, 4)
	r.freeze = 0.3
	var z := r.z
	r.advance(0.1, f, 0.0)
	check(absf(r.z - z) < 0.001, "硬直期间不前进")

func test_personalities_differ() -> void:
	var steady := _sim(RaceRacer.Style.STEADY, 0.0, 40.0)
	var hugger := _sim(RaceRacer.Style.HUGGER, 0.0, 40.0)
	var dasher := _sim(RaceRacer.Style.DASHER, 0.0, 40.0)
	check(hugger["hits"] > steady["hits"], "贴边的撞得更多（%d vs %d）" % [hugger["hits"], steady["hits"]])
	check(dasher["z"] > steady["z"], "冲动型跑得更远（%f vs %f）" % [dasher["z"], steady["z"]])

func test_finish_detected() -> void:
	var r := RaceRacer.new(RaceRacer.Style.STEADY, 3)
	var f := RaceField.new(3)
	r.z = Config.RACE_TRACK_LENGTH - 0.5
	var t := 0.0
	for i in 30:
		r.advance(1.0 / 60.0, f, t)
		t += 1.0 / 60.0
	check(r.finished, "越过终点即完赛")
	check(r.finish_time > 0.0, "记下完赛时间")

func test_big_delta_clamped() -> void:
	var r := RaceRacer.new(RaceRacer.Style.STEADY, 3)
	var f := RaceField.new(3)
	r.advance(1.0, f, 0.0)
	check(r.z < 0.5, "0.3 秒以上的 delta 不会瞬间冲出去（实得 %f）" % r.z)

func _sim(style: int, from_z: float, seconds: float) -> Dictionary:
	var r := RaceRacer.new(style, 9)
	var f := RaceField.new(9)
	r.z = from_z
	var t := 0.0
	while t < seconds and not r.finished:
		r.advance(1.0 / 60.0, f, t)
		t += 1.0 / 60.0
	return {"hits": r.hits, "z": r.z}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `bash scripts/test.sh`
Expected: FAIL（`RaceRacer` 未定义）

- [ ] **Step 3: 实现 `game/minigame/race_racer.gd`**

每帧（`d := minf(delta, 1.0/30.0)`）：
1. `freeze > 0` → `freeze -= d`，本帧只做横向回中，不前进，返回。
2. 前进：`var speed := Config.RACE_BASE_SPEED`；`dash_left > 0` → `speed = Config.RACE_DASH_SPEED`，`dash_left -= d`；`z += speed * d`。`z >= RACE_TRACK_LENGTH` → `finished = true`、`finish_time = elapsed`。
3. 横向：找前方 `z + 18.0` 内最近的一组，目标 = 该组的缝（`HUGGER` 瞄准缝最靠近自己当前 x 的一侧边缘，其余瞄准缝中心）；没有前方组就朝 `x = 0` 靠。`x = move_toward(x, target, 7.0 * d)`，最后 `clampf` 到赛道半宽内。
4. 冲刺（只有 `DASHER`）：`dash_left <= 0 and dash_cd <= 0` 且前方 8m 内没有障碍 → `dash_left = RACE_DASH_SECONDS`、`dash_cd = RACE_DASH_COOLDOWN`。`dash_cd` 每帧递减。
5. 撞击：对前方 `z - 0.5 .. z + 0.9` 内的每组障碍，若 `|x - gap_x| > gap_width * 0.5` → `hits += 1`、`z -= RACE_HIT_PUSH`、`freeze = RACE_HIT_FREEZE`。动物同理：用 `RaceField.animal_x(c.side, elapsed - c.time - Config.RACE_ANIMAL_WARN)`，`|z - c.z| < 0.9 and |x - ax| < 0.9` 算撞。
6. `STEADY` 与 `DASHER` 加一点横向抖动（`sin(elapsed * 1.7 + seed) * 0.35`），让人机不像在轨道上滑。

- [ ] **Step 4: 跑测试确认通过**

Run: `bash scripts/test.sh`
Expected: 全部 PASS（若 `test_personalities_differ` 太苛刻，调横向速度或抖动幅度而不是改断言）

- [ ] **Step 5: 提交**

```bash
git add game/minigame/race_racer.gd tests/test_race_racer.gd
git commit -m "赛跑人机：三种性格、绕障碍、撞了弹开"
```

---

### Task 3: 名次与蘑菇币 `RaceScore`

**Files:**
- Create: `game/minigame/race_score.gd`、`tests/test_race_score.gd`

**Interfaces:**
- Consumes: `Config`
- Produces（`class_name RaceScore`）：
  - `static func ranking(racers: Array) -> Array` — 传入四个「有 `finished` / `finish_time` / `z` 字段」的对象（`RaceRacer` 或玩家的结果字典），返回按名次排列的下标数组
  - `static func coins(rank: int, hits: int) -> int` — `rank` 从 0 开始

- [ ] **Step 1: 写失败测试 `tests/test_race_score.gd`**

```gdscript
extends TestBase

func _r(finished: bool, time: float, z: float) -> Dictionary:
	return {"finished": finished, "finish_time": time, "z": z}

func test_finished_first_then_progress() -> void:
	var racers := [
		_r(true, 30.0, 220.0),
		_r(false, 0.0, 140.0),
		_r(false, 0.0, 190.0),
		_r(false, 0.0, 60.0),
	]
	var order := RaceScore.ranking(racers)
	check_eq(order, [0, 2, 1, 3], "先按冲线，再按进度")

func test_tie_progress_keeps_lower_index() -> void:
	var racers := [
		_r(false, 0.0, 100.0),
		_r(false, 0.0, 100.0),
		_r(false, 0.0, 50.0),
		_r(false, 0.0, 10.0),
	]
	check_eq(RaceScore.ranking(racers)[0], 0, "并列时下标小的在前")

func test_coins_by_rank() -> void:
	check_eq(RaceScore.coins(0, 0), 70, "第一名满分")
	check_eq(RaceScore.coins(3, 0), 20, "第四名保底")
	check_eq(RaceScore.coins(1, 3), 35, "第二名撞三次")

func test_coins_never_negative() -> void:
	check_eq(RaceScore.coins(3, 99), 0, "撞太多次夹到 0")
```

- [ ] **Step 2: 跑测试确认失败**

Run: `bash scripts/test.sh`
Expected: FAIL（`RaceScore` 未定义）

- [ ] **Step 3: 实现 `game/minigame/race_score.gd`**

`ranking`：先取已完赛者按 `finish_time` 升序；未完赛者按 `z` 降序接在后面；完全并列保持原下标顺序（`sort_custom` 的比较函数里相等时返回 `false`）。`coins(rank, hits)` = `maxi(0, Config.RACE_RANK_COINS[rank] - Config.RACE_HIT_PENALTY * hits)`。

- [ ] **Step 4: 跑测试确认通过**

Run: `bash scripts/test.sh`
Expected: 全部 PASS

- [ ] **Step 5: 提交**

```bash
git add game/minigame/race_score.gd tests/test_race_score.gd
git commit -m "赛跑名次与蘑菇币结算"
```

---

### Task 4: 赛道几何、玩家物理与固定相机

**Files:**
- Create: `game/minigame/race_course.gd`、`game/minigame/race_player.gd`、`game/minigame/race.tscn`、`game/minigame/race.gd`

**Interfaces:**
- Consumes: `Config`、`RaceField`、`Movement`、`MushroomMesh`、`UIStyle`
- Produces:
  - `RaceCourse`（`class_name RaceCourse extends Node3D`）：`func build(field: RaceField) -> void`
  - `RacePlayer`（`class_name RacePlayer extends CharacterBody3D`）：`func feed(move: Vector2, jump: bool, dash: bool) -> void`；字段 `hits: int`、`finished: bool`、`finish_time: float`；信号无关（由 `race.gd` 每帧读）
  - `race.tscn` 根节点 `Race`（`Node3D` + `race.gd`），含 `Camera3D`（`position = Vector3(0, 3.5, 7)`、`rotation_degrees = Vector3(-14, 0, 0)`）

- [ ] **Step 1: 赛道几何**

`race_course.gd` 的 `build(field)` 程序化建：地面 `BoxMesh` 220×0.2×9（土黄，`y=-0.1`）、两侧护栏 `BoxMesh` 220×0.9×0.3（`x=±4.65`）、起点拱门与终点拱门（两根柱 + 门楣，终点门楣用亮色）、每组障碍按 `field.groups` 建 `StaticBody3D`（`TALL` 高 2.2m、`LOW` 高 0.6m；缝的左右各一块，缝贴边时只建一块），碰撞体与视觉同尺寸，全部 `add_to_group("hazard")`。终点线用一条白色贴地薄片。

- [ ] **Step 2: 玩家控制器**

`race_player.gd`：`CharacterBody3D` + 胶囊碰撞（半径 0.45、高 1.5，中心 `y=0.75`）+ `MushroomMesh` 子节点。`_physics_process(delta)`：`Movement.accelerate` 把 `feed()` 给的摇杆方向乘 `Config.RACE_BASE_SPEED`（冲刺时 `RACE_DASH_SPEED`）、重力沿用 `Config.GRAVITY`、跳跃用 `Movement.jump_velocity(Config.GRAVITY, Config.JUMP_HEIGHT)`；`move_and_slide()` 之后读 `get_slide_collision_count()`，撞到 `is_in_group("hazard")` 的物体 → `hits += 1`、沿碰撞法线反向推开 `RACE_HIT_PUSH`、`freeze = RACE_HIT_FREEZE`。冻结期间**忽略摇杆输入**（不累积速度），解冻后速度从 0 起。`z` 过 `RACE_TRACK_LENGTH` 置 `finished`。

- [ ] **Step 3: 编排骨架**

`race.gd`：`var _field := RaceField.new(randi())`；`_ready` 里建 `RaceCourse`（`build(_field)`）、`RacePlayer`、`Camera3D` 跟随（`camera.z = player.z + 7`，只跟位置不转）。`race.tscn` 实例化现有的 `game/ui/touch_controls.tscn` 当摇杆与跳跃按钮（读 `move_input` 与 `jump_pressed`）；冲刺这一步先用键盘 `Input.is_action_pressed("run")`（Shift）验证，触屏冲刺按钮留到 Task 6 的 `RaceUI` 里做。

- [ ] **Step 4: 桌面跑通（人工）**

Run: `godot --path . res://game/minigame/race.tscn`
Expected: 能看到直道、两侧护栏、前方一组组障碍；WASD 能跑，空格能跳过矮栏（跳过时不会撞）、撞高墙会弹开并停半秒；相机始终朝前不旋转。构图或速度不对就调 `race.tscn` 的相机与 `Config.RACE_*`，别改赛道生成。

- [ ] **Step 5: 提交**

```bash
git add game/minigame/race_course.gd game/minigame/race_player.gd game/minigame/race.gd game/minigame/race.tscn
git commit -m "赛跑场景：直道、障碍碰撞、玩家跑跳冲刺与固定相机"
```

---

### Task 5: 三个对手、三种动物与撞击反馈

**Files:**
- Create: `game/minigame/racer_visual.gd`、`game/minigame/animal_actor.gd`
- Modify: `game/minigame/race.gd`

**Interfaces:**
- Consumes: `RaceRacer`、`RaceField`、`MushroomMesh`、`Config`
- Produces:
  - `RacerVisual`（`class_name RacerVisual extends Node3D`）：`func setup(color: Color) -> void`、`func apply(racer: RaceRacer) -> void`
  - `AnimalActor`（`class_name AnimalActor extends Node3D`）：`func setup(kind: int, side: int, z: float) -> void`、`func advance(elapsed: float) -> void`（`elapsed` 从影子出现算起；影子 = 贴地深色椭圆，本体在 `elapsed >= Config.RACE_ANIMAL_WARN` 后才出现）

- [ ] **Step 1: 对手与动物**

`racer_visual.gd`：`MushroomMesh`（缩放 0.85，颜色区分）+ 头顶一个小色块；`apply` 把 `racer.z/x` 写到 `position`，`freeze > 0` 时整体压扁一点、`dash_left > 0` 时拉长一点。

`animal_actor.gd`：三种几何（胖甲虫 = 压扁球 + 触角 + 短腿；屎壳郎 = 小球 + 大棕球；松鼠 = 胶囊身体 + 大尾巴球，丢下的松果是一个独立小方块）。全部 `AnimatableBody3D` + `add_to_group("hazard")`。`advance(elapsed)` 用 `RaceField.animal_x(side, elapsed - Config.RACE_ANIMAL_WARN)` 写 `position.x`；`elapsed < WARN` 只显示影子（`QuadMesh` 贴地、`y=0.02`、深色半透明、`visible` 随影子阶段切换）。

- [ ] **Step 2: 三个对手进场景**

`race.gd` 里建三个 `RaceRacer`（`STEADY` / `HUGGER` / `DASHER`，种子 `randi()`）+ 三个 `RacerVisual`（放到各自起始横向位置 `-2.5 / 0 / 2.5`，玩家在 `x=0` 但要错开出发：玩家 `z=0`，对手 `z=+0.6` 等错位，避免叠在一起）。

- [ ] **Step 3: 玩家与动物碰撞**

玩家胶囊与 `AnimatableBody3D` 的碰撞走既有物理；撞击弹开由 `race_player.gd` 的法线判定统一处理，不额外写一套。松果在松鼠横穿到一半时生成（`elapsed >= WARN + 1.4`），是 `StaticBody3D` + `hazard` 组，高度 0.6m。

- [ ] **Step 4: 桌面跑通（人工）**

Run: `godot --path . res://game/minigame/race.tscn`
Expected: 三个对手在前面各自绕障碍、偶尔撞到会被弹一下；动物进场前先看到地面影子、影子从它来的那一侧进来，进场后停在中间再走掉；松鼠走一半留下松果，撞上去会弹开。

- [ ] **Step 5: 提交**

```bash
git add game/minigame/racer_visual.gd game/minigame/animal_actor.gd game/minigame/race.gd
git commit -m "赛跑对手与森林小动物：横穿预警、三种动物、撞了弹开"
```

---

### Task 6: HUD、倒数与结算

**Files:**
- Create: `game/minigame/race_ui.gd`、`game/minigame/race_ui.tscn`
- Modify: `game/minigame/race.gd`、`game/minigame/race.tscn`

**Interfaces:**
- Consumes: `UIStyle`、`Config`、`RaceScore`
- Produces:
  - `RaceUI`（`class_name RaceUI extends CanvasLayer`）：`func show_countdown(text: String) -> void`、`func hide_countdown() -> void`、`func set_progress(player_z: float, rivals: Array, rank: int) -> void`、`func set_dash_ready(ratio: float) -> void`、`func set_time(seconds: float) -> void`、`func show_result(rank: int, seconds: float, hits: int, earned: int) -> void`、信号 `again_pressed` / `forest_pressed` / `dash_pressed`（右下角冲刺按钮，`Button.pressed` 直接发出）

- [ ] **Step 1: HUD**

顶部一条横向进度条（`ColorRect` 底 + 四个小圆点：玩家红色、三个对手各一色；点的 `position.x = clampf(z / RACE_TRACK_LENGTH, 0, 1) * bar_width`）。左上角一行「用时 %d 秒　第 %d 名」；右下角冲刺按钮带冷却环（`TextureProgressBar` 或一个 `ColorRect` 遮罩，`ratio` 0~1）。字体与按钮全部走 `UIStyle`。

- [ ] **Step 2: 倒数与结算**

抄 `classroom.gd` 的写法：`_countdown := 3.0` 期间不推进任何 `RaceRacer`、不写玩家输入、不计时；倒数结束才起跑。冲刺按钮接 `RacePlayer` 的冲刺请求（`race.gd` 收到 `dash_pressed` 后给 `feed` 传一个单帧的 `dash = true`）。玩家冲线或超过 `RACE_TIME_LIMIT` → 结算：`RaceScore.ranking` 取玩家名次、`RaceScore.coins(rank, hits)` 算币、`Save.add_coins(earned)` 入库、`_ui.show_result(...)`。`again_pressed` → `reload_current_scene()`，`forest_pressed` → `change_scene_to_file(Config.FOREST_PATH)`。

- [ ] **Step 3: 桌面跑通（人工）**

Run: `godot --path . res://game/minigame/race.tscn`
Expected: 进场景先 3-2-1；跑动时进度条四个点都在动、名次会变；冲刺按钮有冷却；冲线弹结算面板，两个按钮都能点。

- [ ] **Step 4: 每局不同（Review Focus 1）**

Run: 连续 `godot --path . res://game/minigame/race.tscn` 两次，各截图一张前 30 秒。
Expected: 两张图的障碍位置/类型、动物出场时刻都不一样。若一样，说明种子写死了，回到 `race.gd` 检查 `RaceField.new(randi())`。

- [ ] **Step 5: 提交**

```bash
git add game/minigame/race_ui.gd game/minigame/race_ui.tscn game/minigame/race.gd game/minigame/race.tscn
git commit -m "赛跑 HUD、3-2-1 倒数与名次结算"
```

---

### Task 7: 森林起跑线、真机验收与收尾

**Files:**
- Create: `game/world/start_gate.gd`、`game/ui/race_panel.gd`
- Modify: `game/world/forest.tscn`、`game/main.tscn`、`AGENTS.md`、`CLAUDE.md`、`docs/perf-log.md`、`docs/superpowers/specs/2026-10-17-race-minigame-design.md`（状态一行）

**Interfaces:**
- Consumes: `Config.RACE_PATH`、`UIStyle`、`DoorPanel` 的写法
- Produces: `StartGate`（`class_name StartGate extends Node3D`）：`var player_inside := false`、`add_to_group("start_gate")`

- [ ] **Step 1: 起跑线 POI**

`start_gate.gd`：两根柱子 + 门楣（复用 `door.gd` 的尺寸风格）+ 地面一条白线 + `Area3D`（2.2×2×1.6）每帧扫 `get_overlapping_bodies()` 写 `player_inside`。位置 `Vector3(-7, 0, -11)`（和摊位、校门错开）。

- [ ] **Step 2: 浮层**

`race_panel.gd` 抄 `door_panel.gd`（`ColorRect` 遮罩 + `CenterContainer` + `PanelContainer` + `UIStyle`）：标题「森林赛跑」、三行玩法（「绕开障碍跑到终点 / 侧面有动物冲出来，影子先到 / 跳能跨矮栏，冲刺要等冷却」）、按钮「开始比赛」→ `change_scene_to_file(Config.RACE_PATH)`；每帧惰性找 `start_gate`。`main.tscn` 加 `RacePanel` 节点。

- [ ] **Step 3: 真机走一遍**

```bash
godot --headless --path . --export-debug "Android" build/fungi-party.apk
adb install -r build/fungi-party.apk
```
Expected: 走到起跑线 → 浮层 → 开始 → 3-2-1 → 跑完一局 → 结算 → 回森林；连跑三局 `adb logcat -s godot` 无 ERROR（Review Focus 5）；截 `shots/v3-race.png`。

- [ ] **Step 4: 调数值**

记录一局：用时、撞击次数、名次、三个人机各自的撞击次数。只动 `game/config.gd` 的 `RACE_*` 数字，目标：**三次以内能拿一次第一，老手也不是每局都赢**。一局明显超过 45 秒 → 调 `RACE_BASE_SPEED` 或缩短赛道；撞得太多 → 加大组间距或缝宽。结论写进 `docs/perf-log.md`（机型、FPS、DRAW、TRI、一局关键数值）。

- [ ] **Step 5: 更新文档**

`AGENTS.md` / `CLAUDE.md` 的场景结构补一行（`game/minigame/` 现在有两款小游戏；森林里三个 POI：校门、摊位、起跑线），仍 ≤50 行。赛跑设计文档状态从「待确认」改成「已实现」。

- [ ] **Step 6: 提交**

```bash
git add -A && git commit -m "森林赛跑收尾：起跑线、真机验收、数值与文档"
```

---

## 自审

**Spec 覆盖**

| 设计文档条目 | 落在哪个任务 |
|---|---|
| 220m×9m 直道、护栏、无弯道 | T4 |
| 障碍 70/20/10、每组留缝、间距 12~18m | T1（生成）+ T4（几何） |
| 每局随机种子（硬要求） | T1（模型）+ T4（`randi()`）+ T6 验收 |
| 三种动物、横穿→停留→离开、影子提前 1 秒 | T1（时刻表与 `animal_x`）+ T5（观感） |
| 动物离障碍组 ≥8m | T1（生成约束 + 测试） |
| 松果：矮、可跳、留存 | T5 |
| 撞击弹开 1.5m + 停 0.6s，只有这一种惩罚 | T2（人机）+ T4（玩家） |
| 跳/冲刺（12 m/s、0.3s、CD 3s，撞了照样弹） | T4（玩家）+ T2（人机） |
| 三种人机性格 | T2 |
| 名次 + 币 70/50/35/20 − 5×撞击 | T3 |
| 玩家冲线即结算、120 秒超时 | T6 |
| 镜头锁死朝前、水平跟随、不抖 | T4 |
| 场内 HUD：进度条 + 名次 + 用时 + 冷却环 | T6 |
| 起跑线 POI + 浮层 + 3-2-1 | T7 + T6 |
| 结算面板两个按钮 | T6 |

**类型一致性**：`RaceField.Group` 的字段名（`z/kind/gap_x/gap_width`）在 T2（绕障碍）、T4（建碰撞）里一致；`RaceField.animal_x(side, elapsed)` 在 T1 定义、T2 与 T5 复用；`RaceRacer` 的 `z/x/hits/finished/finish_time` 在 T2 定义、T5（`RacerVisual.apply`）与 T6（`ranking`）里一致；`RaceScore.ranking` 接受「有 `finished`/`finish_time`/`z` 的对象」，玩家的结果在 T6 里用同名字典传。

**比例**：本计划比设计文档长约一倍，因为赛道生成、人机跑法、名次公式这三块是唯一不能靠常识决定的（数值、约束、性格差异全在这里），而场景与 HUD 只给了尺寸和落点。
