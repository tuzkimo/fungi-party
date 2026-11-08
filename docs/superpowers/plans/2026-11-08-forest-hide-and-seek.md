# 森林捉迷藏 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让两个联机玩家在森林里（不换场景）打一局捉迷藏：30 秒藏、120 秒找、捉到或超时定胜负、输的付 5 蘑菇币；森林同时多出一批能藏能跳的地形。

**Architecture:** 服务器把 `hide` 当成第五种 `NetRoom.KINDS`，只跑一个 RefCounted 的 `HideRound`（角色、计时、捉到的距离判定、结算）；玩家的位置沿用现成的 `MOVE`，服务器据此喂模型、并决定找的人那一份 `WORLD` 里放不放藏的人。客户端不换场景，森林里一个新节点 `HideGame` 按 `SESSION` 快照驱动黑屏倒数、速度限制、捉到按钮和结算横幅；藏点几何只在客户端确定性生成。

**Tech Stack:** Godot 4.7.2 / GDScript / ENet（`NetProtocol` 自建信封）/ 无头测试 `bash scripts/test.sh`。

**Spec:** `docs/superpowers/specs/2026-11-08-forest-hide-and-seek-design.md`

## Global Constraints

- 服务器上只跑 RefCounted（绝不实例化 3D 场景）；位置、输入、昵称全是信任边界，类型不对一律拒，不当 0 处理。
- 客户端一次只飞一条 op，只有 `OP_RESULT` 能清 `_inflight`；新增 op / op 参数必须回 `OP_RESULT`。
- `NetProtocol.VERSION` 9 → 10（`WORLD` 多字段、`answer` 多参数、多一种 kind），客户端和服务端一起发版。
- 数字全部进 `game/config.gd` 的 `const`：`HIDE_NEAR_RANGE 4.0`、`HIDE_COUNTDOWN 30.0`、`HIDE_SEEK_SECONDS 120.0`、`HIDE_REVEAL 12.0`、`HIDE_CATCH 2.5`、`HIDE_STAKE 5`、`HIDE_HIDER_SPEED 0.5`。
- 动态拼的中文文案只用 ASCII 标点（真机系统字体没有全角括号）。
- 非平凡逻辑先写测试；能抽纯函数的抽 `static func`。
- 提交信息用中文。
- 不加新依赖、不动 `terrain.gd`（这一版不挖地下坑）。

## Review Focus

- **局中有人掉线**：剩下那台不能挂 120 秒黑屏，必须立刻收局且双方都不动钱。
- **局中重登 / 换设备**：服务器会重推 `SESSION`（`_broadcast_session`），客户端要能重新接管浮层、解锁玩家。
- **`catch` 在范围外 / 坐标缺失 / 对方刚连进来还没报过位置**：一律不算数 —— 一次点击不能结束一局。
- **钱包**：输家余额不足 5 币时只扣到 0，赢家只拿实际扣到的；不许凭空造币。
- **藏点几何把人卡住**：石头/木箱/断木/石洞的碰撞体不能把人顶进地面或墙里，也不能把人锁在原地。

---

### Task 1: `HideRound` 模型 + `Config` 常量

**Files:**
- Create: `game/net/hide_round.gd`
- Create: `tests/test_hide_round.gd`
- Modify: `game/config.gd`（在 v7 那一段末尾追加 `HIDE_*`）

**Interfaces:**
- Produces: `class_name HideRound extends RefCounted`，字段 `phase: String`（`"countdown"` / `"seeking"` / `"over"`）、`seeker_seat: int`、`hider_seat: int`、`left: float`、`revealed: bool`、`caught: bool`、`over: bool`、`winner: int`；
  方法 `assign(hider: int, seeker: int) -> void`、`feed(seat: int, slot: int, spot: Vector3) -> void`、`tick(delta: float) -> void`、`can_catch() -> bool`、`catch(seat: int) -> bool`、`forfeit(seat: int) -> bool`、`coins_for(seat: int) -> int`、`snapshot() -> Dictionary`；
  静态 `flat_distance(a: Vector3, b: Vector3) -> float`、`nearest_distance(a: Array, b: Array) -> float`（任一为空返回 `INF`）、`reveal_ok(seeker: Array, hider: Array) -> bool`、`hide_keys(account: String) -> Array[String]`（`[account, account + "|1"]`）。
- 默认值：`seeker_seat = 0`、`hider_seat = 1`、`left = Config.HIDE_COUNTDOWN`、`winner = -1`。座位坐标存在内部 `seat -> {slot: Vector3}`。

- [ ] **Step 1: 写失败的测试** `tests/test_hide_round.gd`

```gdscript
extends TestBase

func _r() -> HideRound:
	var r := HideRound.new()
	r.assign(1, 0)               # 0 号座找，1 号座藏
	return r

func test_countdown_then_seeking() -> void:
	var r := _r()
	check_eq(r.phase, "countdown", "开局是倒数")
	r.tick(Config.HIDE_COUNTDOWN - 0.1)
	check_eq(r.phase, "countdown", "差一点还在倒数")
	r.tick(0.2)
	check_eq(r.phase, "seeking", "倒数完进找")
	check(r.left > Config.HIDE_SEEK_SECONDS - 0.5, "找的阶段满时长")

func test_timeout_hider_wins() -> void:
	var r := _r()
	r.tick(Config.HIDE_COUNTDOWN + 0.1)
	r.tick(Config.HIDE_SEEK_SECONDS + 0.1)
	check_eq(r.phase, "over", "找的时间用完就收")
	check_eq(r.winner, 1, "超时藏的人赢")

func test_catch_needs_range_and_seeker() -> void:
	var r := _r()
	r.feed(1, 0, Vector3(0, 0, 0))
	r.feed(0, 0, Vector3(0, 0, Config.HIDE_CATCH + 1.0))
	r.tick(Config.HIDE_COUNTDOWN + 0.1)
	check_eq(r.can_catch(), false, "超出捉到距离不能捉")
	check_eq(r.catch(1), false, "藏的人不能自己捉")
	check_eq(r.catch(0), false, "距离不够的捉不算")
	check_eq(r.over, false, "局没结束")
	r.feed(0, 0, Vector3(0, 0, Config.HIDE_CATCH - 0.2))
	check_eq(r.can_catch(), true, "进范围能捉")
	check_eq(r.catch(0), true, "找的人捉到了")
	check_eq(r.over, true, "捉到就收局")
	check_eq(r.winner, 0, "找的人赢")
	check_eq(r.caught, true, "标记捉到")

func test_catch_needs_positions() -> void:
	var r := _r()
	r.tick(Config.HIDE_COUNTDOWN + 0.1)
	check_eq(r.can_catch(), false, "没人报过位置时不能捉")
	check_eq(r.catch(0), false, "坐标缺一就不算")

func test_two_p_on_each_side_takes_nearest() -> void:
	var r := _r()
	r.feed(1, 0, Vector3(0, 0, 0))
	r.feed(0, 0, Vector3(30, 0, 0))
	r.feed(0, 1, Vector3(1.0, 0, 0))
	r.tick(Config.HIDE_COUNTDOWN + 0.1)
	check_eq(r.can_catch(), true, "2P 的另一个 slot 在范围内也算")

func test_reveal_latches() -> void:
	var r := _r()
	r.feed(1, 0, Vector3(0, 0, 0))
	r.feed(0, 0, Vector3(0, 0, Config.HIDE_REVEAL + 1.0))
	r.tick(0.1)
	check_eq(r.revealed, false, "远的时候没现形")
	r.feed(0, 0, Vector3(0, 0, Config.HIDE_REVEAL - 1.0))
	r.tick(0.1)
	check_eq(r.revealed, true, "进 12 米现形")
	r.feed(0, 0, Vector3(0, 0, 40.0))
	r.tick(0.1)
	check_eq(r.revealed, true, "跑远也不收回现形")

func test_payouts_and_forfeit() -> void:
	var r := _r()
	r.tick(Config.HIDE_COUNTDOWN + 0.1)
	r.forfeit(0)
	check_eq(r.over, true, "放弃就收局")
	check_eq(r.winner, 1, "放弃的人判负")
	check_eq(r.coins_for(1), Config.HIDE_STAKE, "赢家 +5")
	check_eq(r.coins_for(0), -Config.HIDE_STAKE, "输家 -5")
	check_eq(r.coins_for(2), 0, "空座位不结账")

func test_hide_keys_and_flat_distance() -> void:
	var keys := HideRound.hide_keys("甲")
	check_eq(keys, ["甲", "甲|1"] as Array[String], "一个账号占两份世界快照键")
	check_eq(HideRound.flat_distance(Vector3(0, 5, 0), Vector3(3, 9, 4)), 5.0, "只算水平距离")
	check(not is_finite(HideRound.nearest_distance([], [Vector3.ZERO])), "空数组是 INF")

func test_snapshot_fields() -> void:
	var r := _r()
	var s := r.snapshot()
	for key in ["phase", "left", "seeker", "hider", "caught", "revealed", "can_catch", "over", "winner"]:
		check(s.has(key), "快照有 %s" % key)
```

- [ ] **Step 2: 跑一遍确认是红的**：`bash scripts/test.sh` → 期望 `无法加载 tests/test_hide_round.gd（语法错误？）` 或 `HideRound` 未定义。

- [ ] **Step 3: 实现** `game/net/hide_round.gd`

`tick`：`countdown` 递减 `left`，到 0 转 `seeking` 并把 `left` 设为 `HIDE_SEEK_SECONDS`；`seeking` 递减，到 0 转 `over`、`winner = hider_seat`；每次 tick 顺手算 `if not revealed and reveal_ok(_slots(seeker_seat), _slots(hider_seat)): revealed = true`。`over` 之后 `tick` 直接 return。
`feed`：只收 `slot` 在 0..1、`spot.is_finite()` 的坐标，存进 `_pos[seat][slot]`。
`can_catch`：`phase == "seeking"` 且 `nearest_distance(...) <= Config.HIDE_CATCH`。
`catch(seat)`：`seat == seeker_seat` 且 `can_catch()` 才 `over = true; winner = seat; caught = true; return true`，否则 `false`。
`forfeit(seat)`：`over` 或 `seat` 不是两个座位之一 → `false`；否则 `winner = 另一个座位`、`over = true`、`return true`。
`coins_for(seat)`：没 `over` 或不是参与座位 → 0；`seat == winner` → `Config.HIDE_STAKE`；否则 `-Config.HIDE_STAKE`。
`snapshot()` 按 Interfaces 里那张表返回，`phase` 用字符串。

- [ ] **Step 4: 跑测试确认绿，然后提交**

```bash
bash scripts/test.sh
git add game/net/hide_round.gd game/config.gd tests/test_hide_round.gd
git commit -m "捉迷藏：服务器规则模型 HideRound 与它的常量"
```

### Task 2: `NetRoom` 认 `hide`

**Files:**
- Modify: `game/net/room.gd`（`KINDS`、`_build_model`、`input`、`tick`）
- Test: `tests/test_net_room.gd`

**Interfaces:**
- Consumes: `HideRound`（Task 1）。
- Produces: `NetRoom.create("hide", ["甲","乙"])` 能建成，`model` 是 `HideRound`；`scene_path("hide")` 返回 `""`；`input(account, {"catch": true})` 走模型。

- [ ] **Step 1: 在 `tests/test_net_room.gd` 末尾加失败的测试**

```gdscript
func test_hide_room() -> void:
	var room := NetRoom.create("hide", ["甲", "乙"])
	check(room != null, "hide 房能建")
	check(room.model is HideRound, "模型是 HideRound")
	check_eq(NetRoom.scene_path("hide"), "", "捉迷藏不换场景")
	check_eq(room.input("甲", {"catch": "yes"}), false, "catch 必须是真布尔")
	room.tick(Config.HIDE_COUNTDOWN + 0.1)
	room.model.feed(1, 0, Vector3.ZERO)
	room.model.feed(0, 0, Vector3(0, 0, 1.0))
	check_eq(room.input("甲", {"catch": true}), true, "合法 catch 被收下")
	check_eq(room.over, true, "捉到就收局")
	check_eq(room.payouts(), {"甲": Config.HIDE_STAKE, "乙": -Config.HIDE_STAKE}, "两边各结一份")
```

- [ ] **Step 2: 跑测试确认红**：`bash scripts/test.sh` → `hide 房能建` 失败。

- [ ] **Step 3: 改 `room.gd`**：`KINDS` 追加 `"hide"`；`_build_model` 加 `"hide": model = HideRound.new()`；`input()` 里在 `bomb` / `race` 后面加一条 —— `catch` 必须 `typeof(...) == TYPE_BOOL`（假就不做，真就 `(model as HideRound).catch(seat)`），返回 `true`；`tick()` 加 `elif kind == "hide": (model as HideRound).tick(delta)`（不造 `press` 数组）。`payouts()` 不动。

- [ ] **Step 4: 跑测试确认绿，然后提交**

```bash
bash scripts/test.sh
git add game/net/room.gd tests/test_net_room.gd
git commit -m "捉迷藏：NetRoom 收下 hide 这一款"
```

### Task 3: `NetLobby`（角色、放弃、掉线、负账结算）

**Files:**
- Modify: `game/net/lobby.gd`
- Test: `tests/test_net_invite.gd`

**Interfaces:**
- Consumes: `NetRoom("hide", ...)`（Task 2）。
- Produces: `answer(from, to, kind, accept, online, now, role := "")`；`forfeit(name) -> void`（`leave_room` 走它）；`drop()` 对 `hide` 直接收局不结账；`_settle()` 支持负 payout（按余额封顶，实扣总额加给收钱那边）。

- [ ] **Step 1: 加失败的测试**（`tests/test_net_invite.gd`）

```gdscript
func _hide_room(lobby: NetLobby, role: String) -> Dictionary:
	lobby.invite("甲", "乙", "hide", ONLINE, NOW)
	return lobby.answer("甲", "乙", "hide", true, ONLINE, NOW, role)

func test_hide_roles() -> void:
	var saves := _fresh()
	var lobby := _lobby(saves)
	var r := _hide_room(lobby, "hide")
	check(bool(r["ok"]), "捉迷藏能开局")
	var model := lobby.room.model as HideRound
	check_eq(model.hider_seat, 1, "接受的人选了藏 → 1 号座藏")
	check_eq(model.seeker_seat, 0, "发起的人找")
	var lobby2 := _lobby(_fresh())
	_hide_room(lobby2, "seek")
	check_eq((lobby2.room.model as HideRound).hider_seat, 0, "接受的人选了找 → 发起的人藏")

func test_hide_bad_role() -> void:
	var lobby := _lobby(_fresh())
	lobby.invite("甲", "乙", "hide", ONLINE, NOW)
	var r := lobby.answer("甲", "乙", "hide", true, ONLINE, NOW, "nope")
	check_eq(str(r["error"]), "role", "角色不合法就拒")
	check(lobby.room == null, "拒了不开房")

func test_hide_payout_win_and_loss() -> void:
	var saves := _fresh()
	saves["甲"]["coins"] = 20
	saves["乙"]["coins"] = 20
	var lobby := _lobby(saves)
	_hide_room(lobby, "hide")
	lobby.room.tick(Config.HIDE_COUNTDOWN + 0.1)
	lobby.room.model.forfeit(1)          # 藏的人放弃
	lobby.tick(0.1)
	check_eq(int(saves["甲"]["coins"]), 25, "赢家 +5")
	check_eq(int(saves["乙"]["coins"]), 15, "输家 -5")

func test_hide_payout_short_on_cash() -> void:
	var saves := {"甲": {"coins": 3}, "乙": {"coins": 1}}
	var lobby := _lobby(saves)
	_hide_room(lobby, "hide")
	lobby.room.tick(Config.HIDE_COUNTDOWN + 0.1)
	lobby.room.model.forfeit(0)          # 找的人（只有 3 币）放弃
	lobby.tick(0.1)
	check_eq(int(saves["甲"]["coins"]), 0, "输家最多扣到 0")
	check_eq(int(saves["乙"]["coins"]), 2, "赢家只拿实际扣到的 1 币")

func test_hide_drop_ends_without_pay() -> void:
	var saves := _fresh()
	var lobby := _lobby(saves)
	_hide_room(lobby, "hide")
	lobby.drop("乙", PackedStringArray(["甲"]))
	check_eq(lobby.room.over, true, "有人掉线就立刻收局")
	lobby.tick(0.1)
	check_eq(int(saves["甲"]["coins"]), 0, "掉线不结账")
	check_eq(lobby.room.paid, false, "没写盘就不算结过账")
```

- [ ] **Step 2: 跑测试确认红**。

- [ ] **Step 3: 改 `lobby.gd`**
  - `MODELLED` 追加 `"hide"`。
  - `answer(...)` 多一个 `role := ""` 参数：只在 `accept` 为真且 `kind == "hide"` 时校验（不是 `"hide"` / `"seek"` → `{"ok": false, "error": "role"}`）；建完房后 `var hider := to if role == "hide" else from`、`var seeker := from if role == "hide" else to`，调 `(room.model as HideRound).assign(room.seat_of(hider), room.seat_of(seeker))`。
  - 新增 `func forfeit(name) -> void`：当前房是 `hide` 且 `seat_of(name) >= 0` → 调模型的 `forfeit(seat)` 并 `room.over = true`（让 `_settle` 照常在 `tick` 里跑）；否则退回 `leave(name, false)`。
  - `drop()`：`room.kind == "hide"` → `leave(name, false)`（收局、不结账）后 return。
  - `_settle()`：先算「负数扣、按余额封顶、记录实际扣到的总额 `pot`」，再把 `pot` 按各正数 payout 的比例分给收钱的人；正数只由赢家拿时和 `pot` 相等。
- [ ] **Step 4: 跑测试确认绿，然后提交**

```bash
bash scripts/test.sh
git add game/net/lobby.gd tests/test_net_invite.gd
git commit -m "捉迷藏：邀请选角色、放弃认输、掉线不结账、结算不许造币"
```

### Task 4: 服务器接线（喂位置、剔藏的人、`hide` 标记、协议版本）

**Files:**
- Modify: `game/net/server_main.gd`（`_on_move`、`_broadcast_world`、`_on_room_op` 的 `leave_room` 分支）
- Modify: `game/net/protocol.gd`（`VERSION := 10`）
- Test: `tests/test_net_room.gd`（`hide_keys` 已在 Task 1 覆盖，这里补 `_hide_view` 的纯函数）

**Interfaces:**
- Consumes: `NetLobby.forfeit`（Task 3）、`HideRound.feed / revealed / hide_keys`（Task 1）。
- Produces: `server_main._on_room_op` 的 `_` 分支改调 `_lobby.forfeit(me)`；`WORLD` 里多 `hide: bool`；找的人那份 `players` 里没有藏的人的 `账号` 与 `账号|1`（直到 `revealed`）。

- [ ] **Step 1: 先把「剔谁」抽成纯函数并写测试**

在 `HideRound` 里加（Task 1 已给它测试的落点）：

```gdscript
## 找的人这一份世界快照里该看见谁：没现形之前藏的人整个不在。
static func view_for(
	players: Dictionary, seeker: String, hider: String, revealed: bool
) -> Dictionary:
	if revealed or seeker == "" or hider == "":
		return players
	var out := players.duplicate(true)
	for key in hide_keys(hider):
		out.erase(key)
	return out
```

测试（`tests/test_hide_round.gd`）：

```gdscript
func test_view_for_hides_hider_when_not_revealed() -> void:
	var players := {"甲": {}, "乙": {}, "乙|1": {}, "丙": {}}
	var seen := HideRound.view_for(players, "甲", "乙", false)
	check_eq(seen.keys().size(), 2, "藏的人两份都剔掉")
	check(seen.has("甲") and seen.has("丙"), "自己和别人还在")
	check_eq(HideRound.view_for(players, "甲", "乙", true).keys().size(), 4, "现形之后照常")
```

- [ ] **Step 2: 跑测试确认红 → 实现上面的函数 → 确认绿**。

- [ ] **Step 3: 改 `server_main.gd`**
  - `_on_move`：存完 `session["slots"] = slots` 后，如果 `_lobby.room != null and _lobby.room.kind == "hide"`，取 `seat = _lobby.room.seat_of(str(session["name"]))`，`seat >= 0` 就 `(_lobby.room.model as HideRound).feed(seat, slot, spot)`。
  - `_broadcast_world`：先算 `hide_on := _lobby.room != null and _lobby.room.kind == "hide" and not _lobby.room.over`，以及 `seeker_account` / `hider_account`（从 `room.seats[model.seeker_seat]` / `[hider_seat]` 取）；给每个人发时 `players` 走 `HideRound.view_for(players, 这个人, hider_account, model.revealed)`，并给 body 加 `"hide": hide_on`。
  - `_on_room_op` 的 `answer` 分支：多传一个 `str(args.get("role", ""))`（Task 3 给 `answer` 加的那个参数）。
  - `_on_room_op` 的 `_` 分支（`leave_room`）改成 `_lobby.forfeit(me)`，`result` 照旧 `{"ok": true}`。
  - `protocol.gd`：`VERSION := 10`。
- [ ] **Step 4: 跑测试确认全绿，提交**

```bash
bash scripts/test.sh
git add game/net/hide_round.gd game/net/server_main.gd game/net/protocol.gd tests/test_hide_round.gd
git commit -m "捉迷藏：服务器喂位置、找的人看不见藏的人，协议升到 v10"
```

### Task 5: 客户端管线（不换场景、锁人、藏名字）

**Files:**
- Modify: `game/main.gd`（`_on_join_room`）
- Modify: `game/net/client.gd`（`WORLD` 里的 `hide` 收成一个字段）
- Modify: `game/player/player.gd`（`input_locked` / `speed_scale`）
- Modify: `game/ui/name_tag.gd`（`static var hidden`）
- Create: `game/hide/hide_game.gd`
- Create: `tests/test_hide_game.gd`
- Modify: `game/main.tscn`（加 `HideGame` 节点）

**Interfaces:**
- Produces: `HideGame`（`class_name HideGame extends Node`）纯函数 `static func is_seeker(session: Dictionary, my_seat: int) -> bool`、`static func locked(phase: String, seeker: bool) -> bool`、`static func speed_scale(phase: String, hider: bool) -> float`；
  `Player.input_locked: bool`、`Player.speed_scale: float`；`NameTag.hidden: bool`；`NetClient.hide_round: bool`（来自 `WORLD.hide`，森林里所有人靠它藏名字）。
- `HideGame` 在 `main.tscn` 里挂在 `Main` 下，`@export var panel_path: NodePath` 指向 `../HidePanel`（Task 6 建）。

- [ ] **Step 1: 写失败的测试**（`tests/test_hide_game.gd`）

```gdscript
extends TestBase

func _session(seeker: int) -> Dictionary:
	return {"kind": "hide", "game": {"phase": "countdown", "seeker": seeker}}

func test_is_seeker() -> void:
	check_eq(HideGame.is_seeker(_session(1), 1), true, "我的座位是找的人")
	check_eq(HideGame.is_seeker(_session(1), 0), false, "不是")

func test_lock_and_speed() -> void:
	check_eq(HideGame.locked("countdown", true), true, "找的人在倒数时被锁")
	check_eq(HideGame.locked("countdown", false), false, "藏的人满速去藏")
	check_eq(HideGame.locked("seeking", true), false, "找的人解锁")
	check_eq(HideGame.locked("over", true), false, "收了局一定要解锁")
	check_eq(HideGame.speed_scale("seeking", true), Config.HIDE_HIDER_SPEED, "找的阶段藏的人降速")
	check_eq(HideGame.speed_scale("countdown", true), 1.0, "倒数阶段不降速")
	check_eq(HideGame.speed_scale("over", true), 1.0, "收了局恢复满速")
```

- [ ] **Step 2: 跑测试确认红**。

- [ ] **Step 3: 实现**
  - `player.gd`：加 `var input_locked := false`、`var speed_scale := 1.0`；`_physics_process` 里读输入那段（`_read_input()` 之后）遇到 `input_locked` 就把 `input` / `dir` 置零，`speed *= speed_scale`（放在 `if leader != null` / `else` 两支都算完之后）。
  - `main.gd::_on_join_room`：开头加 `if str(_net.session.get("kind", "")) == "hide": return`（附一句注释：捉迷藏不换场景）。
  - `name_tag.gd`：`static var hidden := false`；`_process` 里 `visible = fade > 0.0 and not hidden`。
  - `client.gd`：加 `var hide_round := false`，`_drain` 的 `WORLD` 分支里 `hide_round = bool(body.get("hide", false))`（`close()` 里一并复位）。
  - `hide_game.gd`：`_process` 里 `var net := NetClient.of(get_tree())`；`NameTag.hidden = net != null and net.hide_round`（**所有人**都藏名字，含观战的人）；
    `var playing := net != null and net.in_room("hide")`，不 playing 就 `_release()`（解锁、恢复速度、面板收起）后 return；
    playing 时按 `net.session.game` 的 `phase` 给 `Player.of_seat(get_tree(), seat)` 设 `input_locked` / `speed_scale`，并把快照转给面板（Task 6）。
    收局（`over`）之后 `in_room()` 已经是 false，自然走 `_release()`。
  - `main.tscn`：加 `[node name="HideGame" type="Node" parent="."]` + `script` 与 `panel_path`（先留空，Task 6 填）。

- [ ] **Step 4: 跑测试确认绿，提交**

```bash
bash scripts/test.sh
git add game/hide/hide_game.gd game/main.gd game/main.tscn game/player/player.gd game/ui/name_tag.gd game/net/client.gd tests/test_hide_game.gd
git commit -m "捉迷藏：森林里不换场景的那层驱动，藏的人降速、找的人被锁"
```

### Task 6: 三块 UI（黑屏倒数 / 靠近发起 / 邀请横幅选角色）

**Files:**
- Create: `game/ui/hide_panel.gd`、`game/ui/near_panel.gd`
- Create: `tests/test_hide_panel.gd`、`tests/test_near_panel.gd`
- Modify: `game/ui/invite_panel.gd`、`tests/test_invite_panel.gd`
- Modify: `game/main.gd`、`game/main.tscn`

**Interfaces:**
- `HidePanel`（`extends CanvasLayer`）：信号 `catch_pressed`、`give_up_pressed`；方法 `set_target(name: String) -> void`、`show_state(state: Dictionary) -> void`、`close() -> void`；纯函数 `static func clock_text(seconds: float) -> String`（`95.4` → `"1:35"`）。
- `NearPanel`（`extends CanvasLayer`）：信号 `hide_pressed(to: String)`；方法 `set_target(name: String) -> void`（空串=收起）；纯函数 `static func nearest(world: Dictionary, at: Vector3, reach: float) -> String`（跳过带 `|` 的键，只比水平距离，返回最近的账号或 `""`）。
- `InvitePanel.answer_pressed(from, kind, accept, role)`；`kinds()` 里不出现 `hide`。

- [ ] **Step 1: 写失败的测试**

```gdscript
# tests/test_hide_panel.gd
extends TestBase
func test_clock_text() -> void:
	check_eq(HidePanel.clock_text(95.4), "1:35", "一分三十五秒")
	check_eq(HidePanel.clock_text(0.0), "0:00", "归零")

# tests/test_near_panel.gd
extends TestBase
func test_nearest_skips_two_p() -> void:
	var world := {
		"甲": {"x": 1.0, "z": 0.0}, "乙": {"x": 3.0, "z": 0.0},
		"乙|1": {"x": 0.2, "z": 0.0},
	}
	check_eq(NearPanel.nearest(world, Vector3.ZERO, 4.0), "甲", "跳过 2P 那份")
	check_eq(NearPanel.nearest(world, Vector3.ZERO, 0.5), "", "太远就不发起")
	check_eq(NearPanel.nearest({}, Vector3.ZERO, 4.0), "", "世界里没人")
```

`tests/test_invite_panel.gd` 追加：

```gdscript
func test_hide_not_in_list() -> void:
	check(not InvitePanel.kinds().has("hide"), "捉迷藏不进右上角面板")
	check_eq(InvitePanel.kind_name("hide"), "捉迷藏", "文案在表里")
```

- [ ] **Step 2: 跑测试确认红**。

- [ ] **Step 3: 实现**
  - `HidePanel`：一个全屏 `ColorRect`（黑，`mouse_filter = STOP` 在倒数时挡住误触）+ 中间大字（倒数 / 剩余时间 / 「捉到 X」按钮 / 「放弃」按钮）+ 底部结算文字。`show_state` 按 `game.phase` / `game.left` / `game.can_catch` / `game.over` 切内容；按钮只发信号。文案只用 ASCII 标点。
  - `NearPanel`：屏幕下方中间一条按钮「和 X 玩捉迷藏」，`set_target("")` 收起；`add_to_group("poi_panel")`（跟其它浮层一起让位右上角按钮）。
  - `invite_panel.gd`：`KIND_NAMES` 加 `"hide": "捉迷藏"`；新增 `const PANEL_SKIP: Array[String] = ["hide"]`，`kinds()` 里滤掉它；`_fill_banner` 遇到 `hide` 摆三个按钮（我藏 / 我找 / 拒绝），信号 `answer_pressed.emit(from, kind, true, "hide"|"seek")` / `(from, kind, false, "")`。
  - `main.tscn` 加 `HidePanel`、`NearPanel` 两个 `CanvasLayer`；`HideGame` 的 `panel_path` 填 `../HidePanel`。
  - `main.gd`：`near_panel.hide_pressed` → `_net.request("invite", {"to": to, "kind": "hide"})`；`_process` 里算最近的人并 `_near_panel.set_target(...)`（把 `Player.of_seat(tree, 0).global_position` 和 `_net.world` 传进去）；`hide_panel.catch_pressed` → `_net.send_input({"catch": true})`；`give_up_pressed` → `_net.request("leave_room")`；`_on_answer` 多收 `role`。

- [ ] **Step 4: 跑测试确认绿，提交**

```bash
bash scripts/test.sh
git add game/ui/hide_panel.gd game/ui/near_panel.gd game/ui/invite_panel.gd game/main.gd game/main.tscn tests/test_hide_panel.gd tests/test_near_panel.gd tests/test_invite_panel.gd
git commit -m "捉迷藏：黑屏倒数、靠近发起、横幅里选我藏还是我找"
```

### Task 7: 藏点（`HideSpots` + 森林接线 + 饭店屋顶能站人）

**Files:**
- Create: `game/world/hide_spots.gd`、`tests/test_hide_spots.gd`
- Modify: `game/config.gd`（`HIDE_SPOTS` 表）、`game/world/forest_gen.gd`、`game/world/restaurant.gd`、`game/world/stall.gd`、`game/world/start_gate.gd`

**Interfaces:**
- `Config.HIDE_SPOTS: Array[Dictionary]`，每项 `{"kind": "stone"|"crates"|"log"|"cave"|"cap", "pos": Vector3}`。
- `HideSpots`（`class_name HideSpots extends RefCounted`）：`static func build(parent: Node3D, trees: Array[Vector3], rng: RandomNumberGenerator) -> void`；纯函数 `static func climb_heights(kind: String) -> Array[float]`（这个 kind 每一级台阶的高度）、`static func spots() -> Array[Vector3]`。
- `ForestGen.trees: Array[Vector3]`（撒完树填上，`generate()` 里赋值）。

- [ ] **Step 1: 写失败的测试**（`tests/test_hide_spots.gd`）

```gdscript
extends TestBase

func test_steps_are_jumpable() -> void:
	for kind in ["stone", "crates"]:
		var heights := HideSpots.climb_heights(kind)
		var previous := 0.0
		for h in heights:
			check(h - previous <= Config.JUMP_HEIGHT * 0.8, "%s 的台阶 %.2f 米能跳上去" % [kind, h - previous])
			previous = h
		check(previous > 1.5, "%s 顶面高到能借力上树干（%.2f 米）" % [kind, previous])

func test_spots_spread_out() -> void:
	var spots := HideSpots.spots()
	check(spots.size() >= 12, "至少 12 处藏点")
	for i in spots.size():
		for j in range(i + 1, spots.size()):
			check(spots[i].distance_to(spots[j]) >= 6.0, "%d 和 %d 号藏点不挤在一起" % [i, j])
		for poi in Config.POI_SPOTS:
			check(spots[i].distance_to(poi) >= 6.0, "%d 号藏点不压在 POI 上" % i)
```

- [ ] **Step 2: 跑测试确认红**。

- [ ] **Step 3: 实现**
  - `Config.HIDE_SPOTS` 按设计文档那张表落 15 条：`stone` ×6（`(17,14) (-17,-16) (24,-18) (-24,16) (33,4) (-33,-4)`）、`crates` ×3（`(10.8,2)` 饭店墙外、`(4.6,-11)` 摊位侧面、`(-7,-13.2)` 校门口）、`log` ×2（`(26,6) (-26,-22)`）、`cave` ×2（`(30,18) (-30,-10)`）、`cap` ×2（`(14,28) (-14,-28)`）。
  - `HideSpots.build`：
    - `stone`：在 6 米内找最近的树，石头摆在「树心 → 配置点」方向上离树心 1.0 米处，0.9~1.2 米高的平顶圆柱（`CylinderMesh` + `CylinderShape3D`）。
    - `crates`：两个 `BoxMesh` 0.8 米木箱摞成台阶（0.8 / 1.6），朝目标建筑错开 0.9 米。
    - `log`：卧倒的圆柱（粗 1.6、长 6）+ 侧面开口（两块挖空样式的挡板，视觉上留洞），内部 `BoxShape3D` 空腔做成「能站进去」的形状。
    - `cave`：3 块大石（缩放过的 `SphereMesh`）+ `BoxShape3D` 外壳，单侧留 1.4 米宽 2.2 米高的开口。
    - `cap`：粗 0.9 米杆 + 3 米伞盖（`CylinderMesh` + 半球），杆有碰撞、伞盖不挡人但挡视线（伞盖做成不带碰撞的 `MeshInstance3D`）。
    - `climb_heights` / `spots` 是纯函数，`build` 里各 kind 的尺寸都从它们取，别写两份。
  - `forest_gen.gd`：`generate()` 里 `var spots := ForestGen.scatter_positions(rng, tree_count, radius, clear_radius, Config.POI_SPOTS + HideSpots.spots())`（`Array[Vector3]` 相加要先 `var keep: Array[Vector3] = []` 再 `append_array`），把 `spots` 存进 `trees`，在 `_build_rocks` 之后调 `HideSpots.build(self, trees, rng)`。
  - `restaurant.gd`：把 `Shell` 的单个 `shell_box`（4.4×2.9×4.0）拆成「墙 4.4×2.2×4.0 高 2.2」+ 「两块跟视觉屋顶同尺寸同角度的斜板」（`(2.6, 0.2, 4.6)`、位置 `(±1.15, 2.75)`、绕 Z ±`ROOF_ANGLE`），照 `tent.gd::_build_shell` 的写法。
  - `stall.gd`：给 `Awning` 加一个同尺寸的 `BoxShape3D` 碰撞体（放在现有的 StaticBody 里，没有就新建一个）。
  - `start_gate.gd`：`Lintel` 同理加碰撞（顶面在 3.0 米以上，箱子上得去）。
- [ ] **Step 4: 跑测试确认绿；`godot --path . --script res://tools/shot_ingame.gd` 截一张森林图，人肉看藏点位置**。
     另外把 15 处藏点逐个走一遍（桌面版即可，`godot --path .`）：每一处都要能进/能出、不被卡住；
     `stone` 要能「石 → 树干顶 → 树冠」，`crates` 要能上到屋顶/顶棚/门楣，`log` 和 `cave` 要能整个钻进去。

```bash
bash scripts/test.sh
git add game/world/hide_spots.gd game/world/forest_gen.gd game/world/restaurant.gd game/world/stall.gd game/world/start_gate.gd game/config.gd tests/test_hide_spots.gd
git commit -m "森林：能藏能跳的藏点，饭店屋顶和摊位顶棚真能站人"
```

### Task 8: 冒烟、截图工具、文档

**Files:**
- Modify: `scripts/net_smoke.sh`、`tools/net_smoke.gd`（按现有步骤风格加一段）
- Create: `tools/net_hide_shot.gd`（照 `tools/net_invite_shot.gd` 改）
- Modify: `AGENTS.md`（项目概述补 v8 一条 + 技术约束补捉迷藏的规矩）、`docs/perf-log.md`（藏点静态体数量待真机验）

**Interfaces:** 无新接口，只接线。

- [ ] **Step 1: `scripts/net_smoke.sh` 加一步**：A 邀请 B 玩 `hide` → B 以 `role:"seek"` 接受 → 两个客户端各收到 `SESSION(kind=hide)` →
  服务器把藏的人从找的人的 `WORLD` 里剔掉（检查 B 的 world 里没有 A）→ 拉近到 2 米 → B 发 `catch` → 结算：
  A 的存档 `-5`、B 的 `+5`。期望输出 `捉迷藏：两人进同一局，找的人看不见藏的人，捉到后各结 5 币`。

- [ ] **Step 2: 跑冒烟**：`bash scripts/net_smoke.sh` → 期望最后 `SMOKE OK`。

- [ ] **Step 3: `tools/net_hide_shot.gd`**：起两个客户端（照 `net_invite_shot.gd`），截三张 —— `shots/hide_near.png`（靠近弹按钮）、
  `shots/hide_countdown.png`（找的人黑屏倒数）、`shots/hide_catch.png`（捉到横幅）。

- [ ] **Step 4: 文档**：`AGENTS.md` 项目概述加一条 v8（捉迷藏怎么玩、`hide` 是第五种 kind、不换场景、
  `HideRound` 在服务器、藏点由 `ForestGen` 生成、名字全局隐藏、放弃认输 / 掉线不结账）；技术约束补三条：
  捉迷藏不换场景（`scene_path("hide") == ""`）、`HideRound` 只管规则不碰节点、藏点只由 `HideSpots` 生成。

- [ ] **Step 5: 全量验证 + 提交**

```bash
bash scripts/test.sh && bash scripts/net_smoke.sh
git add scripts/net_smoke.sh tools/net_smoke.gd tools/net_hide_shot.gd AGENTS.md docs/perf-log.md
git commit -m "捉迷藏：冒烟、截图工具与文档"
```
