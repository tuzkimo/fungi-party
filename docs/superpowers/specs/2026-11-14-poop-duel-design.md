# 森林扔粑粑（v9）设计

## 要解决什么

森林里现在有两类玩法：换场景的四款小游戏，和留在世界里打的捉迷藏。捉迷藏是「躲」，
缺一个正面对抗的：两个人在森林里互相扔粑粑，谁先被砸中三次谁输，输的给赢的 5 蘑菇币。

它和捉迷藏最大的区别是**弹药不是白的**：开局两边都是空手，森林里随机刷出几只屎壳郎在推粪球，
走过去抢（谁先碰到归谁），有粪球才能扔。所以这一局比的是三件事 —— 抢粪、瞄准、跑位。

## 目标 / 非目标 / 反目标

- 目标：两个人（各自可以是同屏 2P）在森林里打一局扔粑粑；最多 180 秒；三次命中定胜负；
  粪球从屎壳郎身上抢；5 币在服务器上结。
- 目标：瞄准是「转视角对准、点一下扔」的 FPS 手感，屏幕正中永远有一个准星告诉你会飞到哪。
- 非目标：3 人以上的混战；人机；掩体/遮挡判定（树干挡不挡得住粑粑）；蓄力、抛物线、
  弹道下坠；命中硬直或击退；脚步声、雷达、血条动画；局内聊天。
- 反目标：变成纯跑位游戏（弹药无限或满地都是）；变成看不见人的瞎子对射（射程之外就看不见对手）；
  给钱包开印钞机（输家没钱也照赔 5 币）；一局卡在森林里（必须到点自己收）。

## 硬约束（现状决定的）

- **服务器没有 3D**，只跑 RefCounted 模型。所以命中、抢粪的距离判定只能用玩家自己 `MOVE`
  上报的坐标（`server_main._on_move` 已经在喂 `HideRound`，同一条路能给 `PoopRound` 喂）。
- 服务器不知道树、石头、地形。**粑粑会穿过树**。朋友局接受这个；真要遮挡得把森林几何塞进服务器，
  不值。
- 森林里没有射击键：现在触屏只有摇杆 + 一个动作键（跳）。扔粑粑得新加一个按钮 ——
  放在 `PoopPanel` 里（和捉迷藏的「捉到」同一个位置、同一套做法），不动 `TouchControls`
  （改它等于动所有人所有场景的手感）。
- 同时只开一间房（`NetLobby.room`），本局占的也是那一间。
- `NetLobby.MODELLED` 和 `NetRoom.KINDS` 是两个各自的白名单，`kind` 要两边都加。
- 只有 `OP_RESULT` 能清客户端 `_inflight`；本次不加新 op（复用 `invite` / `answer` / `leave_room`）。
- 满槽 3 个粪球、没有冷却：弹药本身已经是节奏，再加冷却只是让人干等。

## 考虑过的做法

| 做法 | 换来什么 | 代价 | 结论 |
| --- | --- | --- | --- |
| A. 换场景，做一个「扔粑粑竞技场」 | 复用 `NetRoom` + 客户端的整套模子，服务器完全可控 | 用不上森林，和「大世界 FPS」的诉求冲突；世界里其他人消失 | 否 |
| B. **留在森林里；服务器跑 `PoopRound` 管屎壳郎、抢粪、飞行、命中、结账；位置沿用 `MOVE`** | 大世界就是场地；抢粪的赛跑是真的在跑；`SESSION` 广播 / `_settle` / 掉线规则全部复用 | 服务器不知道几何（穿树）；特效和准星全在客户端 | **选它** |
| C. 粑粑由客户端飞、客户端判命中 | 最少代码，手感能随手调 | 「我打中了」由客户端说了算，等于把一局的胜负交给客户端；钱包在后面 | 否 |

## 玩法（定稿）

1. **发起**：走到别的账号跟前（4 米内），`NearPanel` 多一个按钮「和 X 扔粑粑」，
   发 `invite {to, kind:"poop"}`。和捉迷藏一样**只能走到跟前发起**（不进右上角「邀请」面板）。
2. **接受**：对方底下的横幅出「我准备好了 / 拒绝」（没有角色可选，两边对称）。
3. **开局**：服务器建一间 `poop` 房（两名真人），两边同时收到 `SESSION`，都不换场景。
   不设倒数 —— 两边开局都是 0 弹药，第一件事本来就是去找屎壳郎。
4. **刷屎壳郎**：开局在两人连线的中点 25 米内随机撒 5 只屎壳郎，每只推着一个粪球，
   慢悠悠乱走（每 3 秒换一个方向，0.7 米/秒）。**粪球被抢走后 6 秒，那只屎壳郎再推一个出来。**
   屎壳郎不会被抢光：它是这一局的弹药来源，不是战利品。
5. **抢粪**：走到粪球 1.5 米内**自动捡**（不用按键）。槽满 3 个就捡不起来，球留在原地。
   两个人同时够得着同一个球时，座位号小的那个拿走（服务器按座位顺序判，两边算出来一样）。
6. **扔**：转视角对准，点右下的「扔」按钮。**只要槽里有一个就飞出去一个，朝相机的正前方**。
   正前方 = 相机朝向，所以屏幕正中的准星说的是真话（见「关键决定」）。
7. **命中**：粑粑直线飞（14 米/秒，不下坠），30 米内没撞到东西就消失。撞到对方（他自己或同屏 2P
   任一个）的胸口算命中。被砸中的那一边 `hits + 1`，屏幕闪一下红、响一声。
8. **胜负**：谁先被打中 3 次谁输。180 秒到了还没打完，**挨得少的那边赢**；打平（一样多）就谁也不付钱。
9. **结账**：赢的 +5 币、输的 −5 币（不够就扣到 0，赢的拿实际扣下来的），走 `NetLobby._settle`。
   **按「放弃」= 认输并结账**，**掉线 = 收局不结账**（和捉迷藏同一条规矩）。
10. **期间**：名字牌照常显示（这一局是公开的，别人可以站边上看），森林里其他玩家也能被砸吗——
    不能，只有这一局的两个人之间算命中。
11. **2P**：座位是账号，一个账号报两份位置（slot 0/1）。**被砸中的是账号**（谁被打中都算他头上），
    **抢粪也按账号**（两个人谁碰到都算抢到）。不引入「谁是带队的」。

## 关键决定

| 决定 | 理由 |
| --- | --- |
| 扔的方向只取相机的**偏航**（实现时定） | 森林是第三视角、相机一直俯着 18° 看人：照相机正前方扔，5 米外就掉到胸口以下，那一款根本打不着人。出手点和命中点都是胸口（`POOP_CHEST`），水平那一发才是唯一打得中的 |
| 准星画「胸口沿扔的方向飞一个射程」那一点的投影（实现时定） | 相机俯着看人时它落在正中偏上。固定正中在第三视角里是骗人的：屏幕上正中是你的帽子，不是弹道 |
| 粑粑**直线飞、不下坠** | 有重力准星就在说谎：要么准星画成抛物线（触摸屏上看不懂），要么让玩家自己补偿下坠（手机上瞄不了）。直线 = 屏幕正中就是落点，只需要「对准 + 预判对方跑位」 |
| 扔的方向由**客户端给**（相机前方向的单位向量），服务器只用它 | 方向是瞄准，不是胜负：服务器还是自己算飞行、自己算命中、自己扣弹药。方向给错了最多是打不中 |
| 飞行和命中**都在服务器** | 一条 `MOVE` 是 10 Hz，本地判命中要插值预测别人的位置，一套对不准就出「明明打中了」；服务器 20 Hz 直接拿最新坐标扫掠，简单且一致 |
| 每 tick 用**线段 vs 球**判命中，不用点 vs 球 | 14 米/秒 × 0.05 秒 = 0.7 米一步，点判会从人身上穿过去（靶子直径 1.2 米，差一点就漏） |
| 打完一下**没有硬直、没有击退** | 有硬直就是滚雪球（中一下 → 动不了 → 再中），三次很快就没了；没有硬直，被砸中只是数到 2，还能跑 |
| 抢粪**自动**，不按键 | 手上已经有摇杆 + 两个按钮，再加一个「捡」在手机上就是打架。走过去就是抢 |
| 槽满不能捡，球留着 | 不然「路过顺手吃掉」变成浪费别人的机会；留着，谁缺谁去拿 |
| 屎壳郎的位置**只由服务器算**，客户端只渲染快照 | 服务器是唯一说得清算谁抢到的地方；两边各算一遍要种子一致、逻辑一致，白搭 |
| 命中按**账号**不按 slot | 座位表就是账号，结账也是账号。给 2P 单独算血等于给一个账号两条命 |
| 不设倒数 | 开局 0 弹药，谁也没法立刻开打；多一个倒数就多一个要同步的阶段 |
| 180 秒平局不结账 | 平局没有输家，付钱给谁都是平白印币 |
| `poop` 也进 `InvitePanel.PANEL_SKIP` | 和捉迷藏同理：隔着森林发邀请会绕开「走到跟前」 |

## 服务器侧

### `game/net/poop_round.gd`（新，RefCounted）

```gdscript
var left := Config.POOP_SECONDS
var over := false
var winner := -1
## 每个账号的命中数 / 弹药
var hits := {}      # seat -> int
var ammo := {}      # seat -> int
## 屎壳郎：{x, z, yaw, ball: bool, timer, refill}；粪球的位置从它派生（`ball_at`），不单独存一份
var beetles: Array[Dictionary] = []
## 飞着的粑粑：{owner, x, y, z, dx, dy, dz, left}
var shots: Array[Dictionary] = []

func anchor(center: Vector3) -> void                               # 第一次拿到位置才撒屎壳郎（幂等）
func feed(seat: int, slot: int, spot: Vector3) -> void            # 同 HideRound，MOVE 喂进来
func throw_poop(seat: int, dir: Vector3) -> bool                  # 点一下：验弹药和方向，立刻出手
func tick(delta: float) -> void                                   # 走屎壳郎、补粪球、飞粑粑、判命中、判超时
func coins_for(seat: int) -> int
func forfeit(seat: int) -> bool
func snapshot() -> Dictionary
```

静态纯函数（好测）：

```gdscript
static func aim_ok(dir: Vector3) -> bool              # 有限、长度 > 0
static func segment_hit(from: Vector3, to: Vector3, chest: Vector3, radius: float) -> bool
static func ball_at(beetle: Dictionary) -> Vector2    # 球在屎壳郎身前（节点自己的 -Z）
static func loser_by_hits(hits: Array, humans: int) -> int   # 超时判：挨得最多的那个座位，平了 -1
```

- 命中判定：`shots` 每 tick 从旧位置往新位置扫，对**对方所有 slot 的胸口**
  （`pos + Vector3(0, Config.POOP_CHEST, 0)`）做 `segment_hit`。
- `hits[seat] >= Config.POOP_HITS` → `over = true`，`winner = 对方座位`。
- 超时：`left <= 0` → `over = true`，`winner = loser_by_hits(...)` 的另一边，平了 `winner = -1`。
- 抢粪：按座位顺序扫一遍，谁有 slot 在 `POOP_PICK_RANGE` 内且槽没满就 `ammo + 1`、
  那只屎壳郎标成「空手」（`refill` 起计）。
- 一个 `MOVE` 都没报过的人：`feed` 没喂过就没有坐标，抢不到球、也打不中他 —— 一切照「判不了就别判」。

### 接线（改动都很小）

- `game/config.gd`：追加 v9 一段常量（见下）。
- `game/net/room.gd`：`KINDS` 加 `"poop"`；`_build_model()` 加一条（`PoopRound.new(human_count(), session_seed)`；
  屎壳郎要等第一个 `MOVE` 到了才知道撒在哪，所以在这里**不** `anchor`）；
  `input()` 加 `kind == "poop"` 分支：只认 `dirx/diry/dirz` 三个数，立刻 `throw_poop`；
  `tick()` 加一条。`scene_path("poop")` 自然返回 `""`（不进 match 就是 `""`）。
- `game/net/lobby.gd`：`MODELLED` 加 `"poop"`；`drop()` 的 `kind == "hide"` 放宽成
  `kind in ["hide", "poop"]`；`_settle()` 里 `room.kind != "hide"` 放宽成
  `room.kind not in ["hide", "poop"]`（认输立刻得付）。
- `server_main.gd`：`_on_move` 那条喂位置的分支从 `room.kind == "hide"` 改成按模型判断
  （`room.model is HideRound` / `is PoopRound`，两行；后者顺带 `anchor(spot)` —— 屎壳郎撒在
  第一个报位置的人那儿，他一报就撒）；`_broadcast_world` 不用动（这一局不藏人）。
- `game/net/protocol.gd`：`VERSION` 10 → 11（多一种 kind；老客户端进去会卡在森林里占着房，必须重来）。

## 客户端侧

### `game/poop/poop_game.gd`（新，挂在 `main.tscn`，和 `HideGame` 并排）

照 `HideGame` 的形状写：`_process` 里读 `NetClient.session`，驱动面板和视角，收局时捡自己那份收益。

- `_net.in_room("poop")` 为真时：开面板、开准星、把相机拉远一点点（可选，不做也行）。
- **不改**任何人的 `input_locked` / `speed_scale`（这一局没人被冻住，也没有降速）。
- 面板按「扔」→ `_net.send_input({"dirx", "diry", "dirz"})`，
  方向取相机的 `-global_basis.z` 抹掉俯仰再归一化（`PoopGame.aim_dir`）。
- 弹药 / 命中次数 / 剩余时间直接读 `session.game`，20 Hz 就够，不做预测。
- 收局：`_finish()` 读 `earned` 显示一行字，4 秒后收起（照抄 `HideGame._finish`）。

### `game/poop/poop_field.gd`（新，挂在森林里，`Node3D`）

只负责 3D 表现，全部按快照画：屎壳郎（小球 + 六条短腿 + 前面一个粪球）、地上的粪球、
飞着的粑粑（带一小段拖尾）。位置按 `Config.NET_GHOST_LERP` 插值（20 Hz 直接贴上会一顿一顿，
和 `RacerVisual.FOLLOW` 同一个道理）。命中时来一下缩放/闪红。没有屎壳郎就不画。

### `game/ui/poop_panel.gd`（新，`CanvasLayer`）

只画和发信号，照 `HidePanel` 的写法：

- **准星**：屏幕正中一个空心圆 + 十字（细、半透明白，别挡视线）。因为粑粑是直线飞，
  正中就是落点 —— 不需要任何补偿。
- **顶上**：`你 0/3　他 0/3`、剩余秒数。
- **右下**：三个小圆点表示弹药（亮 = 有），下面一个「扔」按钮 —— 和「跳」那个动作键一样是个圆的、
  一样半透明，摆在它上面一格（`PRESET_BOTTOM_RIGHT`，112×112）。正中那块地留给准星和视野。
- **左上**：`放弃`（体力条下面）。
- **结算**：一行字「你赢了 +5 蘑菇币 / 你输了 5 蘑菇币 / 这一局没算钱」。
- 动态拼的文字只用 ASCII 标点。

### 入口（改两处已有的）

- `game/ui/near_panel.gd`：多一个「和 X 扔粑粑」按钮（两个按钮竖着排），发 `poop_pressed`。
- `game/main.gd`：`_on_near_poop` → `invite {kind:"poop"}`；`_near_target()` 的判断从
  「在捉迷藏里」放宽成「在任何一局里」（`NetClient.in_any_room()`，新的一行函数）；
  `_on_join_room()` 的 `kind == "hide"` 改成 `NetRoom.KINDS.has(kind)`（`scene_path` 为空的都不换场景）。
- `game/ui/invite_panel.gd`：`PANEL_SKIP` 加 `"poop"`；接受时 `poop` 不需要 `role`。

## 常量（全部进 `game/config.gd`）

```gdscript
# v9 森林扔粑粑（留在森林里打的第二款）
const POOP_NEAR_RANGE := HIDE_NEAR_RANGE
const POOP_SECONDS := 180.0
const POOP_HITS := 3
const POOP_STAKE := 5
const POOP_AMMO_MAX := 3
## 直线飞，不下坠：准星才说真话
const POOP_THROW_SPEED := 14.0
const POOP_RANGE := 30.0
const POOP_HIT_RADIUS := 0.6
const POOP_CHEST := 0.7
const POOP_BEETLES := 5
const POOP_SPAWN_RADIUS := 25.0
const POOP_BALL_REFILL := 6.0
const POOP_PICK_RANGE := 1.5
const POOP_BEETLE_SPEED := 0.7
const POOP_BEETLE_WANDER := 3.0
```

## 顺手修的一个 bug：从小游戏回森林就卡在门口

真机上撞到的：A 去玩了一款小游戏，回来以后 B 看见 A 定在游戏入口一动不动，走过去也发起不了任何东西。

- **根因**在 `server_main._on_move`：一步超过 `NET_MOVE_MAX_STEP * 2`（2.4 米）的 MOVE 被**整条丢掉**，
  而服务端那份旧坐标没被更新 —— 下一条 MOVE 又拿同一份旧坐标去比，于是永远对不上。
  回森林是**换场景重开**：人在原点 `(0, 0.2, 0)` 出生，而校门在 `(0, 0, -14)`，一跳 14 米，必然被拒。
- **修法**：超了就按比例**夹住**（`server_main.clamp_step`），不丢整条。服务端永远在追，客户端 10 Hz 接着报，
  14 米大概 0.6 秒追上（看起来像他从门口小跑回来），之后再无卡住。速度上限没变（还是 24 m/s 的报位置上限）。
- **回归**：`tests/test_move_clamp.gd`（夹住的长度、方向、连续两条都在前进、原地不算出 NaN）、
  `tools/net_move_repro.gd`（起真服务器 + 两个客户端，换场景那一跳之后跟不跟得上）。
- 这个 bug 对扔粑粑是致命的（坐标就是命中点和出手点），所以必须在写这一款之前修掉。

## 测什么

- `tests/test_poop_round.gd`（纯模型）：开局 0 弹药 5 只屎壳郎；抢粪要距离、槽满取不了、抢走 6 秒后补一个；
  扔要方向合法且有弹药；直线飞命中胸口算一次；一步 0.7 米不会从人身上穿过去；
  三次命中收局且赢家正确；180 秒超时按挨得少的判、打平不付钱；没报过位置时打不中也抢不到；
  2P 两个 slot 任一被打中都算这个账号；认输照付；`coins_for` 是 ±5；
  `snapshot` 里 `beetles/shots/hits/ammo/left` 齐全，且塞得进 `NetProtocol.MAX_PACKET`。
- `tests/test_poop_game.gd`（客户端纯函数）：顶部那句文案、结算那行字、弹药点的亮灭。
- `tests/test_net_room.gd` 补：`create("poop", ...)` 能建、`scene_path("poop") == ""`、
  `input` 收 `throw` 且非法方向被拒。
- 冒烟：`scripts/net_smoke.sh` 后面加一段（两个人开局 → 抢粪 → 扔 → 收局），或者单独
  `tools/net_poop_shot.gd` 桌面看一眼森林里的屎壳郎、准星和 HUD。
