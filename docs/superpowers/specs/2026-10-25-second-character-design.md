# 第二个角色：海鲜菇与可换体型

## 意图

现在全游戏只有一个角色：红蘑菇（`MushroomMesh` 里那一套胶囊身体 + 圆角三角帽）。按 `refs/海鲜菇角色设计图.png` 加第二个角色——一根细长得离谱的浅色杆、一顶小扁帽、四根黑棍手脚，脸点在帽面上。它是「第二个身份」，不是第二顶帽子：体型整个不一样。

同时把「体型」从红色蘑菇的几何里拆出来，以后加第三个角色只加一个文件、不改核心。

## 目标

- 海鲜菇按设计图做出 3D 外观：细长杆 + 小扁帽 + 黑棍手脚 + 腮红，无肚皮、无十字印。
- 角色可换，免费，在帐篷里跟「换衣服」并列。
- **15 顶皮肤两个体型都能戴**：配色、斑点、6 个头顶零件在两种体型上都出现在该出现的位置。
- 红蘑菇现在长什么样，改完还长什么样（节点名、位置、尺寸不变）。
- 小游戏里「显示玩家本人」的地方也跟着换体型，不出现「换了角色进教室又是红蘑菇」。

## 非目标

- 不做第三个角色、不做角色解锁/抽卡（角色免费，皮肤照旧抽卡）。
- 不做角色专属皮肤（皮肤永远两头共用）。
- 不改碰撞胶囊（0.45×1.5）、不改相机、不改四款小游戏的规则与摆位。
- 不做角色选择预览的 3D 旋转台（按钮点一下就换，玩家转头就看自己）。
- 不引入贴图/外部模型，继续全程序化。

## 反目标（技术上做成了也算失败）

- 海鲜菇戴皇冠时冠卡在杆里，或者剑飘在空气里——「能戴」等于「摆在帽子上」，不是「节点存在」。
- 为了两只角色的差异在 `build()` 里堆一长串 `if`，加第三个角色时还得回来读全部三种。
- 红蘑菇的外观被顺手「改进」了（斑点位置、剑的角度），老玩家发现自己换了张脸。

## 约束

- 外观唯一入口仍是 `MushroomMesh` 的 `use_skin()` / `build()`；外面 8 处 `MushroomMesh.new()` 一行不改。
- 可调数字进 `game/config.gd` 的 `const`；体型自己的比例常数留在各自的 body 脚本里（它们只服务一个体型，进 Config 反而更难读）。
- 非平凡逻辑先写测试，能抽纯函数的抽 `static func`。
- 提交信息用中文。

## 考虑过的做法

1. **一个类加体型枚举**（`build()` 里按 `body_style` 分两支，共用帽子/脸/斑点/零件）。省的是一次文件拆分，但所有体型的几何挤在同一个函数里，第三个角色要么再加一支 `elif`，要么那时返工。否决。
2. **基类 + 每体型一个子类（选中）**：`MushroomMesh` 继续当门面（对外 API 完全不变），内部把「身体几何」委托给一个 `MushroomBody` 子类；帽子旋转体、脸、斑点、零件挂载、材质全在基类里只有一份。加角色 = 加一个 `body_xxx.gd` + `BodyCatalog` 一行，核心不变长。
3. **海鲜菇单独一个类，皮肤接口对齐**：不碰现有文件，但脸/斑点/6 个零件的摆放要抄第二份，以后加零件改两处。否决。

选 2。理由：真要做的工作（零件挂载参数化、脸和斑点共用、红蘑菇坐标重验）方案 1 和 2 完全一样，2 只多一次文件拆分、不多一行逻辑，而加角色时差别是一行表项 vs 改核心函数。

## 结构

```
game/player/mushroom_mesh.gd        门面：持有 body、组装顺序、材质入口、squash 用的 scale
game/player/body/mushroom_body.gd   基类：帽子旋转体 / 脸 / 腮红 / 斑点 / 零件 / 材质 / 轮廓
game/player/body/body_red.gd        胶囊 + 白肚皮 + 十字印（= 现在的外观，数值照搬）
game/player/body/body_seafood.gd    细长杆 + 小扁帽 + 黑棍手脚 + 腮红
game/player/body/catalog.gd         class_name BodyCatalog：id → 体型类 + 中文名
```

`MushroomMesh` 对外保持：`use_skin(skin)`、`build()`、`cap_radius_at(y_norm)`、`cap_base()`、`body_height`、`cap_radius`、`cap_height`、`tint_cap`、`tint_body`、`parts`、`spot_*`、`cap_tilt`、`cap_squash`、`scale`。新增两个：`use_body(id)`、`top()`。

`body_height` / `cap_radius` / `cap_height` 变成「当前体型的默认值」，`use_body()` 换体型时把它们重置成新体型的默认值；`use_skin()` 之后仍可以覆盖（`bomb_seat` / `seat_visual` / `owl_actor` 都靠「先 use_skin 再改 tint_cap 再 build」这套顺序，不能破）。

## 体型接口（基类合同）

基类负责、子类不许重写的部分：

- 帽子旋转体 `_revolve_cap()`（剖面由 `cap_radius_at()` 决定，「尖度」从常量改成基类字段 `cap_sharpness`，红蘑菇 1.45、海鲜菇 ~1.75）
- 脸（两只眼 + 嘴）、腮红、斑点、`_add_accessory()`、`_add_part()`、`_solid()` / `_outline()`、CapPivot（倾斜/压扁）
- 组装顺序：身体 → CapPivot → 帽子 + 轮廓 → 脸 → 斑点 → 腮红 → 零件

子类只实现：

```gdscript
func _build_body() -> void      # 身体几何、四肢、肚皮这类体型专属的东西
func _default_sizes() -> void   # 设定 body_height / cap_radius / cap_height / cap_sharpness
func _face_span() -> float      # 脸在帽子上的宽度占比，默认 0.2（眼距 = 这个 × cap_radius）
```

## 零件挂载参数化（能不能戴的关键）

现在 6 个零件的坐标全是按红帽写的绝对值（剑护手 x=0.76、皇冠半径 0.23、披风半径 0.50/0.68…）。红帽半径 0.70，这些数刚好合适；海鲜菇帽半径 0.44，照搬就埋进杆里或飘在空中。

规则，改的时候逐条对：

- **横向**一律 `× (cap_radius / RED_CAP_RADIUS)`，`RED_CAP_RADIUS := 0.70` 是这些坐标当初的设计基准。
- **纵向**分两种：挂在帽上的（皇冠、角盔、花、剑）跟 `cap_height` 走；从帽子挂到身上的（披风）顶端按 `cap_base() + cap_height * 0.9`、底端按 `body_height * 0.243`。
- 各零件换算后红蘑菇的数值必须和现在**完全一致**（0.70/0.70=1，`cap_height` 也是 0.46 基准，所以红蘑菇那一支退化成原来的绝对值）。
- 海鲜菇的剑/披风如果贴着杆显得悬空，允许 `MushroomBody` 提供 `func _accessory_offset() -> Vector3`（默认 `ZERO`）整体平移零件组；不要把偏移散回每个零件里。

新增 `MushroomMesh.top() = cap_base() + cap_height * 2.0`，顶上的标记高度一律用它（见下）。

## 红蘑菇

`body_red.gd` 是现在 `build()` 里的身体部分原样搬过去：胶囊（radius 0.45、16×8）、白肚皮、十字印、两只手（0.30/0.13/0.42 的扁球，x=±0.56）。帽子、脸、斑点、零件留基类。节点名全部不变（`Body`、`Belly`、`BellyCross`、`HandL/HandR`、`Cap`、`EyeL/EyeR`、`Mouth0..4`…）。

## 海鲜菇

比例取自设计图（880×1679，图高约 1500px 算作 2.1 米）：

| 部位 | 值 | 依据 |
|---|---|---|
| `body_height`（脚底到帽底） | 1.60 | 总高 2.1 = 1.6 + 帽高 0.5 |
| 杆半径 | 0.22（顶部）→ 0.19（底部） | 图上杆宽约身高的 1/5 |
| 杆分段 | 24 段 × 12 环 | 性能足够，杆是主角，别用默认 64×32 |
| `cap_radius` | 0.44 | 帽宽 = 图上 0.875 |
| `cap_height` | 0.25 | 帽高 0.5，剖面高度 = 2×cap_height |
| `cap_sharpness` | 1.75 | 图上帽是扁圆顶，比红帽更扁 |
| 手臂 | 2 根黑棍，粗细 0.035，长 0.45，从帽沿下往外下垂约 35° | 设计图 |
| 腿 | 2 根黑棍，粗细 0.04，长 0.30，从杆底外撇约 20° | 设计图 |
| 配色 | 帽 `(0.855, 0.675, 0.549)`、杆 `(0.945, 0.878, 0.831)`、黑棍/眼嘴 `(0.14, 0.12, 0.11)`、腮红 `(0.957, 0.788, 0.843)` | 设计图取色 |

「精细」落在三处，都很便宜：

- 杆是**反向收窄的**（顶粗底细）+ 圆润收口，不是等粗圆柱。
- 帽下一圈比帽色深一号的菌褶盘（`cap_radius * 0.9`、高 0.03 的扁平圆盘），让帽和杆的接缝有层次。
- 杆上 2 道极淡的环纹（比杆色暗 4%，宽 `radius * 1.01` 的扁环），暗示海鲜菇的丛生纹理。

无肚皮、无十字印。轮廓（inverted hull）照旧，和其他蘑菇统一。

## 皮肤怎么落到两个体型上

皮肤只提供「颜色 + 斑点 + 零件名 + 帽修饰」，不含体型，因此两头共用同一份 `.tres`，`SkinCatalog` 和 15 个 `.tres` 一个都不改。

`MushroomMesh.use_skin(skin)` 语义不变（只搬字段、不 build）。`use_body(id)` 换体型并重置三个尺寸默认值。两者顺序无关，之后 `build()` 一次。

`BodyCatalog`：

```gdscript
class_name BodyCatalog
const BODIES := {
	"red":     {"name": "红蘑菇", "script": "res://game/player/body/body_red.gd"},
	"seafood": {"name": "海鲜菇", "script": "res://game/player/body/body_seafood.gd"},
}
static func ids() -> Array[String]                  # 顺序即 UI 顺序，第一项是默认
static func display_name(id: String) -> String
static func normalize(id: String) -> String         # 查不到就回落 "red"
```

显式表、不扫目录，理由同 `SkinCatalog.PATHS`。

## 存档与选择

`game/systems/save.gd`：新增键 `character`（String，默认 `"red"`）。`read()` 里返回它，非法值在调用方用 `BodyCatalog.normalize()` 兜住（存档不因为手改就崩）。新增 `Save.set_character(id, path)`，非法 id 返回 `false` 且不写盘。

**造型应用收敛成一个入口**：现在「显示玩家本人」的地方有四处各自读盘、各自 `SkinCatalog.by_id()`——`player.gd`、`bomb_seat.setup(true)`、`classroom.gd`、`owl_arena.gd`。加体型后每处都要多读一个键，不能再抄。

落点定为 `MushroomMesh.use_saved_look()`：读 `Save.read()`，`use_body(BodyCatalog.normalize(character))` + `use_skin(SkinCatalog.by_id(equipped))` + `build()`。四处调用点各删两行、加一行。NPC（座位上的同学、赛跑人机、摊位老板、老师）不读存档，保持现有 `tint_cap` 覆盖写法，永远是红蘑菇体型。

**帐篷 UI**（`game/ui/tent_panel.gd`）：「换衣服」按钮上面加一行「换角色」，不折叠、常驻显示，一个角色一个按钮（当前那个 `disabled`），点了就 `Save.set_character()` + `player.apply_skin()`。角色不折叠是因为它跟皮肤不是一个东西：皮肤是收藏，角色是「我是谁」，藏在二级菜单里会找不到。

## 小游戏里的一致性

玩家的座位/名次牌高度现在写死在常量里：`seat_visual.BAR_Y = 2.1`、`MARK_Y = 2.4`、`bomb_seat.MARK_Y = 2.0`。海鲜菇高 2.1，会穿过这些牌子。

改法：这些高度改成建节点时按 `mesh.top()` 反算（`BAR_Y = top * 1.16`、`MARK_Y = top * 1.32`、`bomb MARK_Y = top * 1.10`，对红蘑菇算出来还是 2.1 / 2.4 / 2.0 附近）。`owl_actor.mouth_point()` 已经在用同样的式子，改成直接调 `_body.top()`，顺手去掉一处手抄。

碰撞胶囊、课桌高度、相机一律不动：海鲜菇比碰撞体高是故意的（视觉高、手感不变），课桌前杵着一根两米一的面条本来就好笑。

## 测试

- `tests/test_mushroom_mesh.gd`：现有全部用例必须原样通过（红蘑菇外观没变）。
- `tests/test_body_seafood.gd`（新）：节点齐（`Stalk` / `Cap` / `EyeL` / `EyeR` / `Mouth0`、有 `ArmL/ArmR`、`LegL/LegR`、`BlushL/BlushR`，没有 `Belly` / `BellyCross`）；`top()` 落在 2.1±0.1；`cap_radius_at(0)` ≈ `cap_radius`。
- `tests/test_skin_on_bodies.gd`（新）：15 顶皮肤 × 2 体型全部 `build()` 不告警、节点数 > 基础数；有 `sword` 时剑身采样点全部在帽子那一圈的半径之外（把现有「剑不埋帽子」的采样逻辑抽成 `static` 复用）；有 `crown` 时冠齿的 x/z 半径在 `(0.5~1.1) × cap_radius` 内；`wide_brim` 的半径 ≤ `cap_radius * 1.25`。
- `tests/test_body_catalog.gd`（新）：默认 id 在表里；`normalize("乱写")` 回到 `"red"`；每个体型的中文名非空。
- `tests/test_save_fields.gd`：补 `character` 读写、默认值 `"red"`、`set_character` 拒非法 id。

## 留给实现者决定

- 海鲜菇手脚的确切长度与角度、菌褶盘和环纹的深浅，按真机截图微调（先按上表实现）。
- 眼距/嘴宽在海鲜菇帽子上的具体比例（基类给 `_face_span()` 一个默认值，海鲜菇看着不对就覆盖）。
- 腮红的大小和位置——设计图上它在眼睛外侧偏下，和眼睛同一层帽面上。
- 小游戏那三个高度系数的具体数值，以「牌子不穿过帽顶、也不飘太高」为准。
- 帐篷里「换角色」那一行的按钮宽度，跟现有档位行对齐即可。
