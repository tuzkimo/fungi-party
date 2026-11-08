# 森林捉迷藏（v8）设计

## 要解决什么

联机森林里现在只有「邀请 → 换场景 → 打一款小游戏」这一种玩法，森林本身只是走道。
捉迷藏是第一款**留在森林里打**的游戏：走到朋友跟前发起，30 秒藏、2 分钟找、捉到或超时定胜负，
输的给赢的 5 蘑菇币。它要吃到 3D 森林的便宜 —— 藏点决定胜负，而不是反应速度。
顺带把森林补上能藏能跳的地形（垫脚石、木箱、空心断木、石头洞、大蘑菇、能上人的屋顶）。

## 目标 / 非目标 / 反目标

- 目标：两个人（各自可以是同屏 2P）在世界里开一局捉迷藏；藏的人在找的人眼前是真的不存在；
  靠近才现形；2.5 米内才能「捉到」；5 币在服务器上结；一局最长 150 秒，卡不住森林。
- 目标：森林里十几处「不看不知道能上」的藏点，最好的一处是树冠。
- 非目标：真正往地下挖（改 `terrain.gd` 的网格）；三个人以上捉迷藏；人机；连胜 / 排行 / 打卡；
  道具（隐身、加速）；躲进去就不许被捉的「绝对安全区」；局内聊天。
- 反目标：变成赛跑（藏的人被找到后必须跑不过找的人）；空地上凭空按「捉到」也能赢；
  给钱包开印钞机（输家没钱也照赔 5 币）；一局卡在森林里（必须到点自己收）。

## 硬约束（现状决定的）

- **服务器没有 3D**，服务器上只跑 RefCounted 模型。所以「捉到」的距离判定只能用玩家自己 `MOVE`
  报上来的坐标（服务器 `_sessions[id].slots` 里已经有这份，10 Hz）；藏点几何只活在客户端，
  两边各自确定性生成，不走网络。
- `server_main._on_move` 把 y 夹在 `[0, 6]`：上树冠（树干碰撞顶 2.16~2.82 米）、上屋顶（2.9 米）
  都在里面，**不用改**；真挖地坑才会破这条，所以这一版不挖。
- 相机是第三人称、4 米拉远带避障：把人塞进实心树叶球里，镜头会被顶到脸上。所以藏点是
  「有一面敞开的」（断木、石洞单侧开口、伞盖下），不是钻进封闭几何里。
- 森林是确定性生成的（`ForestGen.seed_value = 1`），所以藏点也在客户端各自生成，两边看到的一样。
- 森林上限 8 人、同时 1 间房（`NetLobby.room`）；捉迷藏占的是那一间房。
- 只有 `OP_RESULT` 能清客户端的 `_inflight`：新增任何 op / 新参数都要回包。
- 房间类 op 走 `NetLobby`（要看会话状态），存档类 op 走 `NetOps`（纯函数）。

## 考虑过的做法

| 做法 | 换来什么 | 代价 | 结论 |
| --- | --- | --- | --- |
| A. 像四款小游戏一样换场景，做一个「捉迷藏竞技场」 | 复用 `NetRoom` + 客户端小节拍的整套模子，服务器完全可控 | 用不上森林的藏点（要把森林复制一份进场景），和「利用森林环境」的诉求冲突；世界里的其他人也一起消失 | 否 |
| B. **留在森林里；服务器开一个 `hide` 对局只管角色/计时/判定/结账；位置沿用 `MOVE`** | 藏点就是真森林；位置数据现成；`SESSION` 广播、`_settle`、掉线规则全部复用 | 地方几何服务器不知情（判定靠上报坐标）；森林里其他玩家看得见藏的人 | **选它** |
| C. 世界里跑，但胜负由客户端判 | 代码最少 | 客户端说了算 = 可以乱报；结账要动钱包，等于把钱包交给客户端 | 否 |

## 玩法（定稿）

1. **发起**：森林里走到别的账号跟前（水平 4 米内），屏幕底/侧弹一个「和 X 玩捉迷藏」按钮
   （和 POI 浮层同一套让位规则）。按了发 `invite {to, kind:"hide"}`。
2. **接受**：对方底下的横幅变成三个按钮 ——「我藏」「我找」「拒绝」。
   回答走 `answer {from, kind:"hide", accept, role:"hide"|"seek"}`。
3. **开局**：服务器建一间 `hide` 房（两名真人，2/3 号座空着不补人机），两边同时收到 `SESSION`。
   两边都不换场景 —— 本来就在森林里。
4. **藏**：30 秒。藏的人满速去藏；找的人输入锁死 + 全屏黑 + 大字倒数（这条纯客户端）。
5. **找**：120 秒。藏的人**速度减半**（3 米/秒，找的人 6 米/秒）—— 被找到之后光跑是跑不掉的，
   躲在藏点里才是正解。服务器把藏的人从「找的人」的 `WORLD` 里剔掉，直到两人水平距离 ≤ 12 米
   才放进来（现形 = 被发现了）。**现形是一次性锁存**：进了 12 米就一直看得见，不会跑远又消失 ——
   否则「刚看见、追两步又跟丢」这种手感毁掉整局。
6. **捉到**：两人水平距离 ≤ 2.5 米时，找的人屏幕上方弹「捉到 X」。按了发
   `send_input({"catch": true})`，**位置由服务器再验一次**，过才算捉到（赢），不过就什么也不发生。
7. **超时**：120 秒到，藏的人赢。
8. **结账**：赢的 +5 币、输的 −5 币（不够就按他现有的扣，赢的拿实际扣下来的那份），
   走 `NetLobby._settle`，和四款小游戏同一条路。**按「放弃」= 认输并结账**（自己认的，照付），
   **掉线不结账**（手机掉网不该赔钱）—— 不这么分，输的人在按钮上一按就能赖掉 −5，赢的那边白赢。
9. **期间**：所有人的头顶名字牌全藏起来（森林里其他人也藏）——不然在远处一眼看见「那个是 XX」。
   森林里其他玩家照常看得见藏的人（朋友局，聊天泄密算玩的一部分），但他们碰不到、捉不了。
10. **看得见的方向是单向的**：只从找的人那份 `WORLD` 里剔掉藏的人；藏的人一直看得见找的人。
    这不是漏洞 —— 躲猫猫本来就该「看着他走过来、然后憋住」；两面全瞎就变成站着等开奖，没得玩。
    跑是跑不掉的（藏的人 3 米/秒、找的人 6 米/秒），看着躲只是延长被发现的时间。
11. **2P 的距离判定**：两边**各自两个 slot 两两取最小**，不认「谁是带队的」——
    服务器本来就不知道谁在带队，多引入一个 leader 概念只会多一个要同步的字段。

## 关键决定

| 决定 | 理由 |
| --- | --- |
| `hide` 当成第五种 `NetRoom.KINDS`，但 `scene_path("hide")` 返回 `""` | 复用座位 / `SESSION` 20 Hz 广播 / `settle` / `drop`；`main._on_join_room()` 见 `""` 就**不换场景**，交给森林里的 `HideGame` |
| 藏 / 找由**接受的人**选 | 永远一个人当鬼会没人愿意发起；多一个 `role` 字段和两个按钮换公平 |
| 找的人看不到藏的人的坐标（服务器剔条目） | 「真藏」：不只是不画，客户端根本没有他坐标；顺带省得有人用透视 mod |
| 12 米才现形、2.5 米才能捉，现形后锁存 | 一局要有「发现 → 追 → 捉」三段，不是「点一下就有」；不给找的人 200 米外的雷达 |
| 捉迷藏**不进**右上角「邀请」面板 | 那面板能从 50 米外发邀请，会绕开「走到跟前才能发起」；`InvitePanel.kinds()` 里把 `hide` 排掉，只有 `near_panel` 发得出去（服务器仍然认 `hide` kind，只是没人能这么发） |
| 放弃 = 认输结账，掉线 = 不结账 | 放弃是主动认的，照付；掉线是意外，不罚。混成一条，输的一方按一下就赖掉了 5 币 |
| 藏的人在找的阶段降速一半 | 不降速时两边同速，跑起来永远捉不到；降速让「跑」这条策略输给「躲」 |
| 黑屏 + 冻结只在客户端 | 朋友局不值得为它做服务器权威；藏的人也没法看见找的人屏幕 |
| 5 币走 `NetLobby._settle`，赔额按输家余额封顶 | 复用现成的结账；不给「小号破产刷币」留门 |
| 藏点几何由 `ForestGen` 一处生成 | 树是程序化撒的，藏点必须按真实树位摆；放两处会互相踩 |

## 服务器侧

### `game/net/hide_round.gd`（新，RefCounted）

```gdscript
enum Phase { COUNTDOWN, SEEKING, OVER }
var phase := Phase.COUNTDOWN
var seeker_seat := 0
var hider_seat := 1
var left := Config.HIDE_COUNTDOWN      # 当前阶段剩余秒
var caught := false
var over := false
var winner := -1
var _pos := {}                          # 座位 → Vector3（来自 MOVE，可能缺）
```

- `assign_hider(seat)` / `assign_seeker(seat)`：`NetLobby` 建完房按 `role` 指定。
- `feed(seat, spot)`：只收有限的、y 在 `[0, 8]` 的坐标（服务器已经夹过一次，这里再验）。
- `tick(delta)`：倒数 → 找，找的 `left` 到 0 → `over`，`winner = hider_seat`。
- `catch(seat)`：只有 `seeker_seat == seat`、`phase == SEEKING`、且 `can_catch()`
  （两边坐标都有、最小水平距离 ≤ `HIDE_CATCH`，同屏 2P 取两人里最近的那个）才成立。
- `revealed := false`：一旦某一帧的最近距离 ≤ `HIDE_REVEAL` 就置位，**不回头**（`reveal_ok()` 是静态纯函数，
  只比较距离；锁存位在模型里）。快照带上它，服务器据此决定放不放藏的人进找的人的 `WORLD`。
- `coins_for(seat)`：赢家 `+HIDE_STAKE`，输家 `-HIDE_STAKE`，其余座位 0。
- `forfeit(seat)`：按「放弃」的人判负（对方赢），`over = true`，照常结账。
- `snapshot()`：`{phase, left, seeker, hider, caught, revealed, can_catch, over, winner}`。

### 其余服务器改动

- `NetRoom`：`KINDS += "hide"`；`_build_model()` 加一条；`tick()` 里 `hide` 只推 `HideRound`；
  `input()` 加一条 —— `catch` 必须是**真布尔**（项目规矩：不校验时 `bool()` 会抱运行时错误），
  且交给模型再验位置；`payouts()` 照旧遍历真人座位，只是会有负值。
- `NetLobby`：`MODELLED += "hide"`；`answer()` 多收 `role`（`hide` / `seek`，非法值回 `error:"role"`），
  建完房指定角色；`_settle()` 支持负 payout —— 先扣（按余额封顶），把实际扣到的总额加到赢家头上；
  `drop()` 对 `hide` 特判：**有一个真人掉线就收局且不结账**（一个人没法玩），
  避免现在的「剩下那个接着打完」把捉迷藏挂 120 秒。
  `leave_room`（按「放弃」）在 `hide` 里不走 `leave(me, false)`，走 `room.model.forfeit(me)`：认输照付。
- `server_main`：`_on_move` 里，如果当前房是 `hide`，把坐标顺手 `feed` 给模型；
  `_broadcast_world` 里，如果当前房是 `hide`：给「找的人」的那份 `players` 剔掉藏的人的两个 slot
  （`账号` 与 `账号|1`），并按 `HideRound.reveal_ok()` 决定放不放回来；`WORLD` 多带 `hide: true`
  （给所有人藏名字用）。
- `NetProtocol.VERSION` 9 → 10：`WORLD` 多一个字段、`answer` 多一个参数、多一种 kind，
  老客户端必须连不上（`InvitePanel` 不认识 `hide` 会照旧显示并接受，然后卡在森林里）。

## 客户端侧

- **`game/hide/hide_game.gd`（新，`Node`，挂在 `main.tscn`）**：森林里的这局游戏全在这。
  - `_ready`：拿到 `NetClient.of(tree)`，`NetRoom.scene_path("hide")` 是 `""` 的那条路把它激活。
  - `_process`：`NetClient.session` 是 `hide` 就按快照驱动 UI；不是就关掉浮层、解锁玩家。
  - 倒数阶段：找的人两台 `Player` 都 `input_locked = true`；藏的人不动。
  - 找阶段：藏的人两台 `speed_scale = Config.HIDE_HIDER_SPEED`（0.5）。
  - 收局：读 `earned` 显示 +5 / −5；`over` 之后清锁、恢复速度。
- **`game/ui/hide_panel.gd`（新，`CanvasLayer`）**：黑屏 + 倒数 / 剩余时间 / 「捉到 X」按钮 /
  「放弃」按钮 / 结算横幅。按钮只发信号，发 op 在 `hide_game.gd`。
- **`game/ui/near_panel.gd`（新，`CanvasLayer`）**：从 `NetClient.world` 里找最近的账号
  （`|1` 那几份是 2P，跳过），水平 4 米内弹「和 X 玩捉迷藏」。`add_to_group("poi_panel")` 会让位逻辑
  保持一套（`InvitePanel.poi_overlay_open()` 只看组里的 `_root.visible`）。
- **`game/ui/invite_panel.gd`**：`KIND_NAMES` 加 `"hide"`（横幅文案要用），但 `kinds()` 把它排掉
  （面板里不出现捉迷藏，避免 50 米外发邀请）；横幅按 kind 出按钮 —— `hide` 出「我藏 / 我找 / 拒绝」，
  其余照旧；信号改成 `answer_pressed(from, kind, accept, role)`。
- **`game/player/player.gd`**：加 `input_locked`（锁输入、保留重力和碰撞）和 `speed_scale`
  （乘在 `WALK_SPEED` / `RUN_SPEED` 上）。跟随者不读输入，两条都不影响他。
- **`game/ui/name_tag.gd`**：全局 `static var hidden := false`，`HideGame` 开局置位、收局复位；
  `_process` 里先看它。

## 藏点与环境（`game/world/hide_spots.gd`，新）

`ForestGen.generate()` 撒完树之后调 `HideSpots.build(parent, tree_spots, rng)`；配置点在
`Config.HIDE_SPOTS`（`[{kind, pos}]`）。撒树前把它们并进 keep-out 列表，树和石头不往藏点里长。

| kind | 尺寸 | 怎么用 | 数量 |
| --- | --- | --- | --- |
| `stone` | 0.9~1.2 米平顶石，成组时高差 ≤ 1.0 米 | 找到最近的树（6 米内），摆在它边上 → 跳石 → 跳上树干顶（2.16~2.82 米）→ 埋在树冠里 | 6 组 |
| `crates` | 0.8 米木箱两个，错开摆成台阶 | 摆在饭店 / 摊位 / 猫头鹰树的墙边 → 0.8 → 1.6 → 屋檐 2.4 → 屋顶 | 3 处 |
| `log` | 粗 1.6 米、长 6 米的倒木，侧面一个 1.4 米宽的洞 | 地面层藏点，里面站一个人，头顶留 2.2 米 | 2 |
| `cave` | 3 块大石垒 3 米高的小丘，单侧开口，内腔 2 × 2.4 米 | 「往下藏」的地面版，里面暗、外面看不出洞 | 2 |
| `cap` | 杆 0.9 米粗 + 3 米伞盖，盖高 2 米 | 站杆子背光面，身体挡掉一半；也是地标 | 2 |

- **饭店屋顶要顺手修一处**：`restaurant.gd` 的 Shell 是一个 4.4×2.9×4.0 的实心 box，
  顶面是平的 2.9 米，而视觉屋顶是两块斜板（脊线约 3.4 米）—— 站上去会插进斜板里。
  改成「墙 + 两块跟视觉同角度的斜板」的碰撞（照 `tent.gd::_build_shell` 的写法），屋顶才是真能站的。
- 反目标：不做隧道（相机 4 米拉远会撞墙）；洞和断木都「浅而宽」。
- 性能：全部走现成的 `MultiMesh` / 少量 box + `CollisionShape3D`，静态体数量比现在多约 40 个
  （现在已有 240 树干 + 40 石头），真机帧率记一条进 `docs/perf-log.md`。

## 数值（`Config` 新增）

```gdscript
const HIDE_NEAR_RANGE := 4.0      # 走到这么近才弹「捉迷藏」
const HIDE_COUNTDOWN := 30.0
const HIDE_SEEK_SECONDS := 120.0
const HIDE_REVEAL := 12.0         # 找的人这么近才看得见藏的人
const HIDE_CATCH := 2.5           # 这么近才能「捉到」
const HIDE_STAKE := 5
const HIDE_HIDER_SPEED := 0.5     # 找的阶段藏的人速度倍率
const HIDE_SPOTS: Array[Dictionary] = [...]
```

## 文件清单

新增：`game/net/hide_round.gd`、`game/hide/hide_game.gd`、`game/ui/hide_panel.gd`、
`game/ui/near_panel.gd`、`game/world/hide_spots.gd`、`tests/test_hide_round.gd`、
`tests/test_hide_spots.gd`、`tools/net_hide_shot.gd`。

改：`config.gd`、`net/protocol.gd`、`net/room.gd`、`net/lobby.gd`、`net/server_main.gd`、
`net/client.gd`（只在必要处）、`main.gd`、`main.tscn`（两个新 CanvasLayer + `HideGame`）、
`ui/invite_panel.gd`、`ui/name_tag.gd`、`player/player.gd`、`world/forest_gen.gd`、
`world/restaurant.gd`、`scripts/net_smoke.sh`、`AGENTS.md`。

## 测试与验收

纯逻辑（无头，`bash scripts/test.sh`）：

- `test_hide_round.gd`：倒数 → 找的相位与时钟；超时 → 藏的人赢；`catch` 只认找的人、
  只在 2.5 米内成立、坐标缺一就不成立；`reveal_ok` 的边界；`coins_for` ±5；快照字段齐全；
  同屏 2P 取最近那个 slot。
- `test_net_room.gd`：`hide` 能建、`input` 的 `catch` 非布尔被拒、`payouts` 有负值。
- `test_net_invite.gd`：`MODELLED` 含 `hide`；`role` 非法 → `error:"role"`；接受后座位角色对；
  `drop` 一个 hide 参与者 → 立刻收局、`payouts` 为空；`leave_room` → `forfeit`，双方照常 ±5。
- `test_hide_spots.gd`：每处藏点的攀爬链每一级高差 ≤ `JUMP_HEIGHT` 的一大半；
  站点之间、站点与 POI 之间不重叠；单个藏点占地够站人。
- `test_invite_panel.gd`：`hide` 横幅三个按钮、发出的 `role` 对；`kinds()` 里没有 `hide`（不进面板）。

端到端：

- `bash scripts/net_smoke.sh` 加一步：邀请 → 以「我藏」接受 → 服务器把藏的人从找的人的 `WORLD`
  里剔掉 → 拉近到 2 米 → `catch` → 赢家 +5、输家 −5（存档里能看到）。
- `godot --path . --script res://tools/net_hide_shot.gd -- --port 7000`：
  截三张图 —— 靠近弹按钮 / 找的人黑屏倒数 / 捉到横幅。
- 真机：两人两台手机走一遍；重点看黑屏那 30 秒、树冠藏、洞里镜头。

## 风险 / 待验

- **树冠藏是否真的「外面看不见」**：叶球是实心视觉，玩家在球心；从上/从侧面看会不会露出半截，真机看。
- **洞里镜头**：4 米拉远被墙顶短，看到的是自己后脑勺；洞做浅能否接受，真机看。
- **12 米现形**在手机小屏 + 雾气下够不够「突然」；`HIDE_REVEAL` 可能要从 12 调到 8。
- 藏的人降速一半会不会让「藏在开阔地」变成自杀（没有滑步，绕树很僵）；先按 0.5 上真机调。
- 服务器 `_broadcast_world` 现在按人发、每人一份；多一次距离比较，8 人规模无感，但别在这里加分配。
