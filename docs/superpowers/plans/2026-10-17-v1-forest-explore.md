# v1 森林自由探索 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在安卓真机上跑一个能用触屏走动、跳跃的蘑菇角色，身处一片有昼夜光照的森林里。

**Architecture:** 单一 Godot 工程，纯程序化几何（无外部模型）。角色由 `SurfaceTool` 参数化生成，逻辑与 mesh 分离；可测试的数学（移动曲线、昼夜角度、摇杆解析、相机避让）写成 `static func`，由无头测试覆盖；Node 脚本只做编排。每期以「APK 装到真机跑」收尾，性能靠屏上 HUD 读真数。

**Tech Stack:** Godot 4.7.2（Mobile 渲染器）、GDScript、GUT 之外的零依赖自建无头测试、adb 部署。

**Spec:** `docs/superpowers/specs/2026-10-17-fungi-party-design.md`

## Global Constraints

- Godot 版本锁定 **4.7.2**（`winget install GodotEngine.GodotEngine`）。渲染器 `rendering/renderer/rendering_method="mobile"`；phase 0 若真机不支持 Vulkan，整体改为 `gl_compatibility`，不要两条路并存。
- 横屏（`display/window/handheld/orientation=1`），基准分辨率 1280×720，`canvas_items` 拉伸。
- 性能：中端机 60 FPS、低端机 ≥30；可见三角面 <60k，draw call <150。
- 禁止：实时 GI、SSAO、SSR、体积雾、每帧实例化节点。
- 虚拟摇杆自己用 `Control` + 触摸事件实现，不引任何插件。
- 所有可调数字集中在 `game/config.gd` 的 `const` 里，不散落在脚本中。
- 角色逻辑（移动/动画/状态）不引用任何 mesh 节点路径；外观只在 `mushroom_mesh.gd` 里改。
- 提交信息用中文，符合中文开发习惯。
- `AGENTS.md` 与 `CLAUDE.md` 各 ≤50 行，格式参照 wee-count：项目概述 / 开发命令 / 技术约束。
- 测试命令统一为：`godot --headless --path . --script res://tests/run_tests.gd`。

## Review Focus

以下五类是 spec 暗示但没有任何单个任务的测试会覆盖、且最容易在真机上咬人的情况。每条已在对应任务里加了验证步骤。

1. **低端机首帧卡顿**：程序化 mesh 生成 + 上传若在 `_ready()` 里做，进场景会掉帧。`test_mushroom_mesh.gd` 断言生成耗时 <50ms；真机上还要看一眼进场景的瞬间。
2. **多指同时按**：摇杆和跳跃按钮必须各认各的手指，第一根手指离屏时不能把移动向量清成跳跃。`touch_controls.gd` 用 finger index 绑定，测试断言「手指 0 在摇杆、手指 1 在跳跃」时两者互不干扰。
3. **相机被树夹住**：`SpringArm3D` 撞到树会缩到 0，贴进角色头部。`clamp_arm_length()` 保证最短 1.2m，并禁止相机低于地面 0.5m。
4. **低帧率穿透**：一帧 delta 变大时角色移动会穿过树干。`accelerate()` 内部把 delta 夹到 1/30，测试断言大 delta 下位移不超过单帧最大步长。
5. **安全区**：横屏切岛/挖孔屏会把摇杆压到边缘不可达。UI 用 `Control` 的 safe area，真机步骤里手动确认两个控件都在拇指可达区。

---

### Task 1: 工程落地到真机（scaffold + 首帧 HUD）

**Files:**
- Create: `.gitignore`、`AGENTS.md`、`CLAUDE.md`、`project.godot`、`export_presets.cfg`、`game/main.tscn`、`game/ui/debug_hud.gd`、`game/ui/debug_hud.tscn`、`game/config.gd`

**Interfaces:**
- Produces: `game/main.tscn` 为启动场景（`run/main_scene`）；`Config` 单例常量（`game/config.gd`，`class_name Config`）；全局可用命令 `godot`。

- [ ] **Step 1: 写 `AGENTS.md`（≤50 行）**

三段：项目概述（菌子派对，Godot 4.7.2 程序化几何、安卓横屏单机）、开发命令（`godot --path . -e` 开编辑器、`godot --path .` 运行、无头测试命令、`godot --headless --export-debug "Android" build/app.apk` 导出、`adb install -r build/app.apk` 装机）、技术约束（抄 Global Constraints 六条：版本、渲染器、性能预算、禁止项、参数集中、提交中文）。`CLAUDE.md` 复制同一内容。

- [ ] **Step 2: `git init` 并写 `.gitignore`**

忽略：`.godot/`、`build/`、`*.apk`、`*.aab`、`skins/local/`、`.vscode/`、`export_credentials.cfg`。

- [ ] **Step 3: 安装 Godot 并验证**

```bash
winget install GodotEngine.GodotEngine --accept-package-agreements --accept-source-agreements
godot --version
```
Expected: 输出 `4.7.2.stable...`。若 `godot` 不在 PATH，找到 winget 安装目录加入 PATH 后重试。

- [ ] **Step 4: 写 `project.godot`**

关键设置：`run/main_scene="res://game/main.tscn"`、`rendering/renderer/rendering_method="mobile"`、`display/window/handheld/orientation=1`（landscape）、`display/window/size/viewport_width=1280`、`viewport_height=720`、`display/window/stretch/mode="canvas_items"`、`physics/common/physics_ticks_per_second=60`、`application/config/name="菌子派对"`。

- [ ] **Step 5: 写 `game/config.gd`**

```gdscript
class_name Config
const WALK_SPEED := 3.0
const RUN_SPEED := 6.0
const ACCEL := 20.0
const DECEL := 25.0
const GRAVITY := 24.0
const JUMP_HEIGHT := 1.5
const AIR_CONTROL := 0.35
const SQUASH_MAX := 0.2
const DAY_LENGTH_SECONDS := 600.0
const CAM_MIN_LENGTH := 1.2
```

- [ ] **Step 6: 写 `debug_hud.tscn` + `debug_hud.gd`**

一个 `CanvasLayer` 下的 `Label`，左上角，`_process` 里更新文本：`FPS %d  DRAW %d  TRI %d`，draw call / 三角面取 `RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)` 与 `..._TOTAL_PRIMITIVES_IN_FRAME`。`game/main.tscn` = 根 `Node3D` + 这个 HUD。

- [ ] **Step 7: 写 `export_presets.cfg`**

一个名为 `Android` 的 preset：`package/unique_name="com.tuzki.fungiparty"`、`package/name="菌子派对"`、`architectures/arm64-v8a=true`、其余默认、`gradle_build/use_gradle_build=false`、签名留空（用 Godot 自动生成的 debug keystore）。

- [ ] **Step 8: 下载导出模板**

用 `godot --version` 得到的完整版本号拼出 `https://github.com/godotengine/godot/releases/download/<版本>-stable/Godot_v<版本>-stable_export_templates.tpz`，解压到 `%APPDATA%/Godot/export_templates/<版本>.stable/`（把解压出的 `templates/` 内层目录重命名为 `<版本>.stable`）。

- [ ] **Step 9: 导出并在真机运行（验证）**

```bash
godot --headless --path . --export-debug "Android" build/app.apk
adb install -r build/app.apk
adb shell monkey -p com.tuzki.fungiparty -c android.intent.category.LAUNCHER 1
```
Expected: 手机上出现 FPS/DRAW/TRI 标签。

若报 `no export preset named "Android"`，用 `godot --path . -e` 打开编辑器手工加一次 preset 再导出。若报 SDK/JDK 路径缺失，在编辑器 Editor Settings → Export → Android 填入 `D:/dev/Android/Sdk` 与 `D:/dev/jdk-17...` 的路径。若报缺少 build-tools/platform，只装报错里点名的那个版本。

**Step 10: 记录真机渲染器**
```bash
adb shell pm list features | grep -i vulkan
```
有输出 → 保持 `mobile`。无输出 → 把 `project.godot` 改成 `gl_compatibility`，重做 Step 9，并在 `AGENTS.md` 技术约束里改掉驱动那行。

- [ ] **Step 11: 提交**

```bash
git add -A && git commit -m "搭建 Godot 工程骨架，能在安卓真机运行并显示帧率"
```

---

### Task 2: 无头测试脚手架

**Files:**
- Create: `tests/run_tests.gd`、`tests/test_base.gd`、`tests/test_smoke.gd`

**Interfaces:**
- Produces: `TestBase`（`class_name TestBase`，方法 `check(cond: bool, msg: String)`、`check_eq(a, b, msg: String)`、计数器 `failures`、`total`）；运行命令约定（见 Global Constraints）。

- [ ] **Step 1: 写 `tests/test_base.gd`**

```gdscript
class_name TestBase
var failures := 0
var total := 0
func check(cond: bool, msg: String) -> void:
	total += 1
	if not cond:
		failures += 1
		printerr("FAIL: %s" % msg)
func check_eq(actual: Variant, expected: Variant, msg: String) -> void:
	check(actual == expected, "%s (期望 %s, 实得 %s)" % [msg, expected, actual])
```

- [ ] **Step 2: 写 `tests/run_tests.gd`**

`extends SceneTree`。`_initialize()`：扫 `res://tests/` 下所有 `test_*.gd`（跳过 `test_base.gd`），`load()` 后 `new()`，反射出所有以 `test_` 开头的方法逐个调用，累加 `total/failures`，`print` 汇总，最后 `quit(1 if failures > 0 else 0)`。

- [ ] **Step 3: 写 `tests/test_smoke.gd`**

```gdscript
extends TestBase
func test_smoke() -> void:
	check_eq(1 + 1, 2, "冒烟")
```

- [ ] **Step 4: 跑通并确认失败能被发现**

```bash
godot --headless --path . --script res://tests/run_tests.gd
```
Expected: 汇总显示 1 个测试 0 失败，退出码 0（`echo $?`）。然后把 `test_smoke` 里的期望临时改成 `3`，重跑，确认退出码 1、打印 FAIL，再改回。

- [ ] **Step 5: 提交**

```bash
git add tests && git commit -m "加零依赖无头测试脚手架"
```

---

### Task 3: 蘑菇角色外观（程序化 mesh）

**Files:**
- Create: `game/player/mushroom_mesh.gd`、`game/player/mushroom.tscn`、`tests/test_mushroom_mesh.gd`

**Interfaces:**
- Produces: `MushroomMesh`（`class_name MushroomMesh extends Node3D`，导出参数 `cap_radius: float = 0.9`、`cap_height: float = 0.55`、`spot_count: int = 7`、`body_height: float = 1.0`、`tint_cap: Color`、`tint_body: Color`；方法 `build() -> void` 生成子节点）。`mushroom.tscn` 根节点为 `Node3D`，含 `MushroomMesh` 子节点与一个 `CollisionShape3D`（胶囊，半径 0.45、高 1.2，中心 y=0.9）。

- [ ] **Step 1: 写失败测试 `tests/test_mushroom_mesh.gd`**

断言：`MushroomMesh.new().build()` 之后 `get_child_count() >= 6`（伞盖、伞盖描边、身体、左手、右手、脸）；连续两次 `build()` 之后子节点数不翻倍（可重入）；`build()` 耗时 <50 ms（Review Focus 1）。

- [ ] **Step 2: 跑测试确认失败**

```bash
godot --headless --path . --script res://tests/run_tests.gd
```
Expected: FAIL（`MushroomMesh` 未定义）。

- [ ] **Step 3: 实现 `game/player/mushroom_mesh.gd`**

用 `SurfaceTool` 逐部件生成 `ArrayMesh` 并挂到各自 `MeshInstance3D`（描边件复用同一 mesh、材质换成 inverted hull）。形状：
- 伞盖：UV 球体压扁，`SphereMesh` 设 `radius=cap_radius`、`height=cap_height`，下沿略收回（y 方向缩到 0.55）。
- 白斑：`spot_count` 个扁平小球贴在伞盖表面，位置沿伞盖法线偏移 0.02，尺寸随 `cap_radius` 缩放。
- 身体：`CapsuleMesh`，半径 0.45、高 `body_height`，底部略外扩（水滴感）。
- 手 ×2：扁平椭球（`SphereMesh` 缩放 `(0.28, 0.12, 0.42)`），位于身体两侧 `±0.55`，略向前。
- 脸（在伞盖上，不是身体）：两个黑色小球做眼睛 + 一条压扁的环段做嘴；眼睛在伞盖正面 y 略高于中心。
- 肚子：白色压扁球贴片 + 一个由两个细长方体交叉成的黑色 ×。
- 描边：伞盖、身体、手各挂一份 inverted-hull 副本（`BaseMaterial3D`，`cull_mode=CULL_FRONT`、`grow=true`、`grow_amount=0.02`，不需要 shader）。
- 配色：`tint_cap` 默认红 `Color(0.90, 0.22, 0.20)`，`tint_body` 米色 `Color(0.96, 0.78, 0.62)`。

- [ ] **Step 4: 跑测试确认通过**

Expected: 3 个断言全过，耗时断言 <50ms。

- [ ] **Step 5: 真机看脸（人工判断，不要自动化）**

把 `mushroom.tscn` 临时放进 `main.tscn`，正对相机，导出装机，`adb exec-out screencap -p > shots/task3.png` 截图。对照 `refs/Creation_Image_1792213174285_1.png` 检查：脸在伞盖上、手在两侧、肚子上有 ×。不调细节，只确认结构对。

- [ ] **Step 6: 提交**

```bash
git add game/player tests && git commit -m "程序化生成蘑菇角色（伞盖、白斑、手、脸、描边）"
```

---

### Task 4: 移动手感与程序动画

**Files:**
- Create: `game/player/movement.gd`、`game/player/player.gd`、`tests/test_movement.gd`
- Modify: `game/player/mushroom.tscn`（挂 `CharacterBody3D` 与脚本，`MushroomMesh` 移入其中）

**Interfaces:**
- Consumes: `Config` 常量、`MushroomMesh`。
- Produces:
  - `Movement.accelerate(current: Vector3, target: Vector3, accel: float, decel: float, delta: float) -> Vector3` — 水平面内按 accel/decel 向 target 逼近，不超调；`delta` 内部夹到 `1.0/30.0`（Review Focus 4）。
  - `Movement.jump_velocity(gravity: float, height: float) -> float` — `sqrt(2*g*h)`。
  - `Movement.squash_stretch(vertical_speed: float, max_effect: float) -> Vector3` — 上升拉长（y>1）、下降压扁（y<1），速度归零回到 `Vector3.ONE`，t 为 `clampf(abs(vertical_speed)/10.0, 0, 1) * max_effect`。
  - `player.gd` 暴露 `speed_input: Vector2`（供相机与 UI 读）。

- [ ] **Step 1: 写失败测试 `tests/test_movement.gd`**

```gdscript
extends TestBase
func test_accelerate_no_overshoot() -> void:
	var v := Movement.accelerate(Vector3.ZERO, Vector3(10, 0, 0), 20.0, 25.0, 0.016)
	check(v.x <= 10.0001, "不超调")
	check(v.x > 0.0, "朝目标移动")
func test_accelerate_big_delta_clamped() -> void:
	var v := Movement.accelerate(Vector3.ZERO, Vector3(10, 0, 0), 20.0, 25.0, 0.5)
	check(v.length() <= 20.0 / 30.0 + 0.0001, "大 delta 单帧步长上限")
func test_jump_velocity() -> void:
	check(absf(Movement.jump_velocity(24.0, 1.5) - sqrt(72.0)) < 0.0001, "跳跃初速度")
func test_squash_stretch() -> void:
	check_eq(Movement.squash_stretch(0.0, 0.2), Vector3.ONE, "静止不变形")
	var down := Movement.squash_stretch(-10.0, 0.2)
	check(down.y < 1.0 and down.x > 1.0, "下落压扁")
	var up := Movement.squash_stretch(10.0, 0.2)
	check(up.y > 1.0 and up.x < 1.0, "上升拉长")
```

- [ ] **Step 2: 跑测试确认失败** → FAIL（`Movement` 未定义）。

- [ ] **Step 3: 实现 `movement.gd`**（三个 `static func`，按 Interfaces 里的公式）

- [ ] **Step 4: 跑测试确认通过**

- [ ] **Step 5: 实现 `player.gd`**

`extends CharacterBody3D`。`_physics_process`：读 `Input.get_vector("move_left","move_right","move_forward","move_back")` 与 `Input.is_action_pressed("run")`；水平速度走 `Movement.accelerate`；离地时乘 `Config.AIR_CONTROL`；`velocity.y` 每帧减 `GRAVITY*delta`，`is_on_floor()` 时归零；跳跃用 `Movement.jump_velocity`。`MushroomMesh` 的 `scale` 每帧设为 `Movement.squash_stretch(velocity.y, Config.SQUASH_MAX)`。落地瞬间（本帧 `is_on_floor()` 且上帧不在）把 `SQUASH_MAX` 临时放大到 0.3 再在 0.15 秒内插值回 0.2，用 `create_tween()`。

在 `project.godot` 里加 `InputMap` 动作：`move_left/right/forward/back`（WASD + 方向键）、`jump`（空格）、`run`（Shift）、`orbit`（鼠标左键）。

- [ ] **Step 6: 桌面验证手感**

`godot --path .`，WASD 走动、Shift 跑、空格跳。确认：不超调、不滑冰、落地有明显压扁。人手感不对就改 `Config` 里的四个数，不改代码。

- [ ] **Step 7: 提交**

```bash
git add game/player && git commit -m "角色移动手感与挤压拉伸动画"
```

---

### Task 5: 第三人称相机

**Files:**
- Create: `game/camera/cam_rig.gd`、`game/camera/cam_rig.tscn`、`tests/test_camera.gd`
- Modify: `game/player/mushroom.tscn`（挂 `cam_rig.tscn`）

**Interfaces:**
- Produces:
  - `CamRig.orbit(current: Vector3, drag: Vector2, sensitivity: float, pitch_min: float, pitch_max: float) -> Vector3` — 返回新的 (pitch, yaw, 0) 弧度旋转，pitch 夹在 `[-70°, -10°]`。
  - `CamRig.clamp_arm_length(requested: float, min_len: float) -> float` — 不小于 min（Review Focus 3）。
- 场景结构：`SpringArm3D`（`spring_length=4.0`、`margin=0.2`、`collision_mask` 命中地形与树）→ 子 `Camera3D`。

- [ ] **Step 1: 写失败测试 `tests/test_camera.gd`**

断言 `orbit()` 的 pitch 在极值拖拽后不越界（`-70°<=pitch<=-10°`）、yaw 累加正确；`clamp_arm_length(0.3, 1.2) == 1.2`，`clamp_arm_length(4.0, 1.2) == 4.0`。

- [ ] **Step 2: 跑测试确认失败** → FAIL。

- [ ] **Step 3: 实现 `cam_rig.gd` + 场景**，`_ready` 里 `top_level = true`，`_process` 里把全局位置跟到角色头顶 +1.6m，并应用 `orbit()` 结果。

- [ ] **Step 4: 跑测试确认通过**，然后桌面验证：鼠标左键拖动转视角，走进树丛时相机自动缩短且不穿进树干。

- [ ] **Step 5: 提交**
```bash
git add game/camera game/player/mushroom.tscn tests && git commit -m "第三人称相机与避让"
```

---

### Task 6: 触屏摇杆与跳跃按钮

**Files:**
- Create: `game/ui/touch_controls.gd`、`game/ui/touch_controls.tscn`、`tests/test_touch_controls.gd`
- Modify: `game/main.tscn`（加 `CanvasLayer` + `touch_controls.tscn`）

**Interfaces:**
- Produces:
  - `TouchControls.joystick_vector(center: Vector2, touch: Vector2, radius: float, deadzone: float) -> Vector2` — 死区内返回 `ZERO`，超出半径则长度夹到 1，方向保留。
  - `TouchControls.move_input: Vector2`（-1..1）
  - `TouchControls.jump_pressed: bool`
- 多指绑定：`_input` 里收到 `InputEventScreenTouch`，按下时若落点在摇杆圆内则记录 `stick_finger_index`，若落在跳跃按钮矩形内则记录 `jump_finger_index`；抬起时只清除匹配 index 的那一个（Review Focus 2）。

- [ ] **Step 1: 写失败测试 `tests/test_touch_controls.gd`**

```gdscript
extends TestBase
func test_deadzone() -> void:
	check_eq(TouchControls.joystick_vector(Vector2.ZERO, Vector2(3, 0), 100.0, 10.0), Vector2.ZERO, "死区内不响应")
func test_clamp_to_unit() -> void:
	var v := TouchControls.joystick_vector(Vector2.ZERO, Vector2(300, 0), 100.0, 10.0)
	check(absf(v.length() - 1.0) < 0.0001, "超出半径夹到 1")
	check(v.x > 0.99, "方向保留")
func test_partial() -> void:
	var v := TouchControls.joystick_vector(Vector2.ZERO, Vector2(50, 0), 100.0, 10.0)
	check(v.x > 0.4 and v.x < 0.7, "半程约 0.5")
```

- [ ] **Step 2: 跑测试确认失败** → FAIL。

- [ ] **Step 3: 实现 `touch_controls.tscn` + `touch_controls.gd`**

两个 `Control`（`custom_minimum_size` 120×120 的摇杆底座 + 56×56 的跳跃按钮），横屏左下/右下，位置用 `DisplayServer.get_display_safe_area()` 换算边距 24px。摇杆底座画一个半透明圆（`_draw` 或 `Panel` + `StyleBoxFlat`），内部一个小的摇杆头跟随手指。按钮用 `TextureRect` 占位（无美术时用纯色圆角）。

- [ ] **Step 4: 跑测试确认通过**

- [ ] **Step 5: 真机验证（人工，必须做）**

导出装机，单指推摇杆走、单指按跳跃、**两指同时**（摇杆 + 跳跃），确认两者互不干扰；切到系统手势区边缘确认控件不被压住。截图存档。

- [ ] **Step 6: 提交**
```bash
git add game/ui game/main.tscn tests && git commit -m "触屏虚拟摇杆与跳跃按钮，支持多指"
```

---

### Task 7: 森林世界

**Files:**
- Create: `game/world/forest.tscn`、`game/world/forest_gen.gd`、`game/world/tree_mesh.gd`
- Modify: `game/main.tscn`（`forest.tscn` 成为主场景根）
- 备份：`refs/Creation_Image_1792213174285_1.png` 复制到 `refs/`（原图留在根目录也可以，二选一，不要两处都留）

**Interfaces:**
- Produces: `ForestGen`（`class_name ForestGen extends Node3D`，导出 `radius: float = 60.0`、`tree_count: int = 240`、`seed_value: int = 1`；`generate() -> void`）；`TreeMesh.build(variant: int) -> ArrayMesh`。
- `forest.tscn` 内容：`ForestGen`、`StaticBody3D` 地形（`HeightMapShape3D` 或一块低起伏 `PlaneMesh` + `ConcavePolygonShape3D`）、`WorldEnvironment`、`DirectionalLight3D`、`player` 实例、`cam_rig` 实例。

- [ ] **Step 1: 写地形与散布**

`forest_gen.gd`：用固定 seed 的 `RandomNumberGenerator` 在半径 `radius` 内散布树（避开出生点 5m 内），用 `MultiMeshInstance3D` 批量画（`multimesh.instance_count = tree_count`，每个实例随机旋转/缩放 0.8~1.3），按 3 种变体分 3 个 MultiMesh 降低重复感。石头同理，数量 40。

- [ ] **Step 2: 天然边界（不用隐形墙）**

半径 `radius` 之外地形抬成陡坡（`PlaneMesh` 顶点按距离抬升），角色爬不上去；越界时不做任何判定，靠地形本身拦住。验证方式：一路往外走，走不出去也没撞到空气墙。

- [ ] **Step 3: 树与草的几何**

`tree_mesh.gd`：树干 = 细圆柱（棕），树冠 = 2~3 个叠放的压扁球（绿），三个变体只改球的数量、位置、颜色。草地用 200 个扁平四边形当草丛，也走 MultiMesh。全部套 Task 3 的 inverted-hull 描边材质（复用同一个材质资源）。

- [ ] **Step 4: 桌面 + 真机验证**

跑一圈（3~5 分钟能走完）、确认不穿树、不走出去、HUD 的 DRAW <150、TRI <60k。记录真机 FPS 到 `docs/perf-log.md`（新建，一行：日期、机型、FPS、DRAW、TRI）。

- [ ] **Step 5: 提交**
```bash
git add game/world game/main.tscn docs/perf-log.md && git commit -m "程序化森林世界与天然边界"
```

---

### Task 8: 昼夜光照

**Files:**
- Create: `game/world/daynight.gd`、`tests/test_daynight.gd`
- Modify: `game/world/forest.tscn`（`DayNight` 节点接管 `DirectionalLight3D` 与 `WorldEnvironment`）

**Interfaces:**
- Produces: `DayNight`（`class_name DayNight extends Node`，导出 `time_of_day: float = 0.35`（0=午夜、0.25=日出、0.5=正午、0.75=日落）、`day_length_seconds: float = Config.DAY_LENGTH_SECONDS`）与静态函数：
  - `sun_rotation(t: float) -> Vector3` — `Vector3(deg_to_rad(90.0 - 360.0 * t), deg_to_rad(-30.0), 0)`
  - `sun_energy(t: float) -> float` — `clampf(sin(PI * clampf((t - 0.25) / 0.5, 0.0, 1.0)), 0.0, 1.0)`
  - `ambient_color(t: float) -> Color` — 夜晚 `Color(0.10,0.12,0.25)`、黄昏 `Color(0.95,0.62,0.40)`、白天 `Color(0.72,0.78,0.86)` 之间按段插值

- [ ] **Step 1: 写失败测试 `tests/test_daynight.gd`**

断言：`sun_rotation(0.5).x ≈ -PI/2`；`sun_rotation(0.25).x ≈ 0`；`sun_energy(0.5) == 1.0`、`sun_energy(0.25) == 0.0`、`sun_energy(0.0) == 0.0`、`sun_energy(0.75) == 0.0`；`ambient_color(0.5) == Color(0.72,0.78,0.86)`。

- [ ] **Step 2: 跑测试确认失败** → FAIL。

- [ ] **Step 3: 实现 `daynight.gd`**，`_process` 里 `time_of_day = fmod(time_of_day + delta / day_length_seconds, 1.0)`，把 `sun_rotation` 写进灯 `rotation`、`sun_energy` 写进 `light_energy`、`ambient_color` 写进环境的 `ambient_light_color`；夜间 `light_energy` 为 0 时把环境 `ambient_light_energy` 抬到 0.35 保底可见。

- [ ] **Step 4: 跑测试确认通过**，桌面跑一遍把 `day_length_seconds` 临时改成 30 秒看完整一天的光照过渡是否平滑（不闪、不跳色），改回 600。

- [ ] **Step 5: 提交**
```bash
git add game/world tests && git commit -m "昼夜光照循环"
```

---

### Task 9: 收尾与分发包

**Files:**
- Modify: `AGENTS.md`、`CLAUDE.md`、`docs/perf-log.md`

- [ ] **Step 1: 真机全流程验收**

走完一圈森林：摇杆移动、跳跃、转视角、跨昼夜各一次。记录最终 FPS/DRAW/TRI 到 `docs/perf-log.md`。低端机不达标就按顺序砍：草地数量 → 树数量 → 阴影距离（`DirectionalLight3D.directional_shadow_max_distance` 降到 40）。

- [ ] **Step 2: 更新 `AGENTS.md` / `CLAUDE.md`**

补上真实命令（含 `--export-debug` 与 `adb install`）、实际的 Android SDK/JDK 路径、真机渲染器结论。仍然 ≤50 行。

- [ ] **Step 3: 构建分发包**

```bash
godot --headless --path . --export-release "Android" build/fungi-party.apk
```
如果 release 因签名失败，用 `--export-debug` 出包即可——朋友们装 debug 包没问题，只是不能上架（本来也不上架）。

- [ ] **Step 4: 提交**
```bash
git add -A && git commit -m "v1 收尾：真机验收、文档更新、分发包"
```
