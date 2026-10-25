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
godot --headless --path . --script res://tools/soak_party.gd   # 四款小游戏的双人分支无头过一遍（时间加速 10 倍）
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
- 体力与天色只有 `game/systems/day.gd` 一套公式；别处不许再算天色。扣体力只在小游戏 `_ready` 一处。
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
- 提交信息用中文。
