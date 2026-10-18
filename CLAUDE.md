# AGENTS.md

## 项目概述

菌子派对（FungiParty）— 安卓横屏单机 3D 小游戏，圆润几何风格的可爱卡通，玩家是一朵蘑菇。
- 引擎：Godot 4.7.2，Mobile 渲染器（真机 Redmi 24122RKC7C / Vulkan 1.3 已验证）
- 语言：GDScript；美术全部程序化生成（内置 mesh + MultiMesh），不依赖外部模型
- 平台：Android，单机离线，不上架商店
- v3：森林里三个 POI —— 校门（进教室偷吃）、摊位（开商店买皮肤）、起跑线（进 220m 障碍赛跑）；两款小游戏都是自包含单场景，名次/口数换蘑菇币
- 场景：`game/world/` 森林与 POI、`game/minigame/` 教室与赛跑、`game/skins/` 皮肤数据（`.tres`）、`game/ui/` HUD 与浮层

## 开发命令

```bash
godot --path . -e                                              # 打开编辑器
godot --path .                                                 # 桌面运行
bash scripts/test.sh                                           # 无头测试（先刷全局类缓存）
godot --headless --path . --export-debug "Android" build/app.apk
adb install -r build/app.apk
adb shell monkey -p com.tuzki.fungiparty -c android.intent.category.LAUNCHER 1
adb logcat -s godot                                            # 设备日志（脚本报错靠它）
adb exec-out screencap -p > shots/shot.png                     # 设备截图
# release 包需要自己配 keystore；朋友间分发用 --export-debug，装上就能玩
```

- Android SDK：`D:/dev/Android/Sdk`　JDK：`D:/dev/java/jdk-17.0.15.6-hotspot`
- MIUI 会拦 adb 注入输入，触摸只能人肉验；装机需在开发者选项里开「USB 安装」。

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
- 非平凡逻辑先写测试，能抽纯函数的抽成 `static func`。
- 提交信息用中文。
