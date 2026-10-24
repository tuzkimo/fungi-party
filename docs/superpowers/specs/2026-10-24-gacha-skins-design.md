# 皮肤抽卡与五档稀有度

## 意图

摊位现在只卖一顶 200 币的蓝莓帽，买完就没什么可追求的了。改成抽卡：15 顶皮肤分五档，靠蘑菇币抽，抽到即收藏，帐篷里随便换。目标是把「蘑菇币」从一次性消费变成长期的收集目标，同时给游戏加一个可聊的点。

## 目标

- 摊位从「买断一顶」变成「单抽 / 十连」，产出五档稀有度的皮肤。
- 五档从高到低：**夯 / 顶级 / 人上人 / NPC / 拉完了**。
- 高档皮肤靠「长出新零件」区分（剑、披风、角盔、皇冠…），不是纯换色。
- 已拥有列表进存档；帐篷能用按钮在已拥有的皮肤间切换。
- 老存档买过蓝莓帽的人升级后不能丢皮肤。

## 非目标

- 不做碎片 / 合成 / 升星。
- 不做限时卡池、轮换池、抽卡历史记录页。
- 不做抽卡动画演出（卡片直接一次性列出来）。
- 不做「用币直购某一顶」。
- 不做 3D 预览渲染到卡片上，卡片用颜色块 + 名字 + 档位。

## 反目标（技术上做成了也算失败）

- 抽卡变成肝：一个夯档要几十局小游戏才出一次，玩家中途放弃。
- 15 顶皮肤里 12 顶看起来一样，只有颜色不同，那高档就白分了。
- 存档迁移出错把老玩家的蓝莓帽弄丢。

## 约束

- 全程序化美术，不引入外部模型。
- 皮肤数据是 `.tres`（`MushroomSkin` Resource），每个一文件。
- 可调数字一律进 `game/config.gd` 的 `const`。
- 逻辑尽量抽 `static func` 以便无头测试。
- 桌面 / 真机都是横屏 1280×720 基准，浮层 620px 宽。

## 考虑过的做法

1. **纯配色 15 顶**：最省事，`MushroomSkin` 三个字段不动。但五档稀有度靠颜色区分，玩家感知不到「贵」，夯档卖不出价值。否决。
2. **皮肤里存节点树 / 场景**：每顶皮肤一个 `.tscn`，最大自由度。但 15 个场景要手工摆件，且和 `MushroomMesh` 的程序化 layout 冲突（尺寸按脚底 y=0 硬编码）。否决。
3. **固定零件词汇表 + 皮肤引用零件名（选中）**：`MushroomMesh` 内置一小组零件生成函数（剑、披风、角盔、皇冠、花、宽檐），`MushroomSkin` 用 `parts: Array[String]` 声明挂哪些，配几个几何修饰字段（斑点形状、斑点颜色、发光、帽倾斜、帽压扁）。新增一顶皮肤 = 一个 `.tres`，不动代码。选它，因为代码量固定而皮肤数可变。

## 皮肤数据模型

`game/skins/mushroom_skin.gd` 在现有三字段基础上扩展：

```gdscript
class_name MushroomSkin
extends Resource

enum SpotShape { ROUND, STAR, BLOB }

@export var id := ""                  # 存档里用的键，也是 .tres 文件名
@export var display_name := ""        # 中文名，UI 上显示
@export var rarity := 0               # 0 拉完了 … 4 夯
@export var tint_cap := Color(0.90, 0.22, 0.20)
@export var tint_body := Color(0.96, 0.78, 0.62)
@export var spot_count := 7
@export var spot_shape := SpotShape.ROUND
@export var spot_color := Color(0.99, 0.97, 0.94)
@export var spot_glow := 0.0          # 斑点自发光强度，0 = 不发光
@export var parts: Array[String] = [] # 见下方零件词汇表
@export var cap_tilt := 0.0           # 帽子绕 Z 轴倾斜，单位度
@export var cap_squash := 0.0         # 0~1，帽子高度的压扁比例
```

### 零件词汇表（`MushroomMesh` 内置，白名单）

| 名字 | 外观 |
|---|---|
| `sword` | 右手侧竖持的小剑（剑身 + 护手 + 柄） |
| `cape` | 背后一片下垂的披风 |
| `horned_helmet` | 扣在帽顶的角盔（半球 + 两只角） |
| `crown` | 帽顶金冠（一圈方齿） |
| `bloom` | 帽尖一朵小花 |
| `wide_brim` | 加大一圈的帽檐 |

`MushroomMesh` 新增 `@export var parts: Array[String]` 和 `cap_tilt` / `cap_squash` / `spot_shape` / `spot_color` / `spot_glow`，在 `build()` 末尾按 `parts` 逐个调 `_add_accessory(name)`（名字不在白名单里直接 `push_warning` 跳过，不崩）。现有节点名、位置、尺寸完全不动，只增量加节点。

### 皮肤落到 mesh 上只有一个入口

现在有 4 处各自手抄三个字段：`player.gd:39`、`seat_visual.gd:37`、`owl_actor.gd:66`、`bomb_seat.gd:34`。字段扩到 10 个后不能继续抄。

`MushroomMesh` 新增：

```gdscript
# 只搬字段不 build，调用方改完自己的覆盖再 build() 一次
func use_skin(skin: MushroomSkin) -> void   # skin 为 null 时全部复位到默认值
```

四处调用点各改两行：先 `use_skin(skin)`，再按各自原有逻辑做覆盖（`bomb_seat` 的 `tint_cap = color`）和 `build()`。这样小游戏里也长得出剑和披风，不用另外写一套。

`Player.apply_skin()` / 教室 / 猫头鹰 / 传炸弹取皮肤的方式统一改成 `SkinCatalog.by_id(Save.read()["equipped"])`（`""` → null，走默认外观），删掉 4 处 `Config.SKIN_PATH`。

## 皮肤清单（15 顶）

| 档 | id | 名字 | 外观参数 |
|---|---|---|---|
| 夯(4) | `hero` | 菇勇者 | 红帽白斑、`parts=["sword","cape","horned_helmet"]` |
| 夯(4) | `king` | 菌王 | 紫帽金斑、`parts=["crown"]`、`spot_shape=STAR` |
| 夯(4) | `glow` | 幽光菇 | 青白帽、`parts=[]`、`spot_color` 青、`spot_glow=2.0` |
| 顶级(3) | `blueberry` | 蓝莓帽 | 现有配色（帽色 0.35,0.45,0.95 / 身色 0.86,0.9,0.98 / 9 斑）、`parts=["bloom"]` |
| 顶级(3) | `fly_agaric` | 毒蝇伞 | 正红帽白斑、`parts=["wide_brim"]` |
| 顶级(3) | `stardust` | 星尘菇 | 深蓝帽、`spot_color` 金、`spot_shape=STAR` |
| 人上人(2) | `matcha` | 抹茶菇 | 绿帽米色身 |
| 人上人(2) | `sakura` | 樱粉菇 | 粉帽白身 |
| 人上人(2) | `cocoa` | 可可菇 | 棕帽奶油身 |
| NPC(1) | `plain` | 超市白菇 | 全白、`spot_count=0` |
| NPC(1) | `shiitake` | 香菇 | 褐帽、`spot_shape=BLOB`、`spot_color` 浅褐 |
| NPC(1) | `canned` | 罐头菇 | 灰黄褪色、`spot_count=2` |
| 拉完了(0) | `poop` | 屎菇 | 土黄帽、`spot_color` 棕、`spot_shape=BLOB`、`spot_count=5` |
| 拉完了(0) | `stone` | 石头菇 | 石灰灰、`spot_count=0` |
| 拉完了(0) | `wilt` | 蔫菇 | 橄榄色、`cap_tilt=22`、`cap_squash=0.45` |

每档正好 3 顶。`game/skins/<id>.tres`，共 15 个文件。现有 `blueberry.tres` 补上 `id`/`display_name`/`rarity` 后升级为「顶级」。

`game/skins/catalog.gd`：

```gdscript
class_name SkinCatalog
const PATHS := ["res://game/skins/hero.tres", ...]   # 显式 15 条，顺序即展示顺序
static func all() -> Array[MushroomSkin]
static func by_id(id: String) -> MushroomSkin          # 找不到返回 null
static func by_rarity(r: int) -> Array[MushroomSkin]
```

用显式路径数组而不是扫目录：`DirAccess` 在导出的 APK 里对 `res://` 不可靠，且显式表顺序稳定。

## 抽卡规则（`game/systems/gacha.gd`）

```gdscript
class_name Gacha
static func pick_rarity(rng: RandomNumberGenerator, pity: int) -> int
static func pull(path := Save.PATH) -> Dictionary        # 单抽
static func pull_ten(path := Save.PATH) -> Array         # 十连，各自独立 roll
```

- 价格：单抽 50 币，十连 450 币。钱不够直接返回失败，不扣币。
- 权重（下标 = 档位，和为 100）：`GACHA_WEIGHTS := [30, 30, 23, 12, 5]`，即拉完了 30% / NPC 30% / 人上人 23% / 顶级 12% / 夯 5%。
- 同档内三顶皮肤等概率。
- 保底：存档 `pity` 计数，每次未出夯就 +1；`pity >= 50` 时强制出夯；出夯后归零。十连里每一抽独立计数，所以十连中途触发保底后续抽继续正常 roll。
- 重复：抽到的 id 已在 `owned` 里 → 不进 `owned`，退币 `GACHA_REFUND[rarity]`（拉完了 10 / NPC 20 / 人上人 40 / 顶级 80 / 夯 150）。返回值的 `duplicate=true`。
- 返回值：`{"id": String, "rarity": int, "duplicate": bool, "refund": int, "coins": int}`，`coins` 是抽完后的余额。
- 自动穿戴：抽到**新**皮肤且当前 `equipped == ""`（还没穿任何东西）时顺手写 `equipped = 新 id`。已经有皮肤穿着就不动，别把玩家挑好的衣服换掉。摊位抽完调一次 `Player.apply_skin()`。
- 集齐：`owned` 长度等于 15 时摊位不再接受抽卡，按钮显示 `已集齐 15/15` 并禁用。

Config 新增：

```gdscript
const GACHA_PRICE_ONE := 50
const GACHA_PRICE_TEN := 450
const GACHA_PITY := 50
const GACHA_WEIGHTS := [30, 30, 23, 12, 5]
const GACHA_REFUND := [10, 20, 40, 80, 150]
const RARITY_NAMES := ["拉完了", "NPC", "人上人", "顶级", "夯"]
const RARITY_COLORS := [...]   # 卡片边框色，拉完了灰 → 夯 金
```

删除 `SKIN_PRICE`、`SKIN_PATH`（被 `equipped` id 取代）。

## 存档变更与迁移

`game/systems/save.gd`：

| 键 | 旧 | 新 |
|---|---|---|
| `owned` | `bool` | `PackedStringArray`，已拥有皮肤的 id |
| `equipped` | `bool` | `String`，当前穿戴的 id，`""` = 默认红帽 |
| `pity` | — | `int`，距上次出夯的抽数 |

`read()` 里的迁移（只在内存里回退，不写回旧键）：

1. 读 `owned` 数组；为空且旧 `owned` bool 为真 → `["blueberry"]`。
2. 读 `equipped` 字符串；为空且旧 `equipped` bool 为真 → `"blueberry"`。
3. 未拥有任何皮肤时 `equipped` 一律为 `""`。

`Save.equip(id: String, path)` 签名从 `bool` 改成 `String`：`""` 表示换回默认，非空必须是 `owned` 里的 id，否则返回 `false` 且不写盘。

`Player.apply_skin()`：`SkinCatalog.by_id(data["equipped"])`，`null` 就走现有默认色。

## UI

**摊位浮层 `game/ui/shop_panel.gd`**（保留文件名和类名，改内容）：

- 面板宽度从 620 改成 900（横屏 1280 放得下），居中。
- 顶部：`蘑菇币 N`。
- 两行按钮：`单抽 · 50 币`、`十连 · 450 币`。钱不够时按钮文字变 `还差 N 币` 且禁用；集齐后显示 `已集齐 15/15` 禁用。
- 抽完在下方列出结果卡片：`GridContainer` 固定 5 列，卡片 168×150。单抽就是只有一张卡的同一个网格。每张卡 = 色块（`RARITY_COLORS[rarity]` 做边框、皮肤 `tint_cap` 做底色）+ `display_name` + `RARITY_NAMES[rarity]`。重复的卡片右下角加 `重复 +N 币`。
- 玩家离开摊位区域时清空结果卡片。
- 夯档卡片描边用金色并加 `outline`，复用 `UIStyle` 已有样式，不新写。

**帐篷浮层 `game/ui/tent_panel.gd`**：

- 「换衣服」展开后换成 `GridContainer` 4 列（按钮 140×52），遍历 `owned` 按档位从高到低生成，最前面一个「默认红帽」。最多 16 个按钮 = 4 行，620 宽放得下，不需要滚动容器。
- 已穿戴的按钮 `disabled = true`。

## 测试

- `tests/test_gacha.gd`（新）：权重和为 100 且 `pick_rarity` 落在 0~4；`pity=49` 时下一抽必为夯且归零；重复抽到退币金额正确且 `owned` 长度不变；币不够不扣币不产出；十连扣 450 且产出 10 条。
- `tests/test_skin_catalog.gd`（新）：15 个 `.tres` 全部能 `load`；`id` 唯一且与文件名一致；五档各 3 顶；每个 `parts` 元素都在零件白名单里。
- `tests/test_save_fields.gd`：补老存档迁移用例（旧 `owned=true` / `equipped=true` → 新字段）。
- `tests/test_shop.gd`：删掉 `purchase` 三条用例，替换成抽卡用例或整体并入 `test_gacha.gd`。
- `tests/test_skin.gd`：`Config.SKIN_PATH` 没了，改成断言 `blueberry` 从 `SkinCatalog.by_id("blueberry")` 取得到且档位是 3。
- `tests/test_gacha.gd` 补：抽到新皮肤且 `equipped == ""` 时自动穿上；已有皮肤穿着时不被改动；集满 15 顶后抽卡返回失败。
- `tests/test_mushroom_mesh.gd` 补：`use_skin(null)` 把上一顶皮肤的 `parts` / `cap_tilt` / `spot_glow` 全部复位。
- `tests/test_mushroom_mesh.gd`：补一条「`parts` 里塞未知名字只告警不崩」。

## 留给实现者决定

- 零件具体尺寸和挂载点位（跟着现有 `cap_y` / `body_height` 的排布直觉走）。
- 卡片色块的具体圆角、间距，跟 `UIStyle.panel()` 保持一致即可。
- `GACHA_WEIGHTS` / 价格 / 保底 的具体数值需要真机试玩后再调，先按上面的数实现。
