# AGENTS.md

## 项目概述

菌子派对（FungiParty）— 安卓横屏单机 3D 小游戏，圆润几何风格的可爱卡通，玩家是一朵蘑菇。
- 引擎：Godot 4.7.2，Mobile 渲染器（真机 Redmi 24122RKC7C / Vulkan 1.3 已验证）
- 语言：GDScript；美术全部程序化生成（内置 mesh + MultiMesh），不依赖外部模型
- 平台：Android，单机离线，不上架商店
- v3：森林里七个 POI —— 校门（进教室偷吃）、摊位（开商店买皮肤）、起跑线（进 220m 障碍赛跑）、蘑菇圈（进传炸弹）、猫头鹰树（进猫头鹰喂食：长按张嘴接糖、混着屎、三关比总分）、饭店（花币吃饭回体力）、帐篷（睡觉过夜、换衣服）；体力按局扣，天色由体力派生，四款小游戏都是自包含单场景，名次/口数换蘑菇币
- v4：摊位从买断皮肤改成抽卡 —— 15 顶皮肤分五档（夯 / 顶级 / 人上人 / NPC / 拉完了），蘑菇币单抽 50、十连 450，50 抽硬保底，重复按档位退币，抽到第一顶自动穿上；高档皮肤靠长零件区分（剑 / 披风 / 角盔 / 皇冠 / 花 / 宽檐），衣柜按档位一行一组、没抽到的显示「？？？」
- v6：同屏双人 —— 二号位在森林里随时加入（右上角「＋ 加入」选体型 + 已拥有的皮肤），加入后两个人
  谁推摇杆谁带队，镜头跟着带队的那个；四款小游戏都变成两人同场：教室坐 0/1 号课桌、猫头鹰喂食坐 0/1 号位、
  传炸弹坐 0/1 号座各有一对投掷键、赛跑左右分屏各跟一台相机。币是共享钱包，两个人都各自结算再相加；
  二号位的形象只活在这次运行里（`Party` 静态状态），不写盘
- v7（进行中）：联机 —— 账号、存档、钱包、抽卡在服务器上（`game/net/`），启动菜单分「一个人玩 / 联网」；
  **共享森林已通**：每人每 0.1 秒报一次位置（`MOVE`），服务器每 0.1 秒广播一次世界（`WORLD`），别人是插值着走的替身（`game/world/remote_player.gd`），
  同屏 2P 也是世界里的一份（`账号|1`），不用单独登录。
  **邀请已通**：`invite` / `answer` 进 `game/net/lobby.gd`（同时只开一间房，谁玩谁付自己的体力），
  成局后两边各收一份 `SESSION` 换场景，局内输入走 `INPUT`、局内快照 20 Hz 回推。
  **教室、传炸弹、猫头鹰、赛跑已搬上服务器**（`game/minigame/classroom_round.gd` / `bomb_round.gd` / `owl_round.gd` / `race_round.gd`，结算在服务器）。
  **邀请的 UI 已通**：森林右上角「邀请」列出世界里的人、挑一款发邀请，别人邀请我时屏幕底下弹一条接受/拒绝
  （`game/ui/invite_panel.gd`，只发信号，发 op 在 `main.gd`）。
  **睡觉一天一次已通**：天色改由服务器世界时钟给（`game/net/clock.gd`，一天 = 真实 4 小时，`WORLD` 里带 `day`），
  睡觉只回体力不再拨太阳，`slept_day` 记在世界时钟的那一天，同一天再睡服务器回 `error: "slept"`、帐篷按钮置灰。
  接手联机先读 `docs/superpowers/plans/2026-10-25-v7-handoff.md`（现状、约束、下一步、坑都在那一份里）。
- v5：角色可换 —— 红蘑菇之外加了海鲜菇（细长杆 + 小扁帽 + 四根黑棍手脚 + 腮红，按 `refs/海鲜菇角色设计图.png`），帐篷里免费换；体型与皮肤解耦，15 顶皮肤两个角色都能戴
- 场景：`game/world/` 森林与 POI、`game/minigame/` 教室/赛跑/传炸弹/猫头鹰喂食、`game/skins/` 15 顶皮肤数据（`.tres`）与 `catalog.gd` 总表、`game/player/body/` 角色体型（红蘑菇 / 海鲜菇，`catalog.gd` 总表）、`game/ui/` HUD 与浮层

## 开发命令

```bash
godot --path . -e                                              # 打开编辑器
godot --path .                                                 # 桌面运行
bash scripts/test.sh                                           # 无头测试（先刷全局类缓存）
godot --path . --script res://tools/shot_body.gd               # 角色渲染成 shots/body_*.png（真窗口，看外观用）
godot --path . --script res://tools/shot_ingame.gd             # 进森林截一张 shots/ingame.png
godot --path . --script res://tools/shot_party.gd              # 二号位加入后截一张 shots/party.png
godot --path . --script res://tools/shot_race.gd               # 赛跑：倒数 / 跑动 / 结算面板各截一张 shots/race_*.png
godot --headless --path . --script res://tools/soak_party.gd   # 四款小游戏的双人分支无头过一遍（时间加速 10 倍）
godot --headless --path . --script res://game/net/server_main.gd -- --port 7000 --saves build/accounts  # 本机起服务器（上限 8 人）
bash scripts/net_smoke.sh                                      # 联机冒烟：起真服务器 + 客户端注册/抽卡/重连验存档
godot --path . --script res://tools/net_login_shot.gd -- --port 7000   # 桌面看一眼启动菜单和登录（shots/login*.png）
godot --path . --script res://tools/net_world_shot.gd -- --port 7000   # 桌面看一眼共享森林里的替身（shots/world.png）
godot --path . --script res://tools/net_invite_shot.gd -- --port 7000   # 桌面看一眼邀请：列表 + 横幅 + 接受后进教室（shots/invite.png）
bash scripts/deploy-server.sh 用户@主机                           # 手动发一次服务端（平时 push main 就自动上线，见 docs/server-deploy.md）
godot --headless --path . --export-debug "Android" build/app.apk   # 调试包，带 FPS/DRAW/TRI 信息条
bash scripts/export-release.sh                                      # 正式签名包 build/fungi_party_<版本>_arm64.apk
adb install -r build/app.apk
adb shell monkey -p com.tuzki.fungiparty -c android.intent.category.LAUNCHER 1
adb logcat -s godot                                            # 设备日志（脚本报错靠它）
adb exec-out screencap -p > shots/shot.png                     # 设备截图
# release 包需要自己配 keystore；朋友间分发用 --export-debug，装上就能玩
```

- Android SDK：`D:/dev/Android/Sdk`　JDK：`D:/dev/java/jdk-17.0.15.6-hotspot`
- MIUI 会拦 adb 注入输入，触摸只能人肉验；装机需在开发者选项里开「USB 安装」。
- 发布密钥在仓库外：`~/.fungi-party/fungi-party-release.keystore` + `password.txt`（别名 `fungi-party`），丢了就没法给已装机的包升级。CI 走 GitHub Secrets（`ANDROID_KEYSTORE_BASE64` / `_PASSWORD` / `ANDROID_KEY_ALIAS` / `_PASSWORD`），tag `v*` 触发 `release-android` 工作流出包并发 Release。
- debug 包和 release 包签名不同，互相覆盖安装要先卸载（卸载会清掉存档）。

## 技术约束

- Godot 锁定 4.7.2，渲染器 `mobile`（真机不支持 Vulkan 才整体退到 `gl_compatibility`）。
- 性能以真机帧率为准：中端机 60 FPS 以上，记录在 `docs/perf-log.md`。
- 禁止：实时 GI、SSAO、SSR、体积雾、每帧实例化节点。
- 大件几何一律 MultiMesh；球体分段不要用默认的 64×32。
- 虚拟摇杆自己用 `Control` + 触摸事件实现，不引第三方插件。
- 桌面截图先 `SetProcessDPIAware()` 再抓图，否则高 DPI 下只会拿到放大的裁剪图，误判 UI 布局。布局对错优先用运行期打印的控件矩形判断。
- 可调数字集中在 `game/config.gd` 的 `const`。
- 角色逻辑不引用 mesh 节点路径；外观只在 `game/player/mushroom_mesh.gd` 改。
- 教室是自包含单场景，节点间直接 `$` 引用；森林侧的跨场景引用（摊位/玩家）每帧惰性 `get_first_node_in_group`，别在 `_ready` 里查。
- 赛跑的跑者全在 `game/minigame/race_racer.gd`（RefCounted）：离线和联机同一份，真人摇杆只管左右、前进自动跑，
  「跳」不是物理而是「y 高过矮栏（`RaceField.LOW_HEIGHT`）就跨过去」，高栏照撞。别再往赛跑里塞 `CharacterBody3D`。
- 赛跑一局的座位 / 倒数 / 冲线 / 币都在 `RaceRound`：本机 tick 它，服务器那一局只把快照写进去再照旧渲染。
  真人输入分两种形状 —— 横移按着（`steer`），跳跃 / 冲刺点一下（`jump` / `dash` 立刻进模型，不排到 tick）。
- 体力与天色的公式只有 `game/systems/day.gd` 一套：单机的天色由体力派生；联机时天色归服务器的世界时钟
  （`game/net/clock.gd`，`DayLoop` 只读 `NetClient.clock`，不自己推、不落本机盘）。别处不许再算天色。扣体力只在小游戏 `_ready` 一处。
- 睡几号归服务器：`slept_day` 是账号字段，日子来自世界时钟（`NetOps.apply` 的 `world` 参数由服务器注入，客户端说不了算）。
  UI 置灰走 `NetClient.slept_today()`，和服务器那道门槛是同一个判断，别各写一遍。
- 皮肤外观只有一个入口 `MushroomMesh.use_skin()`；存档里的皮肤 id 一律走 `SkinCatalog.by_id()`，查不到就回落默认外观。
- 体型只有一套入口：`MushroomMesh` 是门面，几何在 `game/player/body/`（基类 `mushroom_body.gd` + 每体型一个子类）。加角色 = 加一个 `body_xxx.gd` + `BodyCatalog` 一条，别往 `build()` 里加 if。
- 零件的坐标基准是红帽（半径 0.70）：横向一律 `×(cap_radius/0.70)`、帽上的纵向跟 `cap_height`、披风从帽底挂到腰。新零件照这个写，否则换个体型就埋进杆里或飘在空中。
- 玩家的体型和皮肤一律走 `MushroomMesh.use_party_look(seat)`（森林本体、教室/猫头鹰/传炸弹/赛跑的座位共五处），NPC 永远是红蘑菇。
  只有 seat 0 会读存档；seat 1 的体型和皮肤来自 `Party` 的会话状态。
- 同屏双人只有一套规则：`Party.count()` 是人数，**人类固定占 0..count()-1 号座位**，人机从 count() 号往后。
  加小游戏时不要新写「谁是人」的判断，用 `Party.human(seat)` / `Party.name_of(seat)`。
- 二号位的形象不写盘（存档是单人的）：退出游戏就没了。帐篷里的「你 / 2P」座位行换的是选中那位：
  seat 0 走 `Save.set_character()` / `Save.equip()`，seat 1 走 `Party.set_body()` / `Party.set_skin()`。
- 森林里两个人谁推摇杆谁带队（`Player.should_swap()`）：带队的自由走、另一个追到他身后 side 米的侧后方，
  镜头跟着带队那个（两台 `Player` 各带一台 `CamRig`，只有领队那台 `current`）。
  `CamRig` 的拉远射线要排除所有 `player` 组（`CamRig.exclude_players()`），否则跟随者会把镜头顶到脸上。
- 找某一号座位的玩家一律用 `Player.of_seat(tree, seat)`，别用 `get_first_node_in_group("player")`（森林里有两个人）。
- 触屏按屏幕左右半分给两个人：按住类（教室 / 猫头鹰）走 `EatInput.pressing(player)`，摇杆/动作键走
  `TouchControls.move(i)` / `held(i)`。`TouchControls` 的 `@export var duo` 是「这张场景允许双人」，
  真的摆两组还得 `Party.joined()`（人数变了自动重摆）。
- 浮层里动态拼的文字只用 ASCII 标点：系统字体不一定有全角的 ？ （），真机上会显示成豆腐块。
- 双人赛跑用两个 `SubViewport` 分屏（共用同一份 `World3D`），垫在 `layer = -1` 的 CanvasLayer 上，
  否则晚加的 CanvasLayer 会把 HUD 盖掉。
- `SkinCatalog.PATHS` 是显式路径表（不用扫目录，导出包不可靠）。加一顶皮肤 = 加一个 `.tres` + 一条 PATHS。
- 帽子、脸、斑点、头顶零件的位置全部挂在 `cap_radius` / `cap_height` / `cap_base()` / `top()` 上，改帽子尺寸不要写死坐标。小游戏里的进度条、色块高度也按 `top()` 算。
- 非平凡逻辑先写测试，能抽纯函数的抽成 `static func`。
- 联机：`Save.remote` 非空就是「存档在服务器上、本机只是镜像」。镜像能随便读，写只能走 op；
  `Save.write()` 在联机模式下只把天色推给服务器，别的字段改了不算数。
- 客户端能发起的 op 只有 `NetOps.CLIENT_OPS`（存档纯函数）和 `server_main.ROOM_OPS`（要房间/会话状态，
  `invite` / `answer` / `leave_room`）那几条，两边都回 `OP_RESULT`。加 op 之前先想清楚「这个数客户端说了算吗」；
  `add_coins` 是一期小游戏还在本机跑时的临时口子，二期必须删。
- `NetProtocol.VERSION` 一变，老客户端就连不上。客户端和服务端要一起发版。
- 服务器上账号文件是唯一持久化的东西：写盘一律 `.tmp` + rename，昵称进文件名前必须过 `Accounts.valid_name()`。
- 森林里别人的位置走 `MOVE`（不进 op 队列，位置比 op 新），世界快照走 `WORLD`，两边都由 `NetClient` 收发；
  替身只显示、不碰撞、不读输入；同屏 2P 用 `账号|1` 这个键，客户端要把自己那两份从世界快照里剔掉。
- 人数上限 8、同时 1 个小游戏房：不是设计判断，是这台 2 核 2G / 5 Mbps 机器的实测天花板
  （8 人全量广播 1.1 Mbps；一个 Godot 无头进程常驻 94 MB，但一个 3D 房间就是几十 MB）。要更多先做距离裁剪。
- 服务端上线靠 `.github/workflows/deploy-server.yml`：push main（改 `game/**`、`project.godot`、
  `export_presets.cfg`）→ 无头测试 → 导出 Linux 无头构建 → rsync 到服务器 `~/fungi/` →
  `sudo -n systemctl restart fungi-party-server` → 验 UDP 7000 在监听。没有 HTTP 端点，所以健康检查是
  「进程活着 + 端口 bind 上」，不是 curl。一次部署会把在线的人踢下线，改协议版本等于立刻踢所有人。
  服务器侧布局、sudoers 规则、排错表全在 `docs/server-deploy.md`，改服务器布局先改那份文档。
- 服务器上**只跑 RefCounted 规则模型，绝不实例化 3D 场景**。一款游戏搬上服务器 = 一个 `*_round.gd`
  纯模型（tick 顺序照抄本地场景的 `_process`）+ `NetRoom._build_model()` 一条；客户端那条路只读快照。
- 局内快照**一帧只拍一次**再各人复制（`server_main` 的 `_push_session` / `_broadcast_session`）：
  传炸弹的快照会把「上次之后发生的事」清掉，重复拍等于第二个收到的人看不到事件。
- 快照里的 `earned` 只在服务器**真写盘之后**才带（`NetRoom.paid`，`NetLobby._settle` 里置位）：
  主动走人、开局 5 秒内被收掉的局一分不给，客户端也不许显示「+N 蘑菇币」。
- 局内快照 20 Hz，直接贴上模型值会一顿一顿：跑者/相机这类快速移动的视图要插值（`RacerVisual.FOLLOW`）。
- 客户端输入分两种形状：**按着**（教室 `press`）由 `NetRoom.tick()` 造数组喂模型；**点一下**（传炸弹 `throw`）
  在 `NetRoom.input()` 里立刻交给模型。加新游戏先想清楚它属于哪一种，别硬塞进 `press`。
- 网络来的东西全是信任边界：包的字节、昵称、op 名、op 参数，都要在服务器侧校验，不校验就当 0 处理是错的。
- 提交信息用中文。
