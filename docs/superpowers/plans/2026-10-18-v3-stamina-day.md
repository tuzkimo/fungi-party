# v3 体力与一天 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 给森林加上「一天」：体力按局扣、天色由体力派生、走回帐篷睡觉过夜、饭店花币回体力、抬头能看见戴墨镜的太阳和戴睡帽的月亮。

**Architecture:** 纯数学进 `game/systems/day.gd`（静态函数，无节点依赖），持久化进 `game/systems/save.gd`（先 `load` 再写，四个新字段），运行期状态由一个挂在 `main.tscn` 上的 `DayLoop` 节点持有并每帧驱动 `DayNight.time_of_day`。森林里的 POI 沿用 `Stall` 那套「`add_to_group` + 只回答 `player_inside`」，浮层每帧惰性 `get_first_node_in_group`。

**Tech Stack:** Godot 4.7.2 / GDScript / Mobile 渲染器；测试是 `tests/` 下的手写断言（`TestBase`），无头跑。

**Spec:** `docs/superpowers/specs/2026-10-18-v3-stamina-day-design.md`

## Global Constraints

- Godot 锁定 4.7.2，渲染器 `mobile`。禁止实时 GI / SSAO / SSR / 体积雾 / 每帧实例化节点。
- 可调数字一律进 `game/config.gd` 的 `const`，不散落在代码里。本计划里的数值：日体力 100、教室 12、赛跑 20、炸弹 25、一份饭 20 币回 25 体力、一天 3 份、清晨 `0.28`、见底 `0.80`、夜色 `0.86`。
- 美术全部程序化生成（内置 mesh + 材质），不加模型文件、不加贴图。
- 浮层/字体/按钮统一用 `game/ui/ui_style.gd`（`theme()` / `panel()` / `style_button()`）。默认字体没有中文字形，别绕开它。
- 森林侧的跨场景引用每帧惰性 `get_first_node_in_group`，不要在 `_ready` 里查。
- 非平凡逻辑先写测试；能抽纯函数的抽成 `static func`。
- 提交信息用中文，格式 `v3：<做了什么>`。
- 验证命令：`bash scripts/test.sh`（全绿才算过）。

## Review Focus

这些是 spec 隐含、但任何单测都覆盖不到、真人一用就会踩到的地方。各自在对应任务里有测试或验收步骤：

1. **老存档**（只有 `coins/owned/equipped` 三个键）打开游戏 → 满体力、0 份饭、第 1 天、清晨，不崩、不迁移。（Task 1）
2. **只写部分字段的存档写入**（买皮肤写三个键）→ 体力/份数/天数/天色原样保留，不会被抹掉。（Task 1）
3. **体力正好等于一局花销**（12/20/25）→ 能玩，扣到 0，回森林后进入见底状态，不会变负数。（Task 2、Task 3）
4. **睡觉/吃饭动画期间连点按钮**→ 不重复扣钱、不重复过夜。（Task 5、Task 7）
5. **抬头到俯仰上限时相机贴地穿地形**（尤其站在帐篷/摊位旁有碰撞体的地方）→ 不穿模、不抖。（Task 8）

---

### Task 1: 存档升级，摊位只管卖

**Files:**
- Modify: `game/systems/save.gd`（全文 45 行）
- Modify: `game/ui/shop_panel.gd:110-147`（`equip` 与 `_on_wear` 搬走）
- Modify: `tests/test_shop.gd:31-47`（`ShopPanel.equip` → `Save.equip`）
- Test: `tests/test_save_fields.gd`（新建）

**Interfaces:**
- Consumes: 无（第一个任务）
- Produces:
  - `Save.read(path: String = Save.PATH) -> Dictionary`，键增加到七个：`coins: int`、`owned: bool`、`equipped: bool`、`stamina: int`（缺省 `Config.STAMINA_MAX`）、`meals: int`（缺省 0）、`day: int`（缺省 1）、`day_time: float`（缺省 `Config.MORNING_TIME`）
  - `Save.write(path: String, data: Dictionary) -> void`：先 `load` 再 `set_value`，只改传入的键
  - `Save.equip(blueberry: bool, path: String = Save.PATH) -> bool`（从 `ShopPanel` 搬来，签名不变）
  - `ShopPanel` 不再有 `equip`；购买成功后价格行显示「已买下 · 到帐篷里换」

- [ ] **Step 1: 在 `game/config.gd` 加上 v3 常量**

在 `const RACE_PATH` 之后追加（**不删** `DAY_LENGTH_SECONDS`，Task 5 才删）：

```gdscript
# v3 体力与一天
const STAMINA_MAX := 100
const STAMINA_MIN_COST := 12
const STAMINA_COST_CLASSROOM := 12
const STAMINA_COST_RACE := 20
const STAMINA_COST_BOMB := 25
const MEAL_COINS := 20
const MEAL_STAMINA := 25
const MEALS_PER_DAY := 3
const MORNING_TIME := 0.28
const DAYTIME_MAX_T := 0.80
const NIGHT_TIME := 0.86
const DAY_SAVE_INTERVAL := 5.0
const TENT_POS := Vector3(-8.0, 0.0, 2.0)
const RESTAURANT_POS := Vector3(8.0, 0.0, 2.0)
const SUN_DISTANCE := 120.0
const SUN_RADIUS := 4.5
const MOON_RADIUS := 3.2
const SKY_BODY_MIN_ELEVATION := -0.15
```

- [ ] **Step 2: 写失败测试**

`tests/test_save_fields.gd`：

```gdscript
extends TestBase

const P := "user://test_save_fields.cfg"


func _clean() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(P))


func test_old_save_gets_defaults() -> void:
	_clean()
	Save.write(P, {"coins": 50, "owned": false, "equipped": false})
	var d := Save.read(P)
	check_eq(d.coins, 50, "老字段照旧")
	check_eq(d.stamina, 100, "老存档默认满体力")
	check_eq(d.meals, 0, "老存档没吃过饭")
	check_eq(d.day, 1, "老存档是第一天")
	check(absf(d.day_time - 0.28) < 0.001, "老存档在清晨（实得 %.3f）" % d.day_time)
	_clean()


func test_partial_write_keeps_other_fields() -> void:
	_clean()
	Save.write(P, {"coins": 250, "stamina": 40, "day_time": 0.6})
	# 买皮肤只写三个键：不能把体力、天色抹回缺省
	Save.write(P, {"coins": 50, "owned": true, "equipped": true})
	var d := Save.read(P)
	check_eq(d.coins, 50, "币按新的写")
	check_eq(d.stamina, 40, "体力不被别的写入抹掉")
	check(absf(d.day_time - 0.6) < 0.001, "天色不被别的写入抹掉")
	_clean()


func test_roundtrip_all_fields() -> void:
	_clean()
	Save.write(P, {"coins": 7, "stamina": 33, "meals": 2, "day": 9, "day_time": 0.71})
	var d := Save.read(P)
	check_eq([d.coins, d.stamina, d.meals, d.day], [7, 33, 2, 9], "五个数字字段存得住")
	check(absf(d.day_time - 0.71) < 0.001, "天体水位存得住")
	_clean()


func test_corrupt_save_falls_back_to_defaults() -> void:
	_clean()
	var f := FileAccess.open(P, FileAccess.WRITE)
	f.store_string("这不是配置\x00\x01")
	f.close()
	var d := Save.read(P)
	check_eq(d.stamina, 100, "存坏了也不崩，回缺省")
	check_eq(d.coins, 0, "币回缺省")
	_clean()


func test_equip_moved_to_save() -> void:
	_clean()
	Save.write(P, {"owned": false})
	check(not Save.equip(true, P), "没买不能穿")
	Save.write(P, {"owned": true, "equipped": false})
	check(Save.equip(true, P), "买了能穿")
	check(Save.read(P).equipped, "穿上入库")
	check_eq(Save.read(P).coins, 0, "换衣服不动钱")
	_clean()
```

- [ ] **Step 3: 跑测试确认失败**

Run: `bash scripts/test.sh`
Expected: FAIL —— `Save.read()` 没有 `stamina` 键（`Invalid access to property 'stamina'`），`Save.equip` 不存在。

- [ ] **Step 4: 改 `game/systems/save.gd`**

`read` 的返回字典加到七个键，缺省值用 `Config.STAMINA_MAX` / `0` / `1` / `Config.MORNING_TIME`。

`write` 改成先加载：函数体第一行 `cfg.load(path)`，再做原来的循环。`ConfigFile.load` 失败（文件不存在/损坏）时它返回错误码但不抛异常，照常写新文件。

`add_coins` / `apply_round` 不动。

新增：

```gdscript
## 穿戴状态：已拥有才能换。摊位和帐篷都走这里，不各写一遍。
static func equip(blueberry: bool, path: String = PATH) -> bool
```

- [ ] **Step 5: 改 `game/ui/shop_panel.gd`**

- 删掉 `wear` 那一整块（两个按钮 `_wear_default` / `_wear_skin`、`_on_wear`、`equip`）。
- `_refresh()` 里 `owned` 分支的价格行文字改成 `"蓝莓帽 · 已买下 · 到帐篷里换"`。
- 文件头注释里「买过之后这里换成两个『戴哪个』的按钮」那句删掉。

- [ ] **Step 6: 改 `tests/test_shop.gd`**

第 31-47 行两个用例里的 `ShopPanel.equip(...)` 全部换成 `Save.equip(...)`，断言不变。

- [ ] **Step 7: 跑测试确认通过**

Run: `bash scripts/test.sh`
Expected: 全绿，`test_save_fields.gd` 五项、`test_shop.gd` 五项都在。

- [ ] **Step 8: 提交**

```bash
git add game/config.gd game/systems/save.gd game/ui/shop_panel.gd tests/test_save_fields.gd tests/test_shop.gd
git commit -m "v3：存档加体力/份数/天数字段，修掉整段覆盖，摊位只管卖"
```

---

### Task 2: `Day` 纯函数 + `Save` 的高层操作

**Files:**
- Create: `game/systems/day.gd`
- Modify: `game/systems/save.gd`（追加四个方法）
- Test: `tests/test_day.gd`（新建）

**Interfaces:**
- Consumes: `Config.STAMINA_MAX` / `STAMINA_MIN_COST` / `MEAL_COINS` / `MEAL_STAMINA` / `MEALS_PER_DAY` / `MORNING_TIME` / `DAYTIME_MAX_T` / `NIGHT_TIME`（Task 1）；`Save.read` / `Save.write`（Task 1）
- Produces:
  - `Day.day_time(stamina: int) -> float`
  - `Day.advance_time(saved_t: float, stamina: int) -> float`
  - `Day.can_play(stamina: int, cost: int) -> bool`
  - `Day.spend_cost(stamina: int, cost: int) -> Dictionary` → `{"ok": bool, "stamina": int}`
  - `Day.entry_label(stamina: int, cost: int) -> String`
  - `Day.meal(stamina: int, meals: int, coins: int) -> Dictionary` → `{"ok": bool, "stamina": int, "meals": int, "coins": int}`
  - `Day.rollover(day: int) -> Dictionary` → `{"stamina": int, "meals": int, "day": int, "day_time": float}`
  - `Day.exhausted(stamina: int) -> bool`
  - `Save.spend_stamina(cost: int, path: String = Save.PATH) -> bool`
  - `Save.eat_meal(path: String = Save.PATH) -> bool`
  - `Save.rollover(path: String = Save.PATH) -> void`
  - `Save.set_day_time(t: float, path: String = Save.PATH) -> void`

- [ ] **Step 1: 写失败测试**

`tests/test_day.gd`：

```gdscript
extends TestBase

const P := "user://test_day.cfg"


func _clean() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(P))


func test_day_time_runs_from_morning_to_night() -> void:
	check(absf(Day.day_time(100) - 0.28) < 0.001, "满体力是清晨")
	check(absf(Day.day_time(0) - 0.80) < 0.001, "体力耗尽接近天黑（实得 %.3f）" % Day.day_time(0))
	check(Day.day_time(50) > Day.day_time(100), "体力少了太阳更高")
	check(Day.day_time(10) > Day.day_time(60), "体力越少天越晚")


func test_advance_time_never_rewinds() -> void:
	check(absf(Day.advance_time(0.7, 100) - 0.7) < 0.001, "吃完回体力，太阳不倒回去")
	check(absf(Day.advance_time(0.1, 20) - Day.day_time(20)) < 0.001, "体力照常推进天色")


func test_spend_cost() -> void:
	var r := Day.spend_cost(100, 20)
	check(r["ok"], "够就能玩")
	check_eq(r["stamina"], 80, "扣掉一局的花销")
	var bad := Day.spend_cost(11, 12)
	check(not bad["ok"], "差一点也玩不了")
	check_eq(bad["stamina"], 11, "玩不成不扣体力")
	check_eq(Day.spend_cost(12, 12)["stamina"], 0, "正好够扣到 0，不会负数")
	check(not Day.can_play(0, 12), "0 体力玩不了")


func test_entry_label() -> void:
	check_eq(Day.entry_label(100, 12), "体力 −12 · 剩 88", "够体力时给花销和余额")
	check_eq(Day.entry_label(11, 12), "太累了，明天再来", "不够时给原因")


func test_meal() -> void:
	var r := Day.meal(40, 0, 100)
	check(r["ok"], "饿了有钱就能吃")
	check_eq(r["stamina"], 65, "一份回 25")
	check_eq(r["coins"], 80, "扣 20 币")
	check_eq(r["meals"], 1, "记一份")
	check_eq(Day.meal(95, 0, 100)["stamina"], 100, "回体力不超过满")
	check(not Day.meal(40, 3, 100)["ok"], "一天三份就够了")
	check(not Day.meal(40, 0, 19)["ok"], "差 1 币也吃不了")
	check(not Day.meal(100, 0, 100)["ok"], "饱着的时候不吃")
	check(not Day.meal(11, 0, 100)["ok"], "见底之后饭店打烊")


func test_rejected_meal_changes_nothing() -> void:
	var r := Day.meal(11, 0, 100)
	check_eq(r["coins"], 100, "吃不成不扣钱")
	check_eq(r["meals"], 0, "吃不成不算份数")
	check_eq(r["stamina"], 11, "吃不成不回体力")


func test_rollover() -> void:
	var r := Day.rollover(3)
	check_eq(r["stamina"], 100, "睡醒满体力")
	check_eq(r["meals"], 0, "新的一天还没吃饭")
	check_eq(r["day"], 4, "天数加一")
	check(absf(r["day_time"] - 0.28) < 0.001, "睡醒是清晨")


func test_save_wrappers() -> void:
	_clean()
	check(Save.spend_stamina(20, P), "第一局扣得动")
	check_eq(Save.read(P).stamina, 80, "扣完入库")
	check(Save.spend_stamina(80, P), "正好够第二局")
	check_eq(Save.read(P).stamina, 0, "扣到 0")
	check(not Save.spend_stamina(12, P), "0 体力第三局进不去")
	_clean()


func test_eat_meal_and_rollover_persist() -> void:
	_clean()
	Save.write(P, {"stamina": 40, "coins": 100, "meals": 0, "day": 2, "day_time": 0.75})
	check(Save.eat_meal(P), "有钱有额度就能吃")
	var d := Save.read(P)
	check_eq([d.stamina, d.coins, d.meals], [65, 80, 1], "吃一份同时改三个数")
	Save.set_day_time(0.62, P)
	check(absf(Save.read(P).day_time - 0.62) < 0.001, "天色写回存档")
	Save.rollover(P)
	var e := Save.read(P)
	check_eq([e.stamina, e.meals, e.day], [100, 0, 3], "过夜重置")
	check(absf(e.day_time - 0.28) < 0.001, "过夜回到清晨")
	check_eq(e.coins, 80, "过夜不动钱")
	_clean()
```

- [ ] **Step 2: 跑测试确认失败**

Run: `bash scripts/test.sh`
Expected: FAIL —— `Day` 类不存在，`Save.spend_stamina` 等不存在。

- [ ] **Step 3: 写 `game/systems/day.gd`**

`class_name Day`，`extends RefCounted`（不需要，用纯 `static func`，文件头写 `class_name Day` 即可）。全部静态、不碰节点、不碰文件。`day_time` 的核心公式只有一条：

```
t = lerpf(Config.MORNING_TIME, Config.DAYTIME_MAX_T, 1.0 - clampf(float(stamina) / float(Config.STAMINA_MAX), 0.0, 1.0))
```

`meal` 的拒绝条件按顺序：份数用完 → 钱不够 → 满体力（`>= STAMINA_MAX`）→ 已见底打烊（`< STAMINA_MIN_COST`）。任何一种拒绝都原样返回三个输入值。

- [ ] **Step 4: 在 `game/systems/save.gd` 追加四个高层操作**

每个都是「读 → 调 `Day` → 有变化才写回 → 返回 bool/void」。`rollover` 用 `Day.rollover(int(data["day"]))` 的结果整段写回。

- [ ] **Step 5: 跑测试确认通过**

Run: `bash scripts/test.sh`
Expected: 全绿，`test_day.gd` 九项。

- [ ] **Step 6: 提交**

```bash
git add game/systems/day.gd game/systems/save.gd tests/test_day.gd
git commit -m "v3：体力的纯函数与存档操作（扣费/吃饭/过夜/天色水位）"
```

---

### Task 3: 小游戏扣体力，三个入口面板显示与拦截

**Files:**
- Modify: `game/minigame/classroom.gd:26`（`_ready` 第一行）
- Modify: `game/minigame/race.gd:33`（`_ready` 第一行）
- Modify: `game/minigame/bomb.gd:36`（`_ready` 第一行）
- Modify: `game/ui/door_panel.gd`、`game/ui/race_panel.gd`、`game/ui/bomb_panel.gd`（各加一行提示 + 按钮拦截）

**Interfaces:**
- Consumes: `Day.can_play` / `Day.entry_label`（Task 2）、`Save.spend_stamina`（Task 2）、`Config.STAMINA_COST_*` / `Config.FOREST_PATH`（Task 1）
- Produces: 三款小游戏进入即扣体力，不够则直接回森林；入口面板多了提示行。三个面板各自新增一个私有方法 `_refresh()`，在 `_process` 里 `show_now` 由假变真时调一次

- [ ] **Step 1: 三个小游戏的 `_ready` 加扣费**

每个场景 `_ready` 的最前面（`Controls.ensure()` 之前）：

```gdscript
	if not Save.spend_stamina(Config.STAMINA_COST_CLASSROOM):
		# 体力不够就别开始，直接回去；_ready 里换场景要延后
		call_deferred("_bail_to_forest")
		return
```

`_bail_to_forest()` 就是 `get_tree().change_scene_to_file(Config.FOREST_PATH)`。三处各自的 cost 常量不同（教室 `STAMINA_COST_CLASSROOM`、赛跑 `STAMINA_COST_RACE`、炸弹 `STAMINA_COST_BOMB`）。

**为什么在这里扣**：三款小游戏的结算面板都有「再来一局」，原地重载场景、绕过森林入口。放在 `_ready` 一处，重开自动也扣。

- [ ] **Step 2: 三个入口面板加提示行和拦截**

`DoorPanel` / `RacePanel` / `BombPanel` 结构相同，各改三处：

1. 保存 `start` 按钮到成员变量 `_start`（现在它是局部变量）。
2. 在 `start` 之前插入一个 `Label`「体力 −12 · 剩 88」，存到成员 `_cost_label`。
3. `_process` 里 `_root.visible = door != null and door.player_inside` 保持，另加：可见时每次调 `_refresh()`（面板一帧刷新几十次没有成本顾虑，`Save.read()` 是读小文件——**只在这一行改，不要新增定时器**）。

`_refresh()`：

```gdscript
	var stamina := int(Save.read()["stamina"])
	var can := Day.can_play(stamina, Config.STAMINA_COST_CLASSROOM)
	_start.disabled = not can
	_cost_label.text = Day.entry_label(stamina, Config.STAMINA_COST_CLASSROOM)
```

`_on_start()` 不动（切场景，扣费在 `_ready`）。体力不够时按钮已禁用，点不到。

- [ ] **Step 3: 验证**

Run: `bash scripts/test.sh`
Expected: 全绿（`--editor --quit` 会扫描全部脚本，语法错误在这一步暴露）。

再跑一遍桌面版确认主场景能起、面板不报错：`godot --path .`（手动关掉）。
真机才验的部分（写进 Task 9 的验收）：用「再来一局」连玩两局，两局各扣一次体力。

- [ ] **Step 4: 提交**

```bash
git add game/minigame/classroom.gd game/minigame/race.gd game/minigame/bomb.gd game/ui/door_panel.gd game/ui/race_panel.gd game/ui/bomb_panel.gd
git commit -m "v3：小游戏进场扣体力，入口面板显示花销并在不够时拦门"
```

---

### Task 4: 帐篷 POI 与换衣服浮层

**Files:**
- Create: `game/world/tent.gd`
- Create: `game/ui/tent_panel.gd`
- Modify: `game/world/forest.tscn`（加 `Tent` 节点）
- Modify: `game/main.tscn`（加 `TentPanel`）

**Interfaces:**
- Consumes: `Save.read` / `Save.equip`（Task 1）、`UIStyle`
- Produces:
  - `Tent`（`class_name Tent extends Node3D`）：`add_to_group("tent")`、`player_inside: bool`、`bed_global_position() -> Vector3`（Task 5 用）
  - `TentPanel`（`class_name TentPanel extends CanvasLayer`）：换衣服；同文件里预留 `TENT_PATH` 不适用，睡觉按钮留给 Task 5

- [ ] **Step 1: 写 `game/world/tent.gd`**

照 `game/world/stall.gd` 的骨架写（同一个文件的 `_box` / `_solid` 两个辅助函数照抄）。要求：

- 摆在 `Config.TENT_POS`（森林侧节点自己带 `position`，脚本不再设）。
- 两片斜布（`BoxMesh` 压扁后各转 ±30° 左右形成一个三角棚）+ 两根杆 + 一片卷起来的门帘（一卷用压细的圆柱或方块都行）。
- 开口朝 `+Z`（朝出生点）。
- 里面一张床：床板（扁长方）+ 被褥（再薄一层，颜色另一色）+ 枕头（小球压扁）。床的世界坐标要能被 `bed_global_position()` 返回——床用一个 `Node3D` 命名 `Bed` 装起来，函数返回 `$Bed.global_position`。
- 触发区跟 `StartGate` 一样用 `Area3D` + `_physics_process` 里 `get_overlapping_bodies()` 每帧重算 `player_inside`（`Stall` 用的是信号，但 `StartGate` 的每帧重算更不容易漏；照 `StartGate` 写）。尺寸 `Vector3(3.0, 2.0, 3.0)`，位置在帐篷开口前 1 米。
- 大小以「玩家走过去看得见床」为准，帐篷整体高约 2.6 米。

- [ ] **Step 2: 在 `game/world/forest.tscn` 加节点**

在 `BombRing` 之后、`DayNight` 之前：

```
[node name="Tent" type="Node3D" parent="."]
position = Vector3(-8, 0, 2)
script = ExtResource("<新 ext_resource tent.gd>")
```

记得在文件头补 `ext_resource`（`load_steps` 数字也要 +1）。

- [ ] **Step 3: 写 `game/ui/tent_panel.gd`**

照 `game/ui/shop_panel.gd` 的骨架（`_root` / `Dim` / `Center` / `Panel` / `VBox` / `UIStyle`）。内容：

- 标题「帐篷」。
- 一行体力：`体力 88/100`。
- `睡觉` 按钮：`text = "睡到早上"`，`custom_minimum_size = Vector2(240, 64)`。本任务里 `pressed` 接到一个空的 `_on_sleep()`（只 `print("TODO sleep")`），Task 5 填。
- `换衣服` 按钮：点了把下方的皮肤列表 `visible` 取反。
- 皮肤列表：一个 `HBoxContainer`，两个按钮「默认红帽」「蓝莓帽」。未拥有的按钮 `visible = false`；当前戴着的 `disabled = true`。
- 点皮肤 → `Save.equip(blueberry)` 成功后调玩家 `apply_skin()`（照 `ShopPanel._apply_skin_to_player` 抄）。
- `_process` 每帧惰性找 `get_tree().get_first_node_in_group("tent")`，`_root.visible = tent != null and tent.player_inside`。

- [ ] **Step 4: 在 `game/main.tscn` 加 `TentPanel`**

照 `ShopPanel` 的写法加一个 `CanvasLayer` 节点 `TentPanel`，挂 `tent_panel.gd`。

- [ ] **Step 5: 验证**

Run: `bash scripts/test.sh` → 全绿（保证脚本能解析）。
Run: `godot --path .` → 走到 `(-8, 0, 2)` 能看到帐篷和床，走近弹浮层；买过帽子后能在帐篷里来回换，森林里的蘑菇立刻变色。

- [ ] **Step 6: 提交**

```bash
git add game/world/tent.gd game/world/forest.tscn game/ui/tent_panel.gd game/main.tscn
git commit -m "v3：森林帐篷与床，换衣服从摊位搬进帐篷"
```

---

### Task 5: `DayLoop` —— 天色由体力驱动，帐篷里睡觉

**Files:**
- Create: `game/world/day_loop.gd`
- Modify: `game/world/daynight.gd:74-78`（删掉自己推进时间）
- Modify: `game/config.gd`（删 `DAY_LENGTH_SECONDS`）
- Modify: `game/world/forest.tscn`（加 `DayLoop` 节点）
- Modify: `game/ui/tent_panel.gd`（`_on_sleep` 接上、睡觉期间禁用按钮）

**Interfaces:**
- Consumes: `Day.advance_time` / `Day.exhausted` / `Day.rollover`（Task 2）、`Save.set_day_time` / `Save.rollover` / `Save.read`（Task 2）、`Tent.bed_global_position()`（Task 4）、`DayNight.time_of_day`
- Produces:
  - `DayLoop`（`class_name DayLoop extends Node`，`add_to_group("day_loop")`），成员：`stamina: int`、`meals: int`、`day: int`、`time_of_day: float`、`sleeping: bool`；方法 `refresh() -> void`、`sleep() -> void`；信号 `changed`
  - `DayNight` 不再自动推进，`day_length_seconds` 导出属性删除

- [ ] **Step 1: 改 `game/world/daynight.gd`**

删掉 `day_length_seconds` 导出属性和 `_process` 里的推进逻辑（保留 `_apply()`，仍由 `_ready` 和外部改动触发）。`_process` 整个删掉，改由 `DayLoop` 每帧写 `time_of_day` 再调 `_apply()` —— 把 `_apply` 改成公开的 `apply()`，`_ready` 末尾调它。

`game/config.gd` 里 `const DAY_LENGTH_SECONDS := 600.0` 删掉。

- [ ] **Step 2: 写 `game/world/day_loop.gd`**

```gdscript
class_name DayLoop
extends Node

## 森林侧唯一持有「今天」的地方：读存档、驱动天色、编排睡觉。
## 小游戏场景不感知体力（扣费在它们自己的 _ready 里，切回森林重建时重新读）。

signal changed

const FADE_IN := 0.5      # 淡到黑
const FADE_OUT := 0.7     # 黑到早上
const LIE_SECONDS := 0.4  # 走到床前躺下

var stamina := Config.STAMINA_MAX
var meals := 0
var day := 1
var time_of_day := Config.MORNING_TIME
var sleeping := false
```

`_ready()`：`add_to_group("day_loop")`、`refresh()`、找到 `DayNight`（`@export var daynight_path: NodePath`）并立刻写一次 `time_of_day` 再 `apply()`；`_fade` 用一个自己建的 `CanvasLayer > ColorRect`（黑，`mouse_filter = MOUSE_FILTER_IGNORE`，`modulate.a = 0`）。

`_process(delta)`：
- `sleeping` 时直接 `return`。
- 见底时（`Day.exhausted(stamina)`）天色目标不是体力算出来的 `0.80`，而是 `Config.NIGHT_TIME`（`0.86`）：用一个 `_sunset` 计时器在 `1.2` 秒内把 `time_of_day` 从当前值推到 `0.86`，到位后就停在那儿。体力还够时 `_sunset = -1`，按体力算。
- 否则 `time_of_day = Day.advance_time(time_of_day, stamina)`；写进 `DayNight`，只有变化超过 `0.0005` 才 `apply()`。
- `_save_timer += delta`，超过 `Config.DAY_SAVE_INTERVAL` 就 `Save.set_day_time(time_of_day)` 并清零。
- `stamina` 变化可能来自吃饭（别的面板改的）——**不在这里轮询**，由改动的面板调 `refresh()`。

`refresh()`：`var d := Save.read()`，把三个整数字段抄进成员；**天色要拿存档里的值当前提**——`time_of_day = Day.advance_time(float(d["day_time"]), stamina)`。别写成 `Day.advance_time(time_of_day, stamina)`，那会把初始值 `0.28` 当成水位、把存档里的 `0.71` 盖成 `0.28`。最后 `emit_signal("changed")`。

`sleep()`：
1. `sleeping = true`，`emit_signal("changed")`。
2. 找玩家和帐篷；`player.set_physics_process(false)`；把 `TouchControls` 隐藏（`visible = false`，睡觉期间不能推摇杆）；用 `create_tween()` 把玩家 `global_position` 挪到 `tent.bed_global_position() + Vector3(0, 0.35, 0)`、`rotation.z` 转到 `-PI / 2`，时长 `LIE_SECONDS`。
3. `await tween.finished` → 等 `0.3` 秒 → 黑幕 `modulate.a` 到 1（`FADE_IN`）→ `await`。
4. `Save.rollover()`；`time_of_day = Config.MORNING_TIME`，再 `refresh()`；玩家挪回帐篷外侧（`tent.global_position + Vector3(0, 0.3, 1.2)`）、`rotation.z = 0`、`set_physics_process(true)`、`TouchControls` 恢复可见。
5. 黑幕 `modulate.a` 到 0（`FADE_OUT`）、`await`；`sleeping = false`，`emit_signal("changed")`。

注意：`time_of_day` 在 `refresh()` 里取 `max`，所以 `rollover` 之后必须**手动**设 `time_of_day = Config.MORNING_TIME` 再 `refresh()`（否则 `advance_time` 会把 `0.28` 拉回旧水位）。

- [ ] **Step 3: 接上帐篷浮层的睡觉按钮**

`tent_panel.gd` 的 `_on_sleep()`：找 `get_tree().get_first_node_in_group("day_loop")`，`day_loop.sleep()`。
`_refresh()` 里加：`_sleep.disabled = day_loop != null and day_loop.sleeping`、`_clothes.disabled` 同理；`sleeping` 时整个 `_root.visible = false`（玩家已经躺下了，面板不该盖着黑幕）。

- [ ] **Step 4: 在 `game/world/forest.tscn` 加 `DayLoop`**

在 `DayNight` 之后加一个 `Node` 节点 `DayLoop`，挂 `day_loop.gd`，`daynight_path = NodePath("../DayNight")`。

- [ ] **Step 5: 验证**

Run: `bash scripts/test.sh` → 全绿（`test_daynight.gd` 只测静态函数，不受影响）。
Run: `godot --path .`：玩到体力见底（或直接在编辑器里把存档 `stamina` 改成 0）→ 天色落山 → 走到帐篷 → 点「睡到早上」→ 天黑 → 早上、体力满、玩家站在帐篷外。
检查：在森林里站着不动 30 秒，太阳不动、体力不变。

- [ ] **Step 6: 提交**

```bash
git add game/world/day_loop.gd game/world/daynight.gd game/config.gd game/world/forest.tscn game/ui/tent_panel.gd
git commit -m "v3：天色改由体力驱动，帐篷里睡觉过夜"
```

---

### Task 6: HUD（体力条 + 蘑菇币 + 见底提示）

**Files:**
- Create: `game/ui/day_hud.gd`
- Modify: `game/main.tscn`（加 `DayHUD` 节点）

**Interfaces:**
- Consumes: `DayLoop.stamina` / `DayLoop.meals` / `DayLoop.changed`（Task 5）、`Save.read()["coins"]`
- Produces: 森林左上角常驻体力条与币；体力 `< Config.STAMINA_MIN_COST` 时数字变红并加一行「回帐篷睡觉」

- [ ] **Step 1: 写 `game/ui/day_hud.gd`**

`class_name DayHUD extends CanvasLayer`。`_ready` 建一个锚在左上的 `PanelContainer`（`UIStyle.panel()`，`custom_minimum_size = Vector2(320, 0)`），里面 `VBox`：

- `Label` 体力文字「体力 88/100」
- `ProgressBar`：`min_value = 0`、`max_value = Config.STAMINA_MAX`、`custom_minimum_size = Vector2(260, 22)`、`show_percentage = false`
- `Label` 币「蘑菇币 120」
- `Label` 提示「回帐篷睡觉」（`visible = false`）

刷新走 0.25 秒的 `Timer`（`wait_time = 0.25`、`autostart = true`、`timeout` 连 `_refresh`），**不每帧读存档**。`_refresh()`：

- 惰性找 `get_tree().get_first_node_in_group("day_loop")`，拿 `stamina`；找不到就 `visible = false` 直接返回。
- 更新文字和 `ProgressBar.value`；`stamina < Config.STAMINA_MIN_COST` 时体力文字 `add_theme_color_override("font_color", Color(1.0, 0.45, 0.40))` 并显示提示行，否则清掉覆盖、隐藏提示。
- 币显示 `Save.read()["coins"]`（0.25 秒读一次小文件，够便宜）。
- 同时 `connect("changed", _refresh)` 到 `DayLoop`，让睡觉/吃饭后立刻更新，不等定时器。

`_ready` 里 `theme = UIStyle.theme()` 加在最外层 `Control` 上（`PanelContainer` 可以直接 `theme`）。

- [ ] **Step 2: 在 `game/main.tscn` 加节点**

加 `CanvasLayer` 节点 `DayHUD`，挂 `day_hud.gd`。

- [ ] **Step 3: 验证**

Run: `bash scripts/test.sh` → 全绿。
Run: `godot --path .`：左上角有体力条和币；吃一份饭（Task 7 之后）或睡觉后立刻更新；体力低于 12 时数字变红并出现提示。

- [ ] **Step 4: 提交**

```bash
git add game/ui/day_hud.gd game/main.tscn
git commit -m "v3：森林 HUD 显示体力与蘑菇币，体力见底提示回帐篷"
```

---

### Task 7: 饭店、吃饭与吃饭动画

**Files:**
- Create: `game/world/restaurant.gd`
- Create: `game/ui/meal_panel.gd`
- Create: `game/world/meal_bowl.gd`
- Modify: `game/player/player.gd:104-118`（`_animate` 叠加咬合挤压）
- Modify: `game/player/movement.gd`（加一个纯函数）
- Modify: `game/world/forest.tscn`（加 `Restaurant` 节点）
- Modify: `game/main.tscn`（加 `MealPanel`）
- Test: `tests/test_movement.gd`（追加一项）

**Interfaces:**
- Consumes: `Save.eat_meal`（Task 2）、`DayLoop.refresh()`（Task 5）、`DayHUD`（Task 6，通过 `changed` 信号自动更新）、`MushroomMesh`
- Produces:
  - `Restaurant`（`class_name Restaurant extends Node3D`）：`add_to_group("restaurant")`、`player_inside: bool`
  - `MealBowl`（`class_name MealBowl extends Node3D`）：`static func create() -> MealBowl`，`func play() -> void`（1.2 秒后 `queue_free()`）
  - `Movement.chew_scale(elapsed: float) -> Vector3`
  - `Player.chew()`：让角色咬三口

- [ ] **Step 1: 写失败测试（`tests/test_movement.gd` 追加）**

```gdscript
func test_chew_scale_bites_three_times() -> void:
	check_eq(Movement.chew_scale(-0.1), Vector3.ONE, "没开始不挤压")
	check(Movement.chew_scale(0.05) != Vector3.ONE, "咬下去的瞬间有挤压")
	check(Movement.chew_scale(0.6) != Vector3.ONE, "第二口也在挤压")
	check_eq(Movement.chew_scale(1.4), Vector3.ONE, "咬完回到原样")
```

`Movement.chew_scale(elapsed)`：总时长按 `Config.MEAL_ANIMATION_SECONDS`（`1.2`）算，三口各占前 `1.05` 秒、每口 `0.35`；每一口内部取 `sin(PI * 进度)` 做一次「压扁 → 回弹」，幅度 `0.12`（压扁：y 减、x/z 加）。

- [ ] **Step 2: 跑测试确认失败**

Run: `bash scripts/test.sh`
Expected: FAIL —— `Movement.chew_scale` 不存在。

- [ ] **Step 3: 实现 `Movement.chew_scale` 与 `Player.chew()`**

`Player.chew()`：设 `_chew := 0.0`（新成员），在 `_animate` 里 `if _chew >= 0.0: _chew += delta; squash = squash * Movement.chew_scale(_chew); if _chew > Config.MEAL_ANIMATION_SECONDS: _chew = -1.0`。初值 `-1.0` 表示没在咬。挤压相乘，别覆盖走路的 squash。

`game/config.gd` 加：

```gdscript
const MEAL_ANIMATION_SECONDS := 1.2
```

- [ ] **Step 4: 跑测试确认通过**

Run: `bash scripts/test.sh`
Expected: 全绿。

- [ ] **Step 5: 写 `game/world/restaurant.gd`**

照 `tent.gd` 的骨架。一栋小房子：四面墙（正面留门洞：两块墙板中间空一段）+ 斜屋顶（两块压扁的 `BoxMesh`）+ 招牌（一根杆 + 一块板）。跟帐篷必须一眼分得开：帐篷是布、三角；饭店是方盒子 + 屋顶 + 招牌。触发区 `Vector3(3.4, 2.0, 3.4)` 在门前。

- [ ] **Step 6: 写 `game/world/meal_bowl.gd`**

`Node3D`，`create()` 里建：碗（低半球或压扁的圆柱 + 深一点的色）+ 饭（白色小球压扁，露出碗口一截）。`play()` 让碗从玩家面前 `0.9` 米、高 `0.9` 的位置缓缓出现（0.15 秒放大），停 1 秒，缩小消失，然后 `queue_free()`。

- [ ] **Step 7: 写 `game/ui/meal_panel.gd`**

照 `shop_panel.gd` 的骨架。面板内容：

- 标题「饭店」
- `Label` 体力「体力 40/100」
- `Label` 币「蘑菇币 120」
- `Label` 份数「今天第 1/3 份」
- `Button`「吃一份（20 币）」

`_refresh()`：
- 找 `day_loop`（`get_first_node_in_group("day_loop")`），拿 `stamina` / `meals`。
- 调 `Day.meal(stamina, meals, coins)` 看 `ok`，据此决定按钮 `disabled` 和文字：`ok` → 「吃一份（20 币）」；份数用完 → 「今天吃够了」；钱不够 → 「还差 N 币」；已见底 → 「打烊了，明天再来」；满体力 → 「还饱着」。文字用 `Day.meal` 的返回值和几个 `if` 判，不另写一套规则。

`_on_eat()`：
1. `if _busy: return`（`_busy` 新成员，防连点）。
2. `if not Save.eat_meal(): return`。
3. `_busy = true`，按钮禁用。
4. 找玩家 → `player.chew()`；把 `MealBowl.create()` 加到玩家下面并 `play()`。
5. `day_loop.refresh()`（HUD 会收到 `changed` 自己更新）、`_refresh()`。
6. `await get_tree().create_timer(Config.MEAL_ANIMATION_SECONDS).timeout` → `_busy = false`、`_refresh()`。

- [ ] **Step 8: 场景挂上**

`game/world/forest.tscn` 加 `Restaurant` 节点（`position = Vector3(8, 0, 2)`）。`game/main.tscn` 加 `MealPanel`（`CanvasLayer`）。

- [ ] **Step 9: 验证**

Run: `bash scripts/test.sh` → 全绿。
Run: `godot --path .`：走到饭店 → 吃一份 → 碗出现、蘑菇咬三口、体力条涨 25、币少 20；连点只有第一下生效；体力满、份数用完、钱不够、体力见底四种情况按钮文字都对、都点不动。

- [ ] **Step 10: 提交**

```bash
git add game/world/restaurant.gd game/world/meal_bowl.gd game/ui/meal_panel.gd game/player/player.gd game/player/movement.gd game/config.gd game/world/forest.tscn game/main.tscn tests/test_movement.gd
git commit -m "v3：饭店、吃饭与咬一口的动画"
```

---

### Task 8: 抬头看天，太阳与月亮

**Files:**
- Modify: `game/camera/cam_rig.gd:16`（`PITCH_MAX`）
- Modify: `game/world/daynight.gd`（加 `sun_dir`）
- Create: `game/world/sky_bodies.gd`
- Modify: `game/world/forest.tscn`（加 `SkyBodies` 节点）
- Modify: `tests/test_camera.gd`（改用 `CamRig` 自己的常量，加一条抬头用例）
- Test: `tests/test_daynight.gd`（追加三项）

**Interfaces:**
- Consumes: `DayNight.time_of_day`（Task 5 每帧写入）、`DayNight.sun_rotation`
- Produces:
  - `CamRig.PITCH_MAX := 0.3839724`（22°）、`CamRig.PITCH_MIN` 不变
  - `DayNight.sun_dir(t: float) -> Vector3`（单位向量，从地面指向天体）
  - `DayNight.moon_dir_t(t: float) -> float` = `fmod(t + 0.5, 1.0)`
  - `DayNight.moon_dir(t: float) -> Vector3` = `sun_dir(moon_dir_t(t))`
  - `DayNight.body_visible(dir: Vector3) -> bool` = `dir.y > Config.SKY_BODY_MIN_ELEVATION`
  - `SkyBodies`（`class_name SkyBodies extends Node3D`）：`@export var daynight_path: NodePath`

- [ ] **Step 1: 写失败测试**

`tests/test_daynight.gd` 追加：

```gdscript
func test_sun_rises_in_plus_z_and_sets_in_minus_z() -> void:
	var rise := DayNight.sun_dir(0.25)
	check(absf(rise.y) < 0.01, "日出贴着地平线（实得 %.3f）" % rise.y)
	check(rise.z > 0.5, "日出在 +Z 那侧（实得 %.3f）" % rise.z)
	var set := DayNight.sun_dir(0.75)
	check(absf(set.y) < 0.01, "日落贴着地平线")
	check(set.z < -0.5, "日落在 -Z 那侧（实得 %.3f）" % set.z)


func test_sun_overhead_at_noon_direction() -> void:
	var noon := DayNight.sun_dir(0.5)
	check(noon.y > 0.99, "正午在头顶（实得 %.3f）" % noon.y)


func test_moon_is_opposite_and_complementary() -> void:
	var t := 0.3
	check(DayNight.moon_dir(t).is_equal_approx(-DayNight.sun_dir(DayNight.moon_dir_t(t))), "月亮永远在太阳对面")
	check(DayNight.body_visible(DayNight.sun_dir(0.5)), "白天看得见太阳")
	check(not DayNight.body_visible(DayNight.moon_dir(0.5)), "白天看不见月亮")
	check(DayNight.body_visible(DayNight.moon_dir(0.0)), "夜里看得见月亮")
	check(not DayNight.body_visible(DayNight.sun_dir(0.0)), "夜里看不见太阳")
```

`moon_dir_t(t)` 就是 `fmod(t + 0.5, 1.0)`，单独抽出来是为了这条断言能写清楚。

`tests/test_camera.gd`：把本地 `const PITCH_MIN/PITCH_MAX` 换成 `CamRig.PITCH_MIN` / `CamRig.PITCH_MAX`，并追加：

```gdscript
func test_can_look_up_at_the_sky() -> void:
	check(CamRig.PITCH_MAX > 0.3, "俯仰上限能抬到天上看（实得 %.3f）" % CamRig.PITCH_MAX)
```

- [ ] **Step 2: 跑测试确认失败**

Run: `bash scripts/test.sh`
Expected: FAIL —— `DayNight.sun_dir` 不存在；`CamRig.PITCH_MAX > 0.3` 为假（现在是 -0.17）。

- [ ] **Step 3: 实现 `DayNight.sun_dir` / `moon_dir` / `body_visible`**

`sun_dir(t)` 用现成的 `sun_rotation(t)` 构造基：`Basis.from_euler(sun_rotation(t)).z`（`Basis.from_euler` 与 `Node3D.rotation` 同为 YXZ 序，不用另定角度）。

- [ ] **Step 4: 改 `CamRig.PITCH_MAX`**

`const PITCH_MAX := 0.3839724   # +22°：抬头能看见天`。

- [ ] **Step 5: 写 `game/world/sky_bodies.gd`**

- `_ready`：建 `_sun` / `_moon` 两个 `Node3D`，各自 `unshaded` + 自发光的部件，照 `MushroomMesh` 的 `_add_part(name, mesh, material, pos, scale)` 写法（同一个辅助函数抄一份，`material_override` 指同一份材质）。
- **太阳**：`SphereMesh`（`radius = Config.SUN_RADIUS`，分段 24×12，不要默认的 64×32）+ 一层 `radius * 1.25` 的半透明光晕球（`TRANSPARENCY_ALPHA`、`shading_mode = UNSHADED`、`albedo_color.a ≈ 0.18`）+ 墨镜（两个 `CylinderMesh` 压扁成片当镜片、一个细 `BoxMesh` 当镜桥、两条细 `BoxMesh` 当镜腿）+ 一张微微上扬的嘴（压扁的 `TorusMesh` 取下半段，或者两段小方块拼——builder 选，要求远看是一张笑脸）。
- **月亮**：`SphereMesh`（`radius = Config.MOON_RADIUS`）+ 睡帽（`CylinderMesh` 的 `top_radius = 0` 做锥 + 帽尖小球，斜扣在头顶）+ 两条闭眼（细扁方块各倾斜约 15°，左右对称）+ 可选三个 zzz 小球浮在上面。
- `_process`：取相机 `get_viewport().get_camera_3d()`；从 `daynight_path` 拿 `time_of_day`；太阳 `position = cam.global_position + DayNight.sun_dir(t) * Config.SUN_DISTANCE`、月亮同理；各自的 `visible = DayNight.body_visible(dir)`；可见时 `look_at(cam.global_position)`。
- 别用 `Camera3D.far` 之外的距离；`Config.SUN_DISTANCE = 120` 在默认 far（4000）内。

- [ ] **Step 6: 在 `game/world/forest.tscn` 加节点**

在 `DayNight` 之后加 `Node3D` 节点 `SkyBodies`，挂 `sky_bodies.gd`，`daynight_path = NodePath("../DayNight")`。

- [ ] **Step 7: 跑测试确认通过**

Run: `bash scripts/test.sh`
Expected: 全绿（`test_daynight.gd` 十二项、`test_camera.gd` 五项）。

- [ ] **Step 8: 验证天上的东西**

Run: `godot --path .`：拖到抬头 → 看见天；太阳在东侧低空、中午到头顶、傍晚落到西侧；夜里月亮带睡帽出来。把存档 `day_time` 依次改成 `0.3 / 0.5 / 0.7 / 0.9` 各看一次。

- [ ] **Step 9: 提交**

```bash
git add game/camera/cam_rig.gd game/world/daynight.gd game/world/sky_bodies.gd game/world/forest.tscn tests/test_daynight.gd tests/test_camera.gd
git commit -m "v3：相机能抬头，太阳戴墨镜东升西落，月亮戴睡帽值夜"
```

---

### Task 9: 文档、真机验收与数值回调

**Files:**
- Modify: `AGENTS.md`、`CLAUDE.md`（两个文件同内容，见项目约定）
- Modify: `README.md`（玩法与操作章节）
- Modify: `docs/perf-log.md`（加一行）
- Modify: `docs/superpowers/specs/2026-10-17-fungi-party-design.md:4`（状态行改成「v1 / v2 / v3 已实现」）

**Interfaces:**
- Consumes: 前面全部任务
- Produces: 文档与真机验收结论

- [ ] **Step 1: 更新 `AGENTS.md` / `CLAUDE.md`**

「项目概述」的 v3 一行改成「森林里六个 POI —— 校门、摊位、起跑线、蘑菇圈、饭店、帐篷；体力按局扣，天色由体力派生，饭店回体力，帐篷睡觉换衣服」。

「技术约束」加一条：「体力与天色只有 `game/systems/day.gd` 一套公式；别处不许再算天色。扣体力只在小游戏 `_ready` 一处。」

- [ ] **Step 2: 更新 `README.md`**

「你会玩到什么」加两段：饭店（20 币一份、一天三份、回 25 体力）、帐篷（睡觉过夜、换帽子，摊位只卖不换）。「操作」加一句「帐篷/饭店走到跟前弹浮层」。版本号 `0.4.0` 改 `0.5.0`（同时改 `project.godot` 里的 `config/version`，如果项目里有的话——没有就只改 README）。

- [ ] **Step 3: 真机验收（装包、人肉玩一遍）**

```bash
godot --headless --path . --export-debug "Android" build/app.apk
adb install -r build/app.apk
adb shell monkey -p com.tuzki.fungiparty -c android.intent.category.LAUNCHER 1
adb logcat -s godot
adb exec-out screencap -p > shots/v3-day.png
```

依次确认（spec 第 7 节的那几条）：
- 完整一天：玩到体力见底 → 天黑 → 走到帐篷 → 睡 → 早上满体力。
- 中途吃一份饭：太阳停在原地不倒转，体力条涨、天色不变。
- 帐篷里换帽子立刻生效，摊位上已经换不了。
- 「再来一局」连玩两局，各扣一次体力。
- 抬头能看见天，太阳东升西落，月亮带睡帽；抬头到极限时相机不穿地、不抖。
- 森林里站两分钟：体力不变、太阳不动。

- [ ] **Step 4: 按真机手感调数值**

只改 `game/config.gd` 的常量，不动逻辑。要看的两个数：
- **一天多长**：5 局是不是 10~15 分钟。偏长就把 `STAMINA_MAX` 降到 80，偏短就加。
- **饭值不值**：20 币换 25 体力是不是太便宜。偏便宜就把 `MEAL_COINS` 加到 30。

调完重跑 `bash scripts/test.sh`（`test_day.gd` 里全是按常量算的，不会因为调数值而红）。

- [ ] **Step 5: 记帧率**

`docs/perf-log.md` 加一行：日期、机型、场景（森林、抬头看天时）、FPS、备注（多了两个天体 mesh 的代价）。

- [ ] **Step 6: 提交**

```bash
git add AGENTS.md CLAUDE.md README.md docs/perf-log.md docs/superpowers/specs/2026-10-17-fungi-party-design.md game/config.gd
git commit -m "v3：文档与真机验收，天数按手感回调"
```
