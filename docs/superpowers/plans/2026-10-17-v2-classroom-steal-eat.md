# v2 上课偷吃大赛 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在一片已有的森林里加一堂课：四张课桌、玩家 + 3 个人机、老师视线扫视，被看到就罚站；赢了赚蘑菇币，币能在森林的摊位买一顶皮肤。

**Architecture:** 把「回合规则」「老师视线」「人机决策」三件事写成**不依赖节点**的 `RefCounted` 模型（`Gaze` / `StealEat` / `NpcSeat`），全部 `static func` 或纯状态机，无头测试直接 `new()` 就能跑；`classroom.gd` 只做编排（建几何、收触摸、把模型输出画成弹动/进度条/锥形光）。教室是**自包含单场景**，节点间直接 `$` 引用，不跨场景查 group（v1 的坑）。森林里加两个 POI（校门、摊位），都按 v1 的 `Terrain`/`ForestGen` 风格用脚本建几何。

**Tech Stack:** Godot 4.7.2（Mobile 渲染器）、GDScript、v1 建的零依赖无头测试（`bash scripts/test.sh`）、adb 真机验收。

**Spec:** `docs/superpowers/specs/2026-10-17-fungi-party-design.md`（v2 定义在 §6，皮肤/货币在 §7.2、§11、§12）

---

## 三个必须先答的问题

### 1. 老师视线在屏幕上怎么表现

**三层视觉，从上到下，同一屏内全部可见，不用文字解释规则：**

1. **地面扇形光锥**（主力信号，回答「他现在看哪儿」）：老师脚下沿地面铺一个 14° 半角、5.5m 长的扇形。`AWAY` 完全隐藏；`WARN` 阶段 0.3 秒内从透明淡到半透明**黄**（预警）；`WATCH` 阶段变成**红**，透明度拉满。锥是一个 `SurfaceTool` 扇形 mesh（12 段三角），无贴图、无阴影、不写深度，`y=0.02` 贴地。
2. **老师转头**（回答「他刚才在看哪儿，接下来要看哪儿」）：老师就是一朵放大 1.5 倍的蘑菇，脸长在伞盖上。整个身体在 0.3 秒的 `WARN` 内转向目标课桌（`lerp_angle`，角速度 12 rad/s 保证 0.3 秒内转到位），锥跟着转。你看到的是「脸转过来 + 锥变黄」，0.3 秒后变红开始抓人。
3. **目标座位角色头顶的红「!」**（回答「他看的是不是我」）：被锁定的那个座位，角色头顶弹出一个红色 billboard 方块 + 整个人停住弹动。这一层和锥的红色同时出现，玩家自己的角色身上也有，所以不用去看老师的脸判断。

**不做音效**，理由：v2 没有音频管线，加一个 CC0 音效要连带导入设置、首次进入音频总线、移动端延迟校准，换来的信息量已经被上面三层覆盖。`docs` 里记为 v3 的待办。

**被抓的反馈**：罚站瞬间全屏盖一层 0.15 透明度的红晕，0.3 秒淡出（`shortcut: 整屏红晕代替边缘暗角，等有贴图资源再升级`）；被罚座位的角色改直立、不弹动、头顶挂红「!」直到罚站结束。

### 2. 三个人机怎么不像三根木头

不去做「聪明」，只做**同一件事上的三个不同性格**，全部来自 `NpcSeat`：

1. **反应延迟按胆量分布**：`delay = lerp(0.15, 0.6, guts) × randf_range(0.8, 1.2)`，每次老师开始转头重新掷一次。危险线是「盯视开始 + 0.1 秒宽限」（= 预警开始后 0.4 秒），所以 `delay > 0.4` 就会被抓 —— 胆量 0.15/0.35/0.55 的三个人分别落在 0.22/0.31/0.40 左右，**偶尔**手滑被抓。
2. **赌一口**：每次转头有 `guts × 0.25` 的概率把延迟再加 0.3 秒（贪心吃满这一口）。所以胆量最大那个平均每隔十几个回合被抓一次 —— 屏幕上就会有一个人先站起来罚站，其余两个不同步。
3. **发呆**：每个安全窗口有 25% 的概率这一个窗口根本不吃（`NPC_IDLE_CHANCE`），松手后还有 0.1~0.3 秒的「缓一下」才重新开吃。这两条让四个人的口数进度条永远不在一个节奏上 —— 木头味就是「四个人同时开始、同时停下」来的。

三个人的 `guts` 分别是 0.15 / 0.35 / 0.55，种子不同。**不做**感知、记忆、互相干扰、难度自适应。

### 3. 蘑菇币结算公式

```
币 = max(0, 10 + 3 × 吃到的口数 + (赢了 ? 40 : 0) − 5 × 被抓次数)
```

- 满分一局（20 口、0 抓、赢）= 10 + 60 + 40 = **110**。
- 典型一局（12 口、1 抓、没赢）= 10 + 36 − 5 = **41**。
- 打得极差（0 口、3 抓）= 10 − 15 → 夹到 **0**。
- **皮肤定价 200**（一顶「蓝莓帽」）：满分 2 局、典型 5 局。既不是「一局就买到」（没盼头），也不是「十局才够」（像打卡）。
- 输了照样给钱，给的是进度不是名次 —— 这条是为了「输了想再来一局」，只有赢才给币的话，玩家一局劣势就直接放弃。

---

## Global Constraints

- Godot 锁 **4.7.2**，渲染器 `mobile`，横屏 1280×720 `canvas_items`。改渲染器要整体改，不并存两条路。
- 性能以真机帧率为准（见 `docs/perf-log.md`）；教室场景 draw call 预算 <120，不开实时 GI / SSAO / SSR / 体积雾。
- 大件几何用 MultiMesh 或共享 mesh；球体分段不用默认 64×32（v1 已把 155k 面压到 15k）。
- 虚拟控件自己用 `Control` + 触摸事件实现，不引任何第三方插件；v2 **不新增**全局依赖。
- 所有可调数字集中在 `game/config.gd` 的 `const`。
- 角色逻辑（移动/动画/状态）不引用 mesh 节点路径；外观只在 `mushroom_mesh.gd` 改，皮肤只改它的导出参数。
- 非平凡逻辑先写测试，能抽纯函数的抽成 `static func`；测试命令统一 `bash scripts/test.sh`（先刷全局类缓存）。
- **跨场景节点不能在 `_ready` 里 `get_first_node_in_group`**（v1 的 Critical 1 就栽在这）。新场景内部用直接引用，跨场景用每帧惰性查找。
- **禁**：体力、时间循环（游戏内的一天）、村庄、联机、第二个小游戏、音频系统、通用皮肤装配系统。看到了就是超出范围。
- 提交信息用中文，符合中文开发习惯。

## Review Focus

以下五类是 spec / v1 账本暗示、但没有任何单个任务的测试会自然覆盖、且最容易在真机上咬人的情况。每条在对应任务里有落点。

1. **中文字体是豆腐块**：Godot 默认字体没有 CJK 字形，v1 的 HUD 全是 ASCII 所以没暴露。v2 的商店和结算面板必须显示中文 → 全部 `Theme.default_font = SystemFont(...)`。真机截图确认不是方块；是方块就落 Plan B（下载 OFL 的 `NotoSansSC-Regular.otf` 放 `art/fonts/`，`--editor --quit` 导入）。落点在 Task 6。
2. **按住后手指滑出屏幕边缘**：`InputEventScreenTouch` 的抬手事件照样带 index，但若按位置判定就会误判成松手 → 「我明明按着却被抓」。所有按住态按 **finger index** 绑定，落点在 Task 6 的 `EatInput.next_finger()` 测试。
3. **场景往返后节点引用失效**：森林 → 教室 → 森林，`change_scene_to_file` 之后旧节点全没了，任何缓存的引用都会变成已释放对象。规则：教室不使用 group；森林侧的门/摊位/商店面板全部每帧惰性查找（v1 `_find_touch` 的写法）。headless 测不了 `change_scene`，落点是 Task 9 的真机步骤：来回切 3 次，`adb logcat -s godot` 无 ERROR。
4. **一帧大 delta**：切场景/加载卡顿后第一帧 delta 可能是 0.3 秒，回合若不夹取会「瞬间吃完一口」或「瞬间被抓」。`StealEat.tick()` 内部把 delta 夹到 1/30（和 v1 `Movement.accelerate` 同款）。落点在 Task 2 的 `test_big_delta_clamped`。
5. **罚站结束后立刻连环被抓**：被抓住时人还在吃，若不清状态，罚站 3 秒一结束、视线还没走，0.1 秒后又被抓，三次就出局 —— 玩家会觉得游戏坏了。规则：被抓后必须**先松手**才能重新吃。落点在 Task 2 的 `test_catch_requires_release`。

---

## 文件结构

| 文件 | 职责 |
|---|---|
| `game/config.gd`（改） | 加 v2 全部常量（回合、视线、AI、币价、路径） |
| `game/minigame/gaze.gd`（新） | `Gaze`：老师视线状态机 `AWAY → WARN → WATCH`，扇形判定，锥透明度 |
| `game/minigame/steal_eat.gd`（新） | `StealEat`：四座位的口数/罚站/出局/胜负/结算，纯模型 |
| `game/minigame/npc_seat.gd`（新） | `NpcSeat`：胆量 + 反应延迟 + 赌一口 + 发呆 |
| `game/systems/save.gd`（新） | `Save`：`user://save.cfg` 读写（币、是否拥有、是否穿戴） |
| `game/skins/skin.gd`（新） | `Skin`：`Resource`，三个字段（帽色、身色、斑点密度） |
| `game/skins/blueberry.tres`（新） | 唯一一顶皮肤的数据 |
| `game/minigame/classroom.tscn` + `classroom.gd`（新） | 教室场景：几何、相机、灯、回合编排、触摸输入 |
| `game/minigame/teacher.gd`（新） | 老师外观 + 地面扇形锥 + 转头（读数 `Gaze`） |
| `game/minigame/seat_visual.gd`（新） | 一个座位：课桌 + 蘑菇 + 头顶进度条 + 弹动/罚站/出局姿态 |
| `game/minigame/classroom_ui.tscn` + `classroom_ui.gd`（新） | 教室 HUD（时间、口数、被抓）+ 结算面板 + 两个按钮 |
| `game/world/stall.gd`（新） | 森林摊位：柜台 + 老板 + 触发区，`add_to_group("stall")` |
| `game/world/door.gd`（新） | 森林校门：门框 + 地面进度圈，站 1 秒进教室 |
| `game/ui/shop_panel.gd`（新） | 商店浮层：币数、价格、买 |
| `game/player/player.gd`（改） | 加入 `player` 组、`apply_skin()` |
| `game/world/forest.tscn`（改） | 加 `Stall`、`ClassroomDoor` 两个节点 |
| `game/main.tscn`（改） | 加 `ShopPanel` 浮层 |
| `tests/test_gaze.gd`、`test_steal_eat.gd`、`test_npc_seat.gd`、`test_coins.gd`（新） | 纯逻辑测试 |
| `AGENTS.md`、`CLAUDE.md`、`docs/perf-log.md`、`docs/superpowers/specs/…`（改） | 收尾：命令、真机数据、spec 状态 |

---
### Task 1: 老师视线模型 `Gaze`

**Files:**
- Modify: `game/config.gd`
- Create: `game/minigame/gaze.gd`、`tests/test_gaze.gd`

**Interfaces:**
- Consumes: `Config`
- Produces:
  - `Gaze`（`class_name Gaze extends RefCounted`），`enum Phase { AWAY, WARN, WATCH }`
  - `Gaze.new(seed_value: int = 1)` — 起手在 `AWAY`，`time_left` 已掷好，`target` 已选
  - 字段 `phase: int`、`target: int`、`time_left: float`
  - `advance(delta: float) -> void` — 跨过阶段边界，可一次跨多个阶段
  - `watching() -> int` — `WATCH` 时返回 `target`，否则 `-1`
  - `alpha() -> float` — 锥透明度：`AWAY` 为 0，`WARN` 在 0.15→0.5 之间按剩余时间插值，`WATCH` 为 0.55
  - `static seen(apex: Vector3, yaw: float, point: Vector3, half_angle_deg: float, range_m: float) -> bool` — 水平面内角度差 + 距离判定
  - `static yaw_to(apex: Vector3, point: Vector3) -> float` — `atan2(dx, dz)`

- [ ] **Step 1: `game/config.gd` 加 v2 常量**

```gdscript
# v2 教室偷吃
const SEAT_COUNT := 4
const ROUND_SECONDS := 90.0
const BITES_TO_WIN := 20
const BITE_SECONDS := 1.6
const CATCH_GRACE := 0.1
const STUN_SECONDS := 3.0
const MAX_CAUGHT := 3
const GAZE_AWAY_MIN := 2.0
const GAZE_AWAY_MAX := 5.0
const GAZE_WARN := 0.3
const GAZE_WATCH := 2.0
const GAZE_HALF_ANGLE := 14.0
const GAZE_RANGE := 5.5
const SEAT_POSITIONS := [
	Vector3(-1.2, 0.0, 1.2), Vector3(-4.0, 0.0, 0.6), Vector3(1.6, 0.0, 0.6), Vector3(4.2, 0.0, 1.2)
]
const TEACHER_POS := Vector3(0.0, 0.0, -5.5)
# v2 人机
const NPC_GUTS := [0.15, 0.35, 0.55]
const NPC_REACTION_MIN := 0.15
const NPC_REACTION_MAX := 0.60
const NPC_GAMBLE := 0.25
const NPC_IDLE_CHANCE := 0.25
# v2 蘑菇币
const COIN_BASE := 10
const COIN_PER_BITE := 3
const COIN_WIN_BONUS := 40
const COIN_PER_CATCH := 5
const SKIN_PRICE := 200
const SKIN_PATH := "res://game/skins/blueberry.tres"
const CLASSROOM_PATH := "res://game/minigame/classroom.tscn"
const FOREST_PATH := "res://game/main.tscn"
```

- [ ] **Step 2: 写失败测试 `tests/test_gaze.gd`**

```gdscript
extends TestBase

func test_away_length_in_range() -> void:
	for i in 20:
		var g := Gaze.new(i + 1)
		check(
			g.time_left >= Config.GAZE_AWAY_MIN and g.time_left <= Config.GAZE_AWAY_MAX,
			"AWAY 时长落在 2~5 秒 (%f)" % g.time_left
		)

func test_warn_then_watch_then_away() -> void:
	var g := Gaze.new(1)
	g.advance(g.time_left)
	check_eq(g.phase, Gaze.Phase.WARN, "看黑板结束后进入预警")
	check_eq(g.watching(), -1, "预警阶段不算被看到")
	g.advance(Config.GAZE_WARN)
	check_eq(g.phase, Gaze.Phase.WATCH, "预警 0.3 秒后进入盯视")
	check_eq(g.watching(), g.target, "盯视阶段只有目标座位被看到")
	g.advance(Config.GAZE_WATCH)
	check_eq(g.phase, Gaze.Phase.AWAY, "盯完回到看黑板")

func test_target_changes_between_rounds() -> void:
	var g := Gaze.new(5)
	var seen := {}
	for i in 12:
		g.advance(g.time_left)
		seen[g.target] = true
		g.advance(Config.GAZE_WARN + Config.GAZE_WATCH)
	check(seen.size() >= 2, "目标座位不是永远同一个")

func test_seen_cone() -> void:
	var apex := Vector3.ZERO
	check(Gaze.seen(apex, 0.0, Vector3(0, 0, 3), 14.0, 5.5), "正前方 3m 在锥内")
	check(not Gaze.seen(apex, 0.0, Vector3(0, 0, 6), 14.0, 5.5), "超出 5.5m 看不到")
	check(not Gaze.seen(apex, 0.0, Vector3(3, 0, 3), 14.0, 5.5), "45° 偏角看不到")
	check(Gaze.seen(apex, 0.0, Vector3(0.6, 0, 3), 14.0, 5.5), "11° 偏角还在锥内")

func test_alpha_by_phase() -> void:
	var g := Gaze.new(2)
	check_eq(g.alpha(), 0.0, "看黑板时锥不可见")
	g.advance(g.time_left)
	check(g.alpha() > 0.0 and g.alpha() < 0.55, "预警阶段半透明")
	g.advance(Config.GAZE_WARN)
	check(g.alpha() >= 0.5, "盯视阶段最实")

func test_big_delta_crosses_phases_once() -> void:
	var g := Gaze.new(3)
	g.advance(1000.0)
	check(g.phase != Gaze.Phase.WATCH or g.watching() == g.target, "大 delta 不把状态机卡在矛盾状态")
```

- [ ] **Step 3: 跑测试确认失败**

Run: `bash scripts/test.sh`
Expected: FAIL（`Gaze` 未定义，`test_gaze.gd` 报无法加载或运行时错误）

- [ ] **Step 4: 实现 `game/minigame/gaze.gd`**

状态机（`advance` 用一个 `while remaining > 0.0` 消化剩余时间，避免大 delta 卡死）：`AWAY` 到点 → 掷新 `target`（`randi() % Config.SEAT_COUNT`，不要求与上一轮不同）、`phase = WARN`、`time_left = Config.GAZE_WARN`；`WARN` 到点 → `WATCH`、`time_left = Config.GAZE_WATCH`；`WATCH` 到点 → `AWAY`、`time_left = randf_range(GAZE_AWAY_MIN, GAZE_AWAY_MAX)`。判定阶段边界要用 `time_left <= remaining`（相等也算跨过），否则 `advance(g.time_left)` 这类正好卡在边界的调用推不动状态机；`while` 每轮最多转 8 次防死循环。`_rng: RandomNumberGenerator` 在 `_init` 里 `seed = seed_value`。

- [ ] **Step 5: 跑测试确认通过**

Run: `bash scripts/test.sh`
Expected: 全部 PASS，失败 0

- [ ] **Step 6: 提交**

```bash
git add game/config.gd game/minigame/gaze.gd tests/test_gaze.gd
git commit -m "老师视线状态机：看黑板、0.3 秒预警、2 秒盯视"
```

---
### Task 2: 回合规则模型 `StealEat`

**Files:**
- Create: `game/minigame/steal_eat.gd`、`tests/test_steal_eat.gd`

**Interfaces:**
- Consumes: `Config`
- Produces（`class_name StealEat extends RefCounted`）：
  - `class Seat`（内部类，`RefCounted`）：`bites: int`、`fill: float`、`caught: int`、`stun: float`、`sight: float`、`needs_release: bool`、`out: bool`
  - `StealEat.new(count: int = Config.SEAT_COUNT)`；字段 `seats: Array`（元素是 `StealEat.Seat`）、`time_left: float`、`over: bool`、`winner: int`
  - `tick(delta: float, press: Array, watched: int) -> Dictionary` — `press` 是 4 个 `bool`；`watched` 是老师正在盯的座位号，`-1` 表示没人被盯。返回 `{"chomped": Array[bool], "caught": Array[bool], "over": bool, "winner": int}`（`over`/`winner` 是 tick 之后的当前值）
  - `decide_winner() -> int` — 口数最多 → 被抓次数最少 → 座位号小（座位 0 是玩家，所以完全并列时玩家赢）
  - `static coins(bites: int, is_winner: bool, caught: int) -> int` — 上面 §3 的公式

- [ ] **Step 1: 写失败测试 `tests/test_steal_eat.gd`**

```gdscript
extends TestBase

const HOLD := [true, false, false, false]
const IDLE := [false, false, false, false]

func _feed(r: StealEat, press: Array, watched: int, seconds: float, step := 1.0 / 60.0) -> void:
	# step 必须 ≤ 1/30，否则 tick 内部的 delta 夹取会让实际推进的时间小于循环计数的时间
	var t := 0.0
	while t < seconds:
		r.tick(step, press, watched)
		t += step

func test_hold_one_bite() -> void:
	var r := StealEat.new(4)
	_feed(r, HOLD, -1, Config.BITE_SECONDS + 0.05)
	check_eq(r.seats[0].bites, 1, "按住 1.6 秒吃满一口")

func test_release_resets_fill() -> void:
	var r := StealEat.new(4)
	_feed(r, HOLD, -1, 1.0)
	_feed(r, IDLE, -1, 0.1)
	check_eq(r.seats[0].bites, 0, "没吃满就松手不加口数")
	check(absf(r.seats[0].fill) < 0.0001, "松手口内进度清零")

func test_catch_needs_grace() -> void:
	var r := StealEat.new(4)
	_feed(r, HOLD, 0, Config.CATCH_GRACE * 0.5)
	check_eq(r.seats[0].caught, 0, "宽限内不算被抓")
	_feed(r, HOLD, 0, 0.06)
	check_eq(r.seats[0].caught, 1, "被看到超过 0.1 秒被抓")
	check(absf(r.seats[0].stun - Config.STUN_SECONDS) < 0.0001, "罚站 3 秒")
	check(absf(r.seats[0].fill) < 0.0001, "被抓打断这一口")

func test_unwatched_never_caught() -> void:
	var r := StealEat.new(4)
	_feed(r, HOLD, 1, 5.0)
	check_eq(r.seats[0].caught, 0, "老师盯着别人时随便吃")

func test_stun_blocks_eating() -> void:
	var r := StealEat.new(4)
	_feed(r, HOLD, 0, 0.2)
	_feed(r, HOLD, -1, 1.0)
	check_eq(r.seats[0].bites, 0, "罚站期间按住也不吃")

func test_catch_requires_release() -> void:
	var r := StealEat.new(4)
	_feed(r, HOLD, 0, 0.2)
	check_eq(r.seats[0].caught, 1, "第一次被抓")
	_feed(r, HOLD, 0, Config.STUN_SECONDS + 1.0)
	check_eq(r.seats[0].caught, 1, "罚站结束后一直按着不会连环被抓")
	_feed(r, IDLE, 0, 0.1)
	_feed(r, HOLD, 0, 0.3)
	check_eq(r.seats[0].caught, 2, "松手再按才会重新被抓")

func test_three_catches_out() -> void:
	var r := StealEat.new(4)
	for i in Config.MAX_CAUGHT:
		_feed(r, HOLD, 0, 0.2)
		_feed(r, IDLE, 0, Config.STUN_SECONDS + 0.1)
	check(r.seats[0].out, "被抓 3 次出局")
	_feed(r, HOLD, -1, 5.0)
	check_eq(r.seats[0].bites, 0, "出局后吃不了")

func test_win_at_n_bites() -> void:
	var r := StealEat.new(4)
	r.seats[0].bites = Config.BITES_TO_WIN - 1
	r.seats[0].fill = Config.BITE_SECONDS - 0.05
	_feed(r, HOLD, -1, 0.1)
	check(r.over, "吃满 N 口立刻结束")
	check_eq(r.winner, 0, "先吃满的赢")

func test_clock_winner_by_progress() -> void:
	var r := StealEat.new(4)
	r.seats[1].bites = 5
	r.seats[2].bites = 3
	r.time_left = 0.05
	_feed(r, IDLE, -1, 0.2)
	check(r.over, "时间到结束")
	check_eq(r.winner, 1, "进度最高者赢")

func test_tie_break_fewer_catches_then_player() -> void:
	var r := StealEat.new(4)
	r.seats[0].bites = 5
	r.seats[1].bites = 5
	r.seats[1].caught = 2
	check_eq(r.decide_winner(), 0, "同口数比少被抓")

func test_big_delta_clamped() -> void:
	var r := StealEat.new(4)
	r.tick(0.5, HOLD, -1)
	check_eq(r.seats[0].bites, 0, "0.5 秒的 delta 不会瞬间吃完一口")
	check(absf(r.seats[0].fill - 1.0 / 30.0) < 0.0001, "单帧只推进 1/30 秒")

func test_coins_formula() -> void:
	check_eq(StealEat.coins(20, true, 0), 110, "满分一局")
	check_eq(StealEat.coins(12, false, 1), 41, "典型一局")
	check_eq(StealEat.coins(0, false, 3), 0, "扣成负数夹到 0")
```

- [ ] **Step 2: 跑测试确认失败** → FAIL（`StealEat` 未定义）。

- [ ] **Step 3: 实现 `game/minigame/steal_eat.gd`**

`tick` 的规则顺序是这个文件唯一不确定的部分，按此实现（`d := minf(delta, 1.0/30.0)`）：

1. `if over: return` 原地返回（`chomped`/`caught` 全 false）。
2. `time_left -= d`。
3. 每个座位依次：
   - `stun = maxf(0.0, stun - d)`；`if not press[i]: needs_release = false`
   - `eating = press[i] and stun <= 0.0 and not needs_release and not out`
   - 不 `eating` → `fill = 0.0`、`sight = 0.0`，结束这个座位
   - `fill += d`；`sight = sight + d if watched == i else 0.0`
   - `if sight > Config.CATCH_GRACE`：`caught += 1`、`stun = Config.STUN_SECONDS`、`fill = 0`、`sight = 0`、`needs_release = true`、`caught[i] = true`；`if caught >= Config.MAX_CAUGHT: out = true`
   - `elif fill >= Config.BITE_SECONDS`：`fill -= Config.BITE_SECONDS`、`bites += 1`、`chomped[i] = true`；`if bites >= Config.BITES_TO_WIN: over = true; winner = i`
4. 循环结束：`if not over and time_left <= 0.0: over = true; winner = decide_winner()`
5. 返回字典。

- [ ] **Step 4: 跑测试确认通过** → 全部 PASS。

- [ ] **Step 5: 提交**

```bash
git add game/minigame/steal_eat.gd tests/test_steal_eat.gd
git commit -m "回合规则：一口要按住吃满，被看到罚站，吃满或时间到定胜负"
```

---
### Task 3: 人机决策 `NpcSeat`

**Files:**
- Create: `game/minigame/npc_seat.gd`、`tests/test_npc_seat.gd`

**Interfaces:**
- Consumes: `Config`、`Gaze`
- Produces（`class_name NpcSeat extends RefCounted`）：
  - `NpcSeat.new(guts_value: float, seed_value: int)`
  - `decide(delta: float, gaze: Gaze, seat: int, stunned: bool) -> bool` — 这一帧要不要按住吃。返回 `true` 才喂给 `StealEat.tick` 的 `press[seat]`
  - 内部状态：`_seen: float`（本座位被盯了多久）、`_delay: float`（本次允许撑多久）、`_rest: float`（松手后缓多久，发呆就靠把它拉长）

- [ ] **Step 1: 写失败测试 `tests/test_npc_seat.gd`**

```gdscript
extends TestBase

func _gaze(seat: int, phase: int) -> Gaze:
	var g := Gaze.new(3)
	g.phase = phase
	g.target = seat
	g.time_left = 99.0
	return g

func test_mostly_releases_before_danger_line() -> void:
	var safe := 0
	for seed_value in range(1, 11):
		if _time_to_release(Config.NPC_GUTS[0], seed_value) <= Config.GAZE_WARN + Config.CATCH_GRACE:
			safe += 1
	check(safe >= 8, "怂的人 10 次里至少 8 次在危险线前松手（偶尔手滑才对），实得 %d" % safe)

func test_ignores_other_seats() -> void:
	var g := _gaze(2, Gaze.Phase.WATCH)
	var npc := NpcSeat.new(Config.NPC_GUTS[2], 4)
	var pressed := false
	for i in 10:
		pressed = npc.decide(0.05, g, 1, false)
	check(pressed, "老师盯别人时自己一直在吃")

func test_guts_trade_more_delay() -> void:
	check(_avg_release(Config.NPC_GUTS[2]) > _avg_release(Config.NPC_GUTS[0]), "胆量越大平均越晚松手")

func _avg_release(guts: float) -> float:
	var sum := 0.0
	for seed_value in range(1, 11):
		sum += _time_to_release(guts, seed_value)
	return sum / 10.0

func _time_to_release(guts: float, seed_value: int) -> float:
	var g := _gaze(1, Gaze.Phase.WARN)
	var npc := NpcSeat.new(guts, seed_value)
	var t := 0.0
	while t < 2.0:
		g.phase = Gaze.Phase.WARN if t < Config.GAZE_WARN else Gaze.Phase.WATCH
		if not npc.decide(0.05, g, 1, false):
			return t
		t += 0.05
	return 2.0

func test_seeds_desync() -> void:
	var times := {}
	for seed_value in range(1, 9):
		times[_time_to_release(0.35, seed_value)] = true
	check(times.size() >= 2, "八次里至少两种松手时刻，不是一根木头")

func test_stunned_never_presses() -> void:
	var g := _gaze(1, Gaze.Phase.AWAY)
	var npc := NpcSeat.new(0.5, 9)
	check(not npc.decide(0.05, g, 1, true), "罚站时不按")

func test_rest_gap_after_release() -> void:
	var g := _gaze(1, Gaze.Phase.WATCH)
	var npc := NpcSeat.new(0.15, 5)
	var t := 0.0
	while t < 2.0 and npc.decide(0.05, g, 1, false):
		t += 0.05
	check(t < 2.0, "被盯久了总会松手")
	g.target = 0                     # 视线移走
	check(not npc.decide(0.01, g, 1, false), "刚松手会缓一下才重新开吃")
```

- [ ] **Step 2: 跑测试确认失败** → FAIL（`NpcSeat` 未定义）。

- [ ] **Step 3: 实现 `game/minigame/npc_seat.gd`**

只有 `_seen` / `_delay` / `_rest` 三个状态。「发呆」不单独占一个字段，就是一段更长的 `_rest`，这样少一个分支也少一个测试。`decide` 每帧：

1. `if stunned: _seen = 0.0; return false`
2. 本座位没被盯（`gaze.target != seat` 或 `gaze.phase == Gaze.Phase.AWAY`）：`_seen = 0.0`；若 `_rest > 0` 则 `_rest = maxf(0.0, _rest - delta)`，并且**在 `_rest` 刚归零的那一帧**掷一次发呆（`if _rng.randf() < Config.NPC_IDLE_CHANCE: _rest = _rng.randf_range(0.8, 1.6)`）；返回 `_rest <= 0.0`
3. 被盯：`if _seen == 0.0` 时掷 `_delay = lerpf(Config.NPC_REACTION_MIN, Config.NPC_REACTION_MAX, guts) * _rng.randf_range(0.8, 1.2)`，再 `if _rng.randf() < guts * Config.NPC_GAMBLE: _delay += Config.GAZE_WARN`。`_seen += delta`；`_seen < _delay` → `true`，否则（`_rest <= 0` 时才重新掷，别每帧重掷）`_rest = _rng.randf_range(0.1, 0.3)` 并返回 `false`

刚 `new()` 出来时 `_rest == 0`，所以第 1 帧就在吃（`test_ignores_other_seats` 依赖这一点）。

- [ ] **Step 4: 跑测试确认通过** → 全部 PASS。

- [ ] **Step 5: 提交**

```bash
git add game/minigame/npc_seat.gd tests/test_npc_seat.gd
git commit -m "三个同学的性格：胆量决定反应延迟，偶尔赌一口、偶尔发呆"
```

---
### Task 4: 蘑菇币与存档

**Files:**
- Create: `game/systems/save.gd`、`tests/test_coins.gd`
- Modify: `game/minigame/steal_eat.gd`（若 `coins()` 还在里面就保持不动，`Save` 不重复实现公式）

**Interfaces:**
- Consumes: `Config`、`StealEat.coins()`
- Produces（`class_name Save`）：
  - `const PATH := "user://save.cfg"`
  - `static read(path: String = PATH) -> Dictionary` — 恒返回 `{"coins": int, "owned": bool, "equipped": bool}`，文件不存在给默认（0 / false / false）
  - `static write(path: String, data: Dictionary) -> void`
  - `static add_coins(amount: int, path: String = PATH) -> int` — 读、加起来、夹到 `>= 0`、写回、返回新余额
  - `static apply_round(bites: int, is_winner: bool, caught: int, path: String = PATH) -> Dictionary` — 结算并返回 `{"earned": int, "coins": int}`

- [ ] **Step 1: 写失败测试 `tests/test_coins.gd`**

```gdscript
extends TestBase

const P := "user://test_save.cfg"

func _clean() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(P))

func test_missing_file_defaults() -> void:
	_clean()
	var d := Save.read(P)
	check_eq(d.coins, 0, "没有存档时币为 0")
	check(not d.owned and not d.equipped, "没有存档时没皮肤")

func test_roundtrip() -> void:
	_clean()
	Save.write(P, {"coins": 120, "owned": true, "equipped": true})
	var d := Save.read(P)
	check_eq(d.coins, 120, "币存得住")
	check(d.owned and d.equipped, "皮肤状态存得住")
	_clean()

func test_add_coins_clamps_at_zero() -> void:
	_clean()
	Save.write(P, {"coins": 5, "owned": false, "equipped": false})
	check_eq(Save.add_coins(-200, P), 0, "买不起时不会变成负数")
	_clean()

func test_apply_round_earns() -> void:
	_clean()
	var r := Save.apply_round(12, false, 1, P)
	check_eq(r.earned, StealEat.coins(12, false, 1), "结算用的是同一个公式")
	check_eq(Save.read(P).coins, r.earned, "结算后币入库")
	_clean()
```

- [ ] **Step 2: 跑测试确认失败** → FAIL（`Save` 未定义）。

- [ ] **Step 3: 实现 `game/systems/save.gd`**

用 `ConfigFile`（`load`/`set_value`/`save`），一个 `[game]` 段。`read` 里用 `get_value` 的默认参数兜底，不做异常分支。`apply_round` 内部 `add_coins(StealEat.coins(...))`。

- [ ] **Step 4: 跑测试确认通过** → 全部 PASS。确认 `user://test_save.cfg` 没留在项目里。

- [ ] **Step 5: 提交**

```bash
git add game/systems/save.gd tests/test_coins.gd
git commit -m "蘑菇币结算与本地存档"
```

---
### Task 5: 教室场景与观感

**Files:**
- Create: `game/minigame/classroom.tscn`、`game/minigame/classroom.gd`、`game/minigame/teacher.gd`、`game/minigame/seat_visual.gd`
- Modify: `game/main.tscn`（临时把启动场景指到 `classroom.tscn` 看效果，Task 9 改回来）

**Interfaces:**
- Consumes: `Config.SEAT_POSITIONS`、`Config.TEACHER_POS`、`MushroomMesh`、`Gaze`
- Produces:
  - `Teacher`（`class_name Teacher extends Node3D`），`func apply(gaze: Gaze, delta: float) -> void` — 转头 + 锥的朝向/颜色/透明度
  - `SeatVisual`（`class_name SeatVisual extends Node3D`），`func setup(index: int) -> void`、`func apply(seat: StealEat.Seat, eating: bool, delta: float) -> void`
  - `classroom.tscn` 根节点 `Classroom`（`Node3D` + `classroom.gd`），固定 `Camera3D` 位置 `Vector3(0, 3.2, 6.0)`，看向 `Vector3(0, 0.8, -1.5)`

- [ ] **Step 1: 教室几何**

`classroom.gd` 的 `_ready` 里按 v1 `Terrain`/`ForestGen` 的写法程序化建（不手写 .tscn 布局）：地板 `BoxMesh` 14×0.2×12（暖木色）、后墙与侧墙 3 块 `BoxMesh`（米色）、黑板 `BoxMesh` 6×2.6×0.1 深绿贴在 `TEACHER_POS` 后面、天花板 1 块。光照：`DirectionalLight3D`（`shadow_enabled`、`directional_shadow_max_distance = 20`）+ `WorldEnvironment`（`ProceduralSkyMaterial`，不开 fog）。

- [ ] **Step 2: 座位与课桌**

4 个 `SeatVisual` 放在 `Config.SEAT_POSITIONS`。每个座位建：课桌（`BoxMesh` 1.7×0.08×0.85 @ y=0.78 + 一块 1.4×0.75×0.7 的桌身）、一个 `MushroomMesh`（缩放 0.9，四个不同 tint：玩家红、同学青/黄/紫）、头顶两根 billboard `QuadMesh` 做进度条（底条深灰 1.0×0.14，填充条亮绿，`scale.x = 进度`，`y = 2.1`）。阴影只对玩家课桌与角色开（`cast_shadow` 默认即可）。

- [ ] **Step 3: 老师与锥**

`teacher.gd`：一个 `MushroomMesh`（缩放 1.5，深灰帽）站在 `Config.TEACHER_POS` 后面；地面扇形用 `SurfaceTool` 生成 12 段三角扇（apex 在原点、半径 `Config.GAZE_RANGE`、半角 `Config.GAZE_HALF_ANGLE`），材质 `StandardMaterial3D`：`shading_mode = UNSHADED`、`transparency = TRANSPARENCY_ALPHA`、`cull_mode = CULL_DISABLED`、`albedo_color.a` 由 `gaze.alpha()` 写、`WATCH` 时 `Color(1, 0.25, 0.2)`、`WARN` 时 `Color(1, 0.85, 0.3)`。`apply`：`rotation.y = lerp_angle(rotation.y, Gaze.yaw_to(global_position, Config.SEAT_POSITIONS[gaze.target]), minf(1.0, 12.0 * delta))`；锥的 `rotation.y` 同步。

- [ ] **Step 4: 桌面看效果（人工判断，不自动化）**

Run: `godot --path .`
Expected: 一眼看懂「四个学生、一张黑板、老师站在前面」；把 `classroom.gd` 里临时加一个 `Engine.time_scale = 0.3` 或直接手动调用 `_gaze.advance`，确认锥会亮黄 → 转红 → 消失，且转过去的那个座位和锥覆盖的座位是同一个。

- [ ] **Step 5: 真机看构图（人工）**

```bash
godot --headless --path . --export-debug "Android" build/app.apk
adb install -r build/app.apk
adb shell monkey -p com.tuzki.fungiparty -c android.intent.category.LAUNCHER 1
adb exec-out screencap -p > shots/v2-classroom.png
```
Expected: 四个座位全在画面内、老师与锥可见、没有黑屏/穿墙。构图不对就调 `Camera3D` 的 position/rotation，别调座位（座位是判定用的世界坐标）。

- [ ] **Step 6: 提交**

```bash
git add game/minigame game/main.tscn
git commit -m "教室场景：四张课桌、老师与地面视线锥"
```

---
### Task 6: 回合循环与结算面板

**Files:**
- Create: `game/minigame/classroom_ui.tscn`、`game/minigame/classroom_ui.gd`
- Modify: `game/minigame/classroom.gd`

**Interfaces:**
- Consumes: `Gaze`、`StealEat`、`NpcSeat`、`Save`、`Config`、`SeatVisual`、`Teacher`
- Produces:
  - `ClassroomUI`（`class_name ClassroomUI extends CanvasLayer`）：`func set_state(time_left: float, bites: int, caught: int, stunned: bool) -> void`、`func show_result(bites: int, caught: int, won: bool, earned: int) -> void`、`信号 again_pressed`、`信号 forest_pressed`
  - `EatInput`（`class_name EatInput extends RefCounted`）：`var finger := -1`、`static func next_finger(current: int, index: int, pressed: bool) -> int`、`func pressing() -> bool`
  - `classroom.gd`：`_ready` 建 `_gaze`/`_round`/`_npcs`/`_ui`，`_process` 驱动一帧

- [ ] **Step 1: `EatInput` + 它的测试**

`tests/test_eat_input.gd`：

```gdscript
extends TestBase

func test_tracks_finger() -> void:
	var f := EatInput.next_finger(-1, 2, true)
	check_eq(f, 2, "按下记住手指")
	check_eq(EatInput.next_finger(f, 0, true), 2, "别的手指按下不影响")
	check_eq(EatInput.next_finger(f, 2, false), -1, "记住的那根抬起才松手")
	check_eq(EatInput.next_finger(f, 0, false), 2, "别的手指抬起不算松手")
```

- [ ] **Step 2: 写 `classroom_ui`**

`Theme`：`SystemFont`，`font_names = PackedStringArray(["Noto Sans CJK SC", "Noto Sans SC", "Droid Sans Fallback", "sans-serif"])`、`allow_system_fallback = true`，设到根 `Control.theme`。HUD 左上角一个 `Label`：`时间 %d  吃了 %d/%d  被抓 %d/%d`；罚站时在屏幕中央加一句「罚站中」。结算面板：一个半透明 `ColorRect` + `Label`（`赢了！/ 时间到` + `吃了 X 口，被抓 Y 次，+Z 蘑菇币`）+ 两个 `Button`（「再来一局」「回森林」）分别 `emit_signal`。

- [ ] **Step 3: 在 `classroom.gd` 里接上每帧循环**

`_process(delta)`：`_gaze.advance(delta)` → `_teacher.apply(_gaze, delta)` → 玩家 `press[0] = EatInput.pressing() or Input.is_action_pressed("jump")`（桌面用空格按住）→ 三个人机 `press[i] = _npcs[i].decide(delta, _gaze, i, _round.seats[i].stun > 0.0)` → `var ev := _round.tick(delta, press, _gaze.watching())` → 按 `ev.chomped` / `ev.caught` 给对应 `SeatVisual` 播弹动/红晕 → `_ui.set_state(...)` → `if _round.over and not _settled: _settled = true; var earned := Save.apply_round(...).earned; _ui.show_result(...)`。被抓时全屏红晕：一个 `ColorRect`，`modulate.a` 从 0.15 在 0.3 秒内 tween 到 0。触摸输入：`_input` 里把 `InputEventScreenTouch` 喂给 `EatInput`。

- [ ] **Step 4: 桌面跑一局**

Run: `godot --path .`，按住空格吃、看锥变红前松手。
Expected: 能吃满口数；被看到会罚站 3 秒、进度条清零、角色直立；吃满 20 口或 90 秒后弹结算面板。

- [ ] **Step 5: 真机验证中文与手势**

导出装机，进教室按住屏幕一局，截图存 `shots/v2-hud.png`。
Expected: 中文正常显示（不是方块）；按住时手指滑到屏幕边缘仍算按住；结算面板两个按钮都能点。若中文是方块，落 Plan B：下载 OFL 的 `NotoSansSC-Regular.otf` 到 `art/fonts/`，`godot --headless --path . --editor --quit` 导入，`Theme.default_font` 换成 `load("res://art/fonts/NotoSansSC-Regular.otf")`。

- [ ] **Step 6: 提交**

```bash
git add game/minigame tests/test_eat_input.gd
git commit -m "教室回合循环：按住吃、松手装样子、结算面板"
```

---
### Task 7: 一顶皮肤

**Files:**
- Create: `game/skins/skin.gd`、`game/skins/blueberry.tres`
- Modify: `game/player/player.gd`

**Interfaces:**
- Consumes: `Save`、`Config.SKIN_PATH`
- Produces:
  - `Skin`（`class_name Skin extends Resource`）：`@export var tint_cap: Color`、`@export var tint_body: Color`、`@export var spot_count: int`
  - `Player.apply_skin() -> void` — 读存档，`equipped` 为真则把 `Skin` 的三个字段写进 `$MushroomMesh` 后 `build()`
  - `player.gd` 在 `_ready` 里 `add_to_group("player")` 并调用 `apply_skin()`

- [ ] **Step 1: 写 `Skin` + `blueberry.tres`**

```gdscript
class_name Skin
extends Resource

@export var tint_cap := Color(0.90, 0.22, 0.20)
@export var tint_body := Color(0.96, 0.78, 0.62)
@export var spot_count := 7
```
`blueberry.tres`：`[gd_resource type="Resource" script_class="Skin" format=3]`，帽 `Color(0.35, 0.45, 0.95)`、身 `Color(0.86, 0.90, 0.98)`、斑点 9。

- [ ] **Step 2: `Player.apply_skin()`**

`if not Save.read().equipped: return`；`var skin := load(Config.SKIN_PATH) as Skin`；`if skin == null: return`；写到 `$MushroomMesh` 的两个 tint 与 `spot_count`，然后 `$MushroomMesh.build()`。注意 `MushroomMesh._ready` 已经 build 过一次，这里是第二次（`build()` 可重入，v1 有测试），不要为了省这一次去改 `_ready` 顺序。

- [ ] **Step 3: 桌面验证**

手动把存档写成 `equipped = true`（临时在 `player.gd` 里 `Save.write(Save.PATH, {"coins": 0, "owned": true, "equipped": true})` 跑一次，然后删掉这段），`godot --path .`。
Expected: 角色是蓝帽 + 浅蓝身体 + 9 个斑点；删掉存档恢复红帽。

- [ ] **Step 4: 提交**

```bash
git add game/skins game/player/player.gd
git commit -m "皮肤做成数据：一顶蓝莓帽"
```

---
### Task 8: 森林里的摊位与商店

**Files:**
- Create: `game/world/stall.gd`、`game/ui/shop_panel.gd`
- Modify: `game/world/forest.tscn`（加 `Stall` 节点，位置 `Vector3(7, 0, -11)`）、`game/main.tscn`（加 `ShopPanel` 节点）

**Interfaces:**
- Consumes: `Save`、`Config.SKIN_PRICE`/`SKIN_PATH`、`Player.apply_skin()`
- Produces:
  - `Stall`（`class_name Stall extends Node3D`）：`var player_inside := false`，`_ready` 里 `add_to_group("stall")`
  - `ShopPanel`（`extends CanvasLayer`）：每帧惰性 `get_tree().get_first_node_in_group("stall")`；`player_inside` 为真时显示

- [ ] **Step 1: 建摊位**

`stall.gd` 的 `_ready` 程序化建：柜台 `BoxMesh` 2.4×0.9×0.8（深木色）、顶棚 `BoxMesh` 3.0×0.12×2.0 @ y=2.3（布色）+ 4 根 0.08×2.3×0.08 柱子、老板一个 `MushroomMesh`（缩放 0.85、黄帽）站在柜台后、`Area3D` + `BoxShape3D` 3.4×2.0×3.4 包住柜台前。`body_entered`/`body_exited` 里用 `body is Player` 判，设 `player_inside`。

- [ ] **Step 2: 商店浮层**

`shop_panel.gd` 建 `Control` + `Panel` + `Label` + `Button`（同 `SystemFont` 主题）：显示「蘑菇币 %d」和「蓝莓帽 · 200 币」；买不起时 `Button.disabled = true` 且文案「还差 %d 币」；已拥有时文案「已戴上」且按钮隐藏。买：`Save.add_coins(-Config.SKIN_PRICE)`、`Save.write(Save.PATH, {"coins": 余额, "owned": true, "equipped": true})`、`(get_tree().get_first_node_in_group("player") as Player).apply_skin()`。

- [ ] **Step 3: 桌面验证**

`godot --path .`：走到摊位前浮层出现、走开消失；把存档币改成 250 再走近，点买 → 币变 50、面板文案变「已戴上」、角色立刻变蓝。

- [ ] **Step 4: 真机验证**

截 `shots/v2-shop.png`。
Expected: 面板不被安全区压住、中文正常、按钮点得中。

- [ ] **Step 5: 提交**

```bash
git add game/world/stall.gd game/ui/shop_panel.gd game/world/forest.tscn game/main.tscn
git commit -m "森林摊位与商店：用蘑菇币买蓝莓帽"
```

---
### Task 9: 校门、往返与收尾

**Files:**
- Create: `game/world/door.gd`
- Modify: `game/world/forest.tscn`（加 `ClassroomDoor` 节点，位置 `Vector3(0, 0, -14)`）、`game/main.tscn`、`AGENTS.md`、`CLAUDE.md`、`docs/perf-log.md`、`docs/superpowers/specs/2026-10-17-fungi-party-design.md`（状态一行）

**Interfaces:**
- Consumes: `Config.CLASSROOM_PATH`、`Config.FOREST_PATH`
- Produces: `ClassroomDoor`（`class_name ClassroomDoor extends Node3D`）

- [ ] **Step 1: 建校门**

门框两根柱子 + 门楣 + 门楣上一块深绿「黑板」；地面一个 `CylinderMesh`（半径 0.9、高 0.02）当进度圈，`scale = 0.1 + 0.9 * hold`。`_physics_process`：`Area3D` 里有 `Player` → `hold += delta`，`hold >= 1.0` → `get_tree().change_scene_to_file(Config.CLASSROOM_PATH)`；否则 `hold = 0.0`。用区域内的 body 计数（`get_overlapping_bodies()` 里有没有 `Player`），别缓存进入事件（场景往返后信号连接会旧）。

- [ ] **Step 2: 结算面板的「回森林」接上**

`classroom_ui` 的 `forest_pressed` → `get_tree().change_scene_to_file(Config.FOREST_PATH)`；`again_pressed` → `get_tree().reload_current_scene()`。`main.tscn` 的启动场景仍是 `main.tscn`（把 Task 5 临时改的改回来）。

- [ ] **Step 3: 往返三次（真机）**

导出装机，走：森林 → 门 → 教室打完一局 → 回森林 → 再进教室 → 再回森林。
`adb logcat -s godot` 里不能有 ERROR（尤其是「previously freed instance」「null instance」）。这是 Review Focus 3 的落点。

- [ ] **Step 4: 调数值，记录结果**

在第一局真机上记录：玩家口数、三个人机口数、被抓次数、谁赢、用了多少秒。按 spec §6.7「全部待调」的意图，只动 `game/config.gd` 里的这几个数，目标：**新手 3 局内能赢一次、老手也不是每局都赢**。若三个人机在 60 秒前就全部吃满 20 口 → 调高 `BITE_SECONDS` 或 `NPC_IDLE_CHANCE`；若玩家怎么打都输 → 调低 `GAZE_WATCH` 或 `BITES_TO_WIN`。把结论写进 `docs/perf-log.md`（机型、FPS、DRAW、TRI、一局的关键数值）。

- [ ] **Step 5: 分发包**

```bash
godot --headless --path . --export-debug "Android" build/fungi-party.apk
adb install -r build/fungi-party.apk
```
Expected: 装上就能玩，走完「上课 → 赚币 → 买帽」一整圈。

- [ ] **Step 6: 更新文档**

`AGENTS.md` / `CLAUDE.md` 补 v2 的场景结构（`game/minigame/` = 小游戏、森林里两个 POI）和「教室不跨场景查 group」这条约束，仍 ≤50 行。spec 的「状态」从「待确认」改成「v1/v2 已实现」。

- [ ] **Step 7: 提交**

```bash
git add -A && git commit -m "v2 收尾：校门往返、数值调整、真机验收、文档更新"
```

---

## 自审

**Spec 覆盖（§6 逐条）**

| spec | 落在哪个任务 |
|---|---|
| 6.1 四张课桌 + 玩家 + 3 人机 | T5（几何）、T6（编排） |
| 6.1 视线预警扫视 | T1（模型）、T5（锥/转头/「!」三层视觉） |
| 6.1 按住吃/松手装样子 | T2（规则）、T6（输入） |
| 6.1 罚站 3 秒、累计 3 次出局 | T2 |
| 6.1 先满 N 口赢 / 时间到进度最高赢 | T2 |
| 6.2 0.3 秒预警不可瞬移 | T1（`GAZE_WARN` 阶段本身即是预警窗口，锥提前 0.3 秒出现）、T5（转头在 WARN 内完成） |
| 6.2 判定宽限 0.1 秒 | T2 `test_catch_needs_grace` |
| 6.3 胆量 + 反应延迟分布 | T3 |
| 6.4 单指操作、进度条长在身上 | T6 `EatInput`、T5 头顶 billboard 进度条 |
| 6.5 弹动/腮帮/食物变小 | T5 `SeatVisual.apply` 的 `eating` 弹动；「腮帮鼓起 / 食物变小」用角色整体挤压拉伸 + 进度条跳一格代替，不做额外道具 mesh（`shortcut: 没有食物道具模型，用挤压代替咀嚼，等美术判断后再加`） |
| 6.5 被看瞬间的提示 | T5 锥变红 + 目标座位「!」；`shortcut: 不做音效变调，v3 有音频管线再说` |
| 6.5 被抓定格 0.3 秒 + 老师表情 | T6 全屏红晕 0.3 秒 + 罚站姿态；`shortcut: 老师表情不换（没有五官绑定），用锥变红和「!」代替` |
| 6.6 不做多儿 | T5 老师是自己的蘑菇 + 深色帽，无鸟形 |
| 6.7 全部起手值 | T1 `config.gd` 一次性写全，T9 调 |
| v2 阵容：蘑菇币 + 摊位 + 一个 NPC + 一个皮肤 | T4、T8、T7 |
| §12 存档只存币/皮肤 | T4 的 `read` 恰好三个字段 |

**明确不做**：音频、体力、天数、村庄、第二款小游戏、皮肤装配系统（`Skin` 只有三个字段，不是通用系统）、更多 NPC（摊位老板就是那唯一一个）。这些都在 v3 的账上。

**类型一致性**：`Gaze.Phase` / `Gaze.watching()` / `Gaze.yaw_to` / `Gaze.seen` 在 T5、T6 复用时与 T1 定义一致；`StealEat.Seat` 的字段名在 T5 的 `SeatVisual.apply(seat, eating, delta)` 与 T2 一致；`Save.read()` 返回的 `coins/owned/equipped` 在 T7、T8、T6 都按这三个键用；`Config.NPC_GUTS` 三个值在 T3 与 `classroom.gd` 的循环里都是「第 i 个人机用 `NPC_GUTS[i-1]`」。

**比例**：本计划比 spec 长，因为 spec 对「回合规则怎么组合」几乎没写（只说结论），而规则组合是 v2 唯一真正不可自作主张的地方；几何与 UI 部分只给了尺寸和落点，没有逐行代码。
