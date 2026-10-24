# 皮肤抽卡与五档稀有度 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把摊位的「买断一顶皮肤」换成「蘑菇币抽卡」，产出 15 顶分五档（夯 / 顶级 / 人上人 / NPC / 拉完了）的皮肤，高档靠长出新零件区分。

**Architecture:** 皮肤数据全部落在 `MushroomSkin` Resource 上（15 个 `.tres` + 一个 `SkinCatalog` 索引）。外观由 `MushroomMesh` 一个 `use_skin()` 入口统一施加，零件是 `MushroomMesh` 内置的白名单词汇表，新皮肤不改代码。抽卡规则抽成 `Gacha` 的纯静态函数便于无头测试。存档从 `owned: bool` / `equipped: bool` 迁到 `owned: PackedStringArray` / `equipped: String` / `pity: int`，老存档在 `Save.read()` 里内存回退。

**Tech Stack:** Godot 4.7.2 / GDScript / Mobile 渲染器；测试是自制的 `tests/run_tests.gd`（`bash scripts/test.sh`），不是 GUT。

**Spec:** `docs/superpowers/specs/2026-10-24-gacha-skins-design.md`

## Global Constraints

- Godot 锁定 4.7.2，渲染器 `mobile`。
- 美术全部程序化生成，不引入外部模型；球体分段不要用默认 64×32。
- 大件几何一律 MultiMesh；但本次零件只挂在玩家一个实例上（另有三处小游戏座位），不涉及 MultiMesh。
- 可调数字集中在 `game/config.gd` 的 `const`。
- 角色逻辑不引用 mesh 节点路径；外观只在 `game/player/mushroom_mesh.gd` 改。
- 非平凡逻辑先写测试，能抽纯函数的抽成 `static func`。
- 提交信息用中文。

## Review Focus

按「最可能咬人」排序。每条都归到具体任务里，由该任务的测试钉住。

1. **币刚好等于价格**（余额 50，单抽 50）——必须能抽，抽完余额 0。`<` 写成 `<=` 就会让玩家永远差一币。（Task 4）
2. **老存档只有 `owned=true` / `equipped=true` 布尔键**（v3 装机的所有人）——升级后蓝莓帽必须在，而且穿着。迁移写错就是老玩家皮肤消失。（Task 3）
3. **`owned` 里有一个已经不存在的 id**（改过皮肤 id、删过 `.tres`）——`SkinCatalog.by_id()` 返回 null，`use_skin(null)` 回落默认，不能崩、不能把玩家卡在一顶穿不上的皮肤上。（Task 2、Task 3）
4. **`pity` 在抽到重复的夯时也归零**——保底计数看的是「出没出夯」，不是「是不是新的」。归零漏了就变成 50 抽保底连续触发。（Task 4）
5. **十连中途写盘失败 / 币被别处扣光**——不能扣了钱却没发卡。`pull_ten` 每抽独立返回 `ok`，任何一抽失败就停，已成功的照常记账。（Task 4）

---

## Task 1: 皮肤数据（`MushroomSkin` 扩字段 + 15 个 `.tres` + `SkinCatalog`）

**Files:**
- Modify: `game/skins/mushroom_skin.gd`（全文件，12 字段）
- Create: `game/skins/catalog.gd`
- Create: `game/skins/hero.tres`、`king.tres`、`glow.tres`、`fly_agaric.tres`、`stardust.tres`、`matcha.tres`、`sakura.tres`、`cocoa.tres`、`plain.tres`、`shiitake.tres`、`canned.tres`、`poop.tres`、`stone.tres`、`wilt.tres`（14 个新文件）
- Modify: `game/skins/blueberry.tres`（补 id / display_name / rarity / parts）
- Test: `tests/test_skin_catalog.gd`（新建）

**Interfaces:**
- Consumes: 无
- Produces:
  - `MushroomSkin`：`enum SpotShape { ROUND, STAR, BLOB }`；字段 `id: String`、`display_name: String`、`rarity: int`、`tint_cap: Color`、`tint_body: Color`、`spot_count: int`、`spot_shape: int`、`spot_color: Color`、`spot_glow: float`、`parts: Array[String]`、`cap_tilt: float`、`cap_squash: float`
  - `SkinCatalog.PATHS: Array[String]`（15 条，顺序即展示顺序）
  - `SkinCatalog.PART_NAMES: Array[String]`（零件白名单）
  - `SkinCatalog.all() -> Array[MushroomSkin]`
  - `SkinCatalog.by_id(id: String) -> MushroomSkin`（找不到返回 `null`）
  - `SkinCatalog.by_rarity(rarity: int) -> Array[MushroomSkin]`
  - `SkinCatalog.count() -> int`（= 15）

- [ ] **Step 1: 写失败的测试**

`tests/test_skin_catalog.gd`：

```gdscript
extends TestBase


func test_all_fifteen_load() -> void:
	var all := SkinCatalog.all()
	check_eq(all.size(), 15, "15 顶皮肤全部加载")
	for skin in all:
		check(skin != null, "皮肤不是 null")
		if skin != null:
			check(skin.display_name != "", "%s 有中文名" % skin.id)


func test_ids_unique_and_match_filename() -> void:
	var seen := {}
	for skin in SkinCatalog.all():
		if skin == null:
			continue
		check(not seen.has(skin.id), "id 唯一：%s" % skin.id)
		seen[skin.id] = true
		check(
			SkinCatalog.PATHS.has("res://game/skins/%s.tres" % skin.id),
			"id 与文件名一致：%s" % skin.id,
		)


func test_three_skins_per_rarity() -> void:
	for r in 5:
		check_eq(SkinCatalog.by_rarity(r).size(), 3, "档位 %d 正好 3 顶" % r)


func test_parts_are_in_whitelist() -> void:
	for skin in SkinCatalog.all():
		if skin == null:
			continue
		for part in skin.parts:
			check(SkinCatalog.PART_NAMES.has(part), "%s 的零件 %s 在白名单里" % [skin.id, part])


func test_by_id_and_missing() -> void:
	check(SkinCatalog.by_id("hero") != null, "hero 查得到")
	check_eq(SkinCatalog.by_id("hero").rarity, 4, "菇勇者是夯")
	check(SkinCatalog.by_id("nope") == null, "查不到的 id 返回 null")


func test_blueberry_upgraded() -> void:
	var skin := SkinCatalog.by_id("blueberry")
	check(skin != null, "老蓝莓帽还在")
	if skin == null:
		return
	check_eq(skin.rarity, 3, "蓝莓帽升为顶级")
	check_eq(skin.spot_count, 9, "还是 9 个斑点")
	check(skin.tint_cap.b > skin.tint_cap.r, "帽子偏蓝")
```

- [ ] **Step 2: 跑测试确认失败**

Run: `bash scripts/test.sh`
Expected: `无法加载 tests/test_skin_catalog.gd（语法错误？）` 或失败若干项 —— 因为 `SkinCatalog` 还不存在。

- [ ] **Step 3: 扩 `MushroomSkin`**

`game/skins/mushroom_skin.gd` 全文替换为：

```gdscript
class_name MushroomSkin
extends Resource

## 一顶皮肤的完整外观：两个色 + 斑点 + 挂在头上的零件。
## 零件名必须在 SkinCatalog.PART_NAMES 里，MushroomMesh 才认得。
## 这里是所有默认值的唯一来源：use_skin(null) 就用这里的一套。

enum SpotShape { ROUND, STAR, BLOB }

@export var id := ""
@export var display_name := ""
@export var rarity := 0
@export var tint_cap := Color(0.90, 0.22, 0.20)
@export var tint_body := Color(0.96, 0.78, 0.62)
@export var spot_count := 7
@export var spot_shape := SpotShape.ROUND
@export var spot_color := Color(0.99, 0.97, 0.94)
@export var spot_glow := 0.0
@export var parts: Array[String] = []
@export var cap_tilt := 0.0
@export var cap_squash := 0.0
```

- [ ] **Step 4: 写 `SkinCatalog`**

`game/skins/catalog.gd`：

```gdscript
class_name SkinCatalog

## 皮肤总表。用显式路径而不是扫目录：DirAccess 对导出的 res:// 不可靠，且顺序要稳定。

const PATHS: Array[String] = [
	# 夯
	"res://game/skins/hero.tres",
	"res://game/skins/king.tres",
	"res://game/skins/glow.tres",
	# 顶级
	"res://game/skins/blueberry.tres",
	"res://game/skins/fly_agaric.tres",
	"res://game/skins/stardust.tres",
	# 人上人
	"res://game/skins/matcha.tres",
	"res://game/skins/sakura.tres",
	"res://game/skins/cocoa.tres",
	# NPC
	"res://game/skins/plain.tres",
	"res://game/skins/shiitake.tres",
	"res://game/skins/canned.tres",
	# 拉完了
	"res://game/skins/poop.tres",
	"res://game/skins/stone.tres",
	"res://game/skins/wilt.tres",
]

const PART_NAMES: Array[String] = [
	"sword", "cape", "horned_helmet", "crown", "bloom", "wide_brim",
]


static func all() -> Array[MushroomSkin]:
	var result: Array[MushroomSkin] = []
	for path in PATHS:
		var skin := load(path) as MushroomSkin
		if skin == null:
			push_error("皮肤加载失败：%s" % path)
			continue
		result.append(skin)
	return result


static func by_id(id: String) -> MushroomSkin:
	if id == "":
		return null
	for skin in all():
		if skin.id == id:
			return skin
	return null


static func by_rarity(rarity: int) -> Array[MushroomSkin]:
	var result: Array[MushroomSkin] = []
	for skin in all():
		if skin.rarity == rarity:
			result.append(skin)
	return result


static func count() -> int:
	return PATHS.size()
```

- [ ] **Step 5: 写 15 个 `.tres`**

每个文件照 `game/skins/blueberry.tres` 现有的格式（`[gd_resource ... load_steps=2 format=3]` + ext_resource 指到 `mushroom_skin.gd`），只改参数。数值照下表，未写的字段用资源默认值（`spot_shape = 0`、`spot_color = Color(0.99, 0.97, 0.94, 1)`、`spot_glow = 0.0`、`parts = []`、`cap_tilt = 0.0`、`cap_squash = 0.0`）。

| id | display_name | rarity | tint_cap | tint_body | spot_count | spot_shape | spot_color | spot_glow | parts | cap_tilt | cap_squash |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `hero` | 菇勇者 | 4 | 0.86,0.16,0.16 | 0.98,0.92,0.86 | 8 | 0 | — | — | `["sword","cape","horned_helmet"]` | — | — |
| `king` | 菌王 | 4 | 0.52,0.22,0.72 | 0.94,0.88,0.98 | 7 | 1 | 0.98,0.80,0.30 | — | `["crown"]` | — | — |
| `glow` | 幽光菇 | 4 | 0.62,0.94,0.90 | 0.82,0.96,0.98 | 9 | 0 | 0.55,1.0,0.95 | 2.0 | — | — | — |
| `blueberry` | 蓝莓帽 | 3 | 0.35,0.45,0.95 | 0.86,0.90,0.98 | 9 | 0 | — | — | `["bloom"]` | — | — |
| `fly_agaric` | 毒蝇伞 | 3 | 0.96,0.20,0.18 | 0.98,0.95,0.90 | 10 | 0 | — | — | `["wide_brim"]` | — | — |
| `stardust` | 星尘菇 | 3 | 0.14,0.20,0.48 | 0.72,0.78,0.94 | 8 | 1 | 0.98,0.82,0.42 | — | — | — | — |
| `matcha` | 抹茶菇 | 2 | 0.52,0.72,0.36 | 0.94,0.90,0.76 | 7 | 0 | — | — | — | — | — |
| `sakura` | 樱粉菇 | 2 | 0.96,0.62,0.74 | 0.99,0.96,0.96 | 6 | 0 | — | — | — | — | — |
| `cocoa` | 可可菇 | 2 | 0.48,0.32,0.22 | 0.94,0.86,0.72 | 8 | 0 | — | — | — | — | — |
| `plain` | 超市白菇 | 1 | 0.94,0.94,0.92 | 0.99,0.98,0.96 | 0 | 0 | — | — | — | — | — |
| `shiitake` | 香菇 | 1 | 0.42,0.29,0.20 | 0.90,0.84,0.72 | 6 | 2 | 0.62,0.48,0.34 | — | — | — | — |
| `canned` | 罐头菇 | 1 | 0.70,0.68,0.48 | 0.86,0.84,0.66 | 2 | 0 | — | — | — | — | — |
| `poop` | 屎菇 | 0 | 0.60,0.48,0.24 | 0.76,0.68,0.48 | 5 | 2 | 0.44,0.32,0.16 | — | — | — | — |
| `stone` | 石头菇 | 0 | 0.62,0.62,0.62 | 0.72,0.72,0.70 | 0 | 0 | — | — | — | — | — |
| `wilt` | 蔫菇 | 0 | 0.58,0.60,0.36 | 0.80,0.80,0.66 | 4 | 0 | — | — | — | 22.0 | 0.45 |

`tint_cap` / `tint_body` / `spot_color` 的 alpha 一律 `1`。

- [ ] **Step 6: 跑测试确认通过**

Run: `bash scripts/test.sh`
Expected: `test_skin_catalog.gd: 6 项，失败 0`，末尾 `测试 N 项，失败 0 项`。

- [ ] **Step 7: 提交**

```bash
git add game/skins tests/test_skin_catalog.gd
git commit -m "皮肤数据：扩到 12 个字段，新增 15 顶分五档的皮肤与总表"
```

---

## Task 2: `MushroomMesh` 长出新零件

**Files:**
- Modify: `game/player/mushroom_mesh.gd`
- Test: `tests/test_mushroom_mesh.gd`（追加 4 条用例）

**Interfaces:**
- Consumes: `MushroomSkin`（Task 1）、`SkinCatalog.PART_NAMES`（Task 1）
- Produces:
  - `MushroomMesh.default_skin() -> MushroomSkin`（static，返回共享的默认外观实例）
  - `MushroomMesh.use_skin(skin: MushroomSkin) -> void`（只搬字段，不 `build()`；`null` 复位到默认）
  - 新 `@export`：`spot_shape: int`、`spot_color: Color`、`spot_glow: float`、`parts: Array[String]`、`cap_tilt: float`、`cap_squash: float`

- [ ] **Step 1: 写失败的测试**

在 `tests/test_mushroom_mesh.gd` 末尾追加：

```gdscript
func test_use_skin_copies_all_fields() -> void:
	var m := MushroomMesh.new()
	m.use_skin(SkinCatalog.by_id("hero"))
	check_eq(m.spot_count, 8, "斑点数量搬过来")
	check_eq(m.parts, ["sword", "cape", "horned_helmet"], "零件清单搬过来")
	m.free()


func test_use_skin_null_resets() -> void:
	var m := MushroomMesh.new()
	m.use_skin(SkinCatalog.by_id("hero"))
	m.use_skin(null)
	check_eq(m.parts.size(), 0, "零件清空")
	check_eq(m.cap_tilt, 0.0, "帽倾斜复位")
	check_eq(m.spot_glow, 0.0, "发光复位")
	check_eq(m.tint_cap, MushroomSkin.new().tint_cap, "配色回默认")
	m.free()


func test_build_with_parts_does_not_crash() -> void:
	var m := MushroomMesh.new()
	m.use_skin(SkinCatalog.by_id("hero"))
	m.build()
	var plain := MushroomMesh.new()
	plain.build()
	check(m.get_child_count() > plain.get_child_count(), "菇勇者比默认多出零件节点")
	m.free()
	plain.free()


func test_unknown_part_only_warns() -> void:
	var m := MushroomMesh.new()
	m.parts.clear()
	m.parts.append("剑")
	m.build()
	check(m.get_child_count() >= 6, "未知零件只告警，基础部件照建")
	m.free()
```

- [ ] **Step 2: 跑测试确认失败**

Run: `bash scripts/test.sh`
Expected: 四条新用例失败，报 `Invalid call. Nonexistent function 'use_skin'`。

- [ ] **Step 3: 加字段与 `use_skin`**

`game/player/mushroom_mesh.gd` 在现有 `@export` 之后追加：

```gdscript
@export var spot_shape := 0
@export var spot_color := Color(0.99, 0.97, 0.94)
@export var spot_glow := 0.0
@export var parts: Array[String] = []
@export var cap_tilt := 0.0
@export var cap_squash := 0.0
```

并加：

```gdscript
static var _default_skin: MushroomSkin


## 默认外观的唯一来源是 MushroomSkin 的字段初值，不在这里另抄一份。
static func default_skin() -> MushroomSkin:
	if _default_skin == null:
		_default_skin = MushroomSkin.new()
	return _default_skin


## 只搬字段，不重建；调用方改完自己的覆盖再 build() 一次。
func use_skin(skin: MushroomSkin) -> void:
	var s := skin if skin != null else default_skin()
	tint_cap = s.tint_cap
	tint_body = s.tint_body
	spot_count = s.spot_count
	spot_shape = s.spot_shape
	spot_color = s.spot_color
	spot_glow = s.spot_glow
	parts = s.parts.duplicate()
	cap_tilt = s.cap_tilt
	cap_squash = s.cap_squash
```

- [ ] **Step 4: 让 `build()` 用上新字段**

改 `build()` 的三处：

1. 帽子倾斜与压扁（`_add_part("Cap", ...)` 和 `_add_part("CapOutline", ...)` 之前）：
   ```gdscript
   var cap_scale := Vector3(1.0, cap_height / cap_radius * (1.0 - cap_squash), 1.0)
   ```
   两个 cap 节点建好后设 `rotation.z = deg_to_rad(cap_tilt)`。**注意**：斑点循环里算 `spot_pos` 用的是原始 `cap_y`，倾斜后斑点会错位 —— 所以倾斜只施加在 `Cap` / `CapOutline` 两个节点上，斑点留在原位（歪帽的斑点跟着歪反而不自然）。
2. 斑点材质与形状：把 `mat_white` 换成 `_solid_glow(spot_color, spot_glow)`；`spot_mesh` 按 `spot_shape` 选：
   - `SpotShape.ROUND`（0）→ 现有 `SphereMesh`
   - `SpotShape.STAR`（1）→ `BoxMesh`，`size = Vector3(0.22, 0.05, 0.05)`，每个斑点建两个节点、第二个 `rotation_degrees.y = 90.0`，名字后缀 `A` / `B`
   - `SpotShape.BLOB`（2）→ `SphereMesh`，`spot_scale` 再乘 `Vector3(1.6, 0.5, 1.0)` 拉成扁块
3. `build()` 末尾调用零件：
   ```gdscript
   for part in parts:
   	_add_accessory(part)
   ```

- [ ] **Step 5: 写 `_add_accessory`**

```gdscript
## 零件白名单。名字不在表里只告警，不崩 —— 存档里的旧皮肤可能带已经删掉的名字。
func _add_accessory(part: String) -> void:
	match part:
		"sword":
			...
		"cape":
			...
		"horned_helmet":
			...
		"crown":
			...
		"bloom":
			...
		"wide_brim":
			...
		_:
			push_warning("未知零件：%s" % part)
```

各零件做法（尺寸按现有「脚底 y=0」的排布，`cap_y = body_height - 0.05`，`cap_radius = 0.9`）：

- `sword`：`BoxMesh` 剑身 `size = Vector3(0.05, 1.0, 0.11)`，位置 `(0.66, 1.05, 0.06)` 略微外倾 `rotation_degrees.z = -12`；`BoxMesh` 护手 `size = Vector3(0.30, 0.05, 0.07)` 位置 `(0.71, 1.48, 0.06)`；`BoxMesh` 柄 `size = Vector3(0.06, 0.20, 0.06)` 位置 `(0.72, 1.62, 0.06)`。材质 `mat_white`（银白）和 `mat_dark`（柄）。每块都配一个 outline 副本，同现有做法。
- `cape`：`CylinderMesh`（`top_radius = 0.42`、`bottom_radius = 0.62`、`height = 1.05`、`radial_segments = 16`）位置 `(0.0, 1.0, -0.36)`，用 `tint_cap` 压暗 0.8 的实心材质 + outline。
- `horned_helmet`：`SphereMesh`（`radius = 0.34`、`radial_segments = 20`、`rings = 10`）压扁 `Vector3(1.0, 0.55, 1.0)` 放在 `(0.0, cap_y + cap_height * 0.85, 0.0)`，材质 `mat_dark`；两只角用 `CylinderMesh`（`top_radius = 0.02`、`bottom_radius = 0.09`、`height = 0.34`、`radial_segments = 10`）在 `x = ±0.22`、向外倾 `rotation_degrees.z = ∓35`。
- `crown`：`CylinderMesh`（`top_radius = 0.30`、`bottom_radius = 0.26`、`height = 0.12`、`radial_segments = 16`）+ 绕一圈 5 个 `BoxMesh` 方齿 `size = Vector3(0.07, 0.13, 0.06)`，位置半径 0.27、角度 `TAU * i / 5`，全部用金色 `_solid(Color(0.98, 0.82, 0.30))`，高度 `cap_y + cap_height * 0.92`。
- `bloom`：`SphereMesh`（`radius = 1.0`、`radial_segments = 12`、`rings = 6`）缩放 `Vector3(0.16, 0.06, 0.16)` 放在帽尖 `(0.0, cap_y + cap_height * 0.98, 0.0)`，颜色 `Color(0.99, 0.72, 0.80)`；中间一颗小黄球 `Vector3(0.06, 0.05, 0.06)`。
- `wide_brim`：`SphereMesh`（`radius = 1.0`、`radial_segments = 24`、`rings = 12`）缩放 `Vector3(cap_radius * 1.18, 0.06, cap_radius * 1.18)` 放在 `(0.0, cap_y - cap_height * 0.12, 0.0)`，材质用 `tint_cap` 压暗 0.9。

`_solid_glow(color, energy)`：

```gdscript
func _solid_glow(color: Color, energy: float) -> StandardMaterial3D:
	var mat := _solid(color)
	if energy > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = energy
	return mat
```

- [ ] **Step 6: 跑测试确认通过**

Run: `bash scripts/test.sh`
Expected: `test_mushroom_mesh.gd: 7 项，失败 0`，`test_build_is_fast` 仍然 <50ms（零件只在有 parts 时生成，默认外观不受影响）。

- [ ] **Step 7: 提交**

```bash
git add game/player/mushroom_mesh.gd tests/test_mushroom_mesh.gd
git commit -m "蘑菇外观：支持斑点形状与发光、帽倾斜压扁，新增六个可挂零件"
```

---

## Task 3: 存档新模型 + 迁移 + 全部调用点 + 帐篷换装

**Files:**
- Modify: `game/systems/save.gd`
- Modify: `game/config.gd`（删 `SKIN_PRICE` / `SKIN_PATH`）
- Modify: `game/player/player.gd:39-46`
- Modify: `game/minigame/seat_visual.gd:37-42`
- Modify: `game/minigame/owl_actor.gd:66-70`
- Modify: `game/minigame/classroom.gd:57-61`
- Modify: `game/minigame/owl.gd:71-75`
- Modify: `game/minigame/bomb_seat.gd:33-46`
- Modify: `game/ui/tent_panel.gd`
- Modify: `game/ui/shop_panel.gd`（收窄成只读状态，抽卡按钮在 Task 5 接上）
- Test: `tests/test_save_fields.gd`、`tests/test_coins.gd`、`tests/test_skin.gd`

**Interfaces:**
- Consumes: `SkinCatalog.by_id()`（Task 1）、`MushroomMesh.use_skin()`（Task 2）
- Produces:
  - `Save.read()` 的字典键：`owned: PackedStringArray`、`equipped: String`、`pity: int`（其余键不变）
  - `Save.equip(id: String, path: String = PATH) -> bool`（`""` = 换回默认；必须是 `owned` 里的 id）
  - `Save.add_coins()` / `apply_round()` / `spend_stamina()` / `eat_meal()` / `rollover()` / `set_day_time()` / `write()` 签名不变

- [ ] **Step 1: 写失败的测试**

`tests/test_save_fields.gd` 里删掉 `test_equip_moved_to_save`，追加：

```gdscript
func test_legacy_bool_owned_migrates() -> void:
	_clean()
	# v3 存档的样子：只写了布尔键
	Save.write(P, {"coins": 0, "owned": true, "equipped": true})
	var d := Save.read(P)
	check_eq(d.owned, PackedStringArray(["blueberry"]), "老存档的蓝莓帽补进已拥有")
	check_eq(d.equipped, "blueberry", "老存档继续穿着蓝莓帽")
	_clean()


func test_legacy_bool_not_equipped_migrates() -> void:
	_clean()
	Save.write(P, {"owned": true, "equipped": false})
	var d := Save.read(P)
	check_eq(d.owned, PackedStringArray(["blueberry"]), "买了没穿的也有皮肤")
	check_eq(d.equipped, "", "没穿就是默认红帽")
	_clean()


func test_fresh_save_has_no_skin() -> void:
	_clean()
	var d := Save.read(P)
	check_eq(d.owned.size(), 0, "新存档一顶都没有")
	check_eq(d.equipped, "", "新存档穿默认")
	check_eq(d.pity, 0, "新存档保底计数为 0")


func test_owned_roundtrip() -> void:
	_clean()
	Save.write(P, {"owned": PackedStringArray(["hero", "poop"]), "equipped": "hero", "pity": 7})
	var d := Save.read(P)
	check_eq(d.owned, PackedStringArray(["hero", "poop"]), "已拥有列表存得住")
	check_eq(d.equipped, "hero", "穿戴 id 存得住")
	check_eq(d.pity, 7, "保底计数存得住")
	_clean()


func test_equip_requires_owned_id() -> void:
	_clean()
	Save.write(P, {"owned": PackedStringArray(["hero"])})
	check(not Save.equip("poop", P), "没拥有的穿不上")
	check_eq(Save.read(P).equipped, "", "穿不上就不写盘")
	check(Save.equip("hero", P), "拥有的能穿")
	check_eq(Save.read(P).equipped, "hero", "穿上入库")
	check(Save.equip("", P), "能换回默认")
	check_eq(Save.read(P).equipped, "", "换回默认后为空")
	check_eq(Save.read(P).coins, 0, "换衣服不动钱")
	_clean()


func test_equip_gone_id_is_ignored() -> void:
	_clean()
	# 皮肤 id 从总表里消失后，存档里还留着：不能崩，也不能穿
	Save.write(P, {"owned": PackedStringArray(["ghost"]), "equipped": "ghost"})
	var d := Save.read(P)
	check_eq(d.equipped, "ghost", "存档层不做白名单判断（读出来就是原样）")
	check(SkinCatalog.by_id(d.equipped) == null, "上层拿到 null 会回落默认外观")
	_clean()
```

`tests/test_save_fields.gd` 的 `test_partial_write_keeps_other_fields` 里那句 `Save.write(P, {"coins": 50, "owned": true, "equipped": true})` 改成 `{"coins": 50, "owned": PackedStringArray(["blueberry"]), "equipped": "blueberry"}`（否则会顺带触发迁移分支，测的东西就不是它名字说的那个了）。

`tests/test_skin.gd` 全文替换（`Config.SKIN_PATH` 没了）：

```gdscript
extends TestBase

func test_blueberry_skin_loads() -> void:
	var skin := SkinCatalog.by_id("blueberry")
	check(skin != null, "蓝莓帽从总表里取得到")
	if skin == null:
		return
	check_eq(skin.spot_count, 9, "蓝莓帽 9 个斑点")
	check(skin.tint_cap.b > skin.tint_cap.r, "帽子偏蓝")
```

`tests/test_coins.gd` 里三处旧断言改成新类型：

```gdscript
func test_missing_file_defaults() -> void:
	_clean()
	var d := Save.read(P)
	check_eq(d.coins, 0, "没有存档时币为 0")
	check_eq(d.owned.size(), 0, "没有存档时没皮肤")
	check_eq(d.equipped, "", "没有存档时穿默认")


func test_roundtrip() -> void:
	_clean()
	Save.write(P, {"coins": 120, "owned": PackedStringArray(["blueberry"]), "equipped": "blueberry"})
	var d := Save.read(P)
	check_eq(d.coins, 120, "币存得住")
	check_eq(d.owned, PackedStringArray(["blueberry"]), "皮肤状态存得住")
	check_eq(d.equipped, "blueberry", "穿戴状态存得住")
	_clean()
```

`test_add_coins_clamps_at_zero` 里的 `{"owned": false, "equipped": false}` 改成 `{}`（那两个键跟它无关，去掉即可）。

- [ ] **Step 2: 跑测试确认失败**

Run: `bash scripts/test.sh`
Expected: `test_save_fields` 与 `test_coins` 多条失败，`owned` 实得 `false` 而不是数组。

- [ ] **Step 3: 改 `Save`**

`game/systems/save.gd`：

```gdscript
static func read(path: String = PATH) -> Dictionary:
	var cfg := ConfigFile.new()
	cfg.load(path)
	# v3 存档里 owned/equipped 是布尔键，类型得先看再取：直接赋给 PackedStringArray 会报错，
	# str(true) 又得到 "true" 而不是 "blueberry"
	var owned := PackedStringArray()
	var raw_owned = cfg.get_value(SECTION, "owned", PackedStringArray())
	if typeof(raw_owned) == TYPE_PACKED_STRING_ARRAY:
		owned = raw_owned
	elif typeof(raw_owned) == TYPE_BOOL and bool(raw_owned):
		owned = PackedStringArray(["blueberry"])
	var equipped := ""
	var raw_equipped = cfg.get_value(SECTION, "equipped", "")
	if typeof(raw_equipped) == TYPE_STRING:
		equipped = raw_equipped
	elif typeof(raw_equipped) == TYPE_BOOL and bool(raw_equipped):
		equipped = "blueberry"
	return {
		"coins": int(cfg.get_value(SECTION, "coins", 0)),
		"owned": owned,
		"equipped": equipped,
		"pity": int(cfg.get_value(SECTION, "pity", 0)),
		"stamina": int(cfg.get_value(SECTION, "stamina", Config.STAMINA_MAX)),
		"meals": int(cfg.get_value(SECTION, "meals", 0)),
		"day": int(cfg.get_value(SECTION, "day", 1)),
		"day_time": float(cfg.get_value(SECTION, "day_time", Config.MORNING_TIME)),
	}
```

注意旧存档的 `owned` / `equipped` 都是布尔。`owned` 直接赋给 `PackedStringArray` 变量会运行时报错；`equipped` 用 `str(true)` 会得到字符串 `"true"`，迁移就白做了（这正好是 Review Focus #2 要钉的那条）。必须按 `typeof` 分支。

`equip()` 换成：

```gdscript
## 穿戴状态：`""` 是默认红帽，非空必须是已拥有的 id。摊位和帐篷都走这里，不各写一遍。
static func equip(skin_id: String, path: String = PATH) -> bool:
	var data := read(path)
	if skin_id != "" and not (data["owned"] as PackedStringArray).has(skin_id):
		return false
	write(path, {"equipped": skin_id})
	return true
```

- [ ] **Step 4: 删 `Config` 里作废的两个常量**

`game/config.gd` 删掉 `const SKIN_PRICE := 200` 和 `const SKIN_PATH := "res://game/skins/blueberry.tres"`。

- [ ] **Step 5: 六个调用点改用 `use_skin`**

`game/player/player.gd` 的 `apply_skin()`：

```gdscript
func apply_skin() -> void:
	var data := Save.read()
	_visual.use_skin(SkinCatalog.by_id(str(data["equipped"])))
	_visual.build()
```

`_base_cap` / `_base_body` / `_base_spots` 三个成员和它们在 `_ready()` 里的赋值一起删掉（默认外观现在由 `MushroomMesh.default_skin()` 负责）。

`game/minigame/seat_visual.gd` 的 `apply_skin()`：

```gdscript
func apply_skin(skin: MushroomSkin) -> void:
	_body.use_skin(skin)
	_body.build()
```

`game/minigame/owl_actor.gd` 的 `apply_skin()`：

```gdscript
func apply_skin(skin: MushroomSkin) -> void:
	_cap_color = skin.tint_cap
	_body.use_skin(skin)
	_body.build()
```

`game/minigame/classroom.gd:57-61` 换成：

```gdscript
	# 玩家穿着的那顶，教室里的自己也长一样（换场景后 Player 不在，座位 0 才是「我」）
	var skin := SkinCatalog.by_id(str(Save.read()["equipped"]))
	if skin != null:
		_seats[0].apply_skin(skin)
```

`game/minigame/owl.gd:71-75` 换成同样的形状（目标是 `_actors[OwlRound.PLAYER].apply_skin(skin)`）。

`game/minigame/bomb_seat.gd:33-46` 换成：

```gdscript
func setup(color: Color, use_saved_skin: bool) -> void:
	var skin: MushroomSkin = null
	if use_saved_skin:
		skin = SkinCatalog.by_id(str(Save.read()["equipped"]))

	_mesh = MushroomMesh.new()
	_mesh.name = "Body"
	_mesh.use_skin(skin)
	if skin == null:
		_mesh.tint_cap = color
	add_child(_mesh)
```

（`use_skin` 不 build，所以这里的 `_mesh` 保持「还没 build」的状态，和原来一致 —— 原来也是先建节点再等 `_ready`/别处 build。）

- [ ] **Step 6: 帐篷换装改成按已拥有生成按钮**

`game/ui/tent_panel.gd`：删掉 `_wear_default` / `_wear_skin` 两个成员和 `_skin_button` / `_on_wear` 两个函数，`_skins` 改成网格，`_refresh()` 里重建：

```gdscript
	_skins = GridContainer.new()
	_skins.columns = 4
	_skins.add_theme_constant_override("h_separation", 12)
	_skins.add_theme_constant_override("v_separation", 12)
	_skins.visible = false
	box.add_child(_skins)
```

```gdscript
func _refresh() -> void:
	var data := Save.read()
	_stamina.text = "体力 %d/%d" % [int(data["stamina"]), Config.STAMINA_MAX]
	# _process 每帧都调这里，按钮只在已拥有/穿戴变了时才重建
	var key := "%s|%s" % [str(data["owned"]), str(data["equipped"])]
	if _skins.visible and key != _built_key:
		_built_key = key
		_build_skin_buttons(data)


## 已拥有的按档位从高到低排，最前面一个「默认红帽」。
func _build_skin_buttons(data: Dictionary) -> void:
	for child in _skins.get_children():
		child.queue_free()

	var owned := data["owned"] as PackedStringArray
	var equipped := str(data["equipped"])
	_add_skin_button("默认红帽", "", equipped == "")
	var skins: Array[MushroomSkin] = []
	for skin_id in owned:
		var skin := SkinCatalog.by_id(skin_id)
		if skin != null:
			skins.append(skin)
	skins.sort_custom(func(a, b): return a.rarity > b.rarity)
	for skin in skins:
		_add_skin_button(skin.display_name, skin.id, equipped == skin.id)


func _add_skin_button(text: String, skin_id: String, worn: bool) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(140.0, 52.0)
	button.disabled = worn
	button.pressed.connect(_on_wear.bind(skin_id))
	UIStyle.style_button(button)
	_skins.add_child(button)


func _on_wear(skin_id: String) -> void:
	if not Save.equip(skin_id):
		return
	var player := get_tree().get_first_node_in_group("player") as Player
	if player != null:
		player.apply_skin()
	_refresh()
```

`_on_clothes()` 展开后要重建一次：`_skins.visible = not _skins.visible; _built_key = ""; _refresh()`。新增成员 `var _built_key := ""`。`_on_wear()` 末尾也是 `_built_key = ""; _refresh()`。

- [ ] **Step 7: 摊位的临时收窄（Task 5 接上抽卡）**

`game/ui/shop_panel.gd` 的 `_refresh()` / `purchase()` / `_on_buy()` / `_apply_skin_to_player()` 全部删掉，`_ready()` 里去掉 `_price` 和 `_buy` 两个控件的构建，`_refresh()` 换成：

```gdscript
func _refresh() -> void:
	var data := Save.read()
	_coins.text = "蘑菇币 %d" % int(data["coins"])
	_status.text = "已拥有 %d/%d · 到帐篷里换" % [
		(data["owned"] as PackedStringArray).size(), SkinCatalog.count()
	]
```

`_ready()` 里把 `_price` 换成 `_status`（一个 `Label`）。这是过渡态，Task 5 会整个重写这个文件。

- [ ] **Step 8: 跑测试确认通过**

Run: `bash scripts/test.sh`
Expected: 全绿。若 `无法加载 game/ui/shop_panel.gd` 则说明还残留 `Config.SKIN_PRICE` 引用。

- [ ] **Step 9: 桌面跑一遍确认没崩**

Run: `godot --path . --quit-after 120 2>&1 | grep -i "error\|警告" || echo "无报错"`
Expected: `无报错`。老存档在 `~/.local/share/godot/app_userdata/...` 或 `%APPDATA%/Godot/app_userdata/...`，手动把 `save.cfg` 的 `owned`/`equipped` 改成布尔键再跑一遍，确认蓝莓帽还在身上。

- [ ] **Step 10: 提交**

```bash
git add game/systems/save.gd game/config.gd game/player/player.gd \
  game/minigame game/ui/tent_panel.gd game/ui/shop_panel.gd \
  tests/test_save_fields.gd tests/test_coins.gd
git commit -m "存档：已拥有改成皮肤 id 列表、穿戴改成 id，老布尔存档自动迁移；帐篷按已拥有列出换装"
```

---

## Task 4: `Gacha` 抽卡系统

**Files:**
- Create: `game/systems/gacha.gd`
- Modify: `game/config.gd`（新增抽卡常量）
- Create: `tests/test_gacha.gd`
- Delete: `tests/test_shop.gd`（内容并入 `test_gacha.gd`）

**Interfaces:**
- Consumes: `Save.read()` / `Save.write()`（Task 3）、`SkinCatalog.by_rarity()`（Task 1）
- Produces:
  - `Gacha.pick_rarity(rng: RandomNumberGenerator, pity: int) -> int`
  - `Gacha.pick_skin(rng: RandomNumberGenerator, rarity: int) -> MushroomSkin`
  - `Gacha.can_pull_one(data: Dictionary) -> bool`
  - `Gacha.can_pull_ten(data: Dictionary) -> bool`
  - `Gacha.pull(path: String = Save.PATH, rng: RandomNumberGenerator = null) -> Dictionary`
  - `Gacha.pull_ten(path: String = Save.PATH, rng: RandomNumberGenerator = null) -> Array[Dictionary]`
  - 返回字典：`{"ok": bool, "id": String, "rarity": int, "duplicate": bool, "refund": int, "coins": int}`

- [ ] **Step 1: 写失败的测试**

`tests/test_gacha.gd`：

```gdscript
extends TestBase

const P := "user://test_gacha.cfg"

func _clean() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(P))

func _seeded(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng

func test_weights_sum_to_hundred() -> void:
	var sum := 0
	for w in Config.GACHA_WEIGHTS:
		sum += w
	check_eq(sum, 100, "权重和为 100")
	check_eq(Config.GACHA_WEIGHTS.size(), 5, "五个档位都有权重")

func test_pick_rarity_stays_in_range() -> void:
	var rng := _seeded(42)
	for i in 500:
		var r := Gacha.pick_rarity(rng, 0)
		check(r >= 0 and r <= 4, "档位落在 0~4（实得 %d）" % r)
		if r < 0 or r > 4:
			return

func test_pity_forces_top_on_last_pull() -> void:
	var rng := _seeded(7)
	check_eq(Gacha.pick_rarity(rng, Config.GACHA_PITY - 1), 4, "第 50 抽必出夯")
	check_eq(Gacha.pick_rarity(rng, Config.GACHA_PITY), 4, "超了也还是夯")

func test_pity_one_short_is_not_forced() -> void:
	var rng := _seeded(1234)
	var forced := true
	for i in 200:
		if Gacha.pick_rarity(rng, Config.GACHA_PITY - 2) != 4:
			forced = false
			break
	check(not forced, "差两抽时不该每抽都是夯")

func test_pull_takes_exactly_price() -> void:
	_clean()
	Save.write(P, {"coins": Config.GACHA_PRICE_ONE})
	var r := Gacha.pull(P, _seeded(1))
	check(r.ok, "钱刚好够就能抽")
	check_eq(r.coins, 0, "抽完刚好归零")
	check_eq(Save.read(P).coins, 0, "落盘也是 0")
	_clean()

func test_pull_refuses_when_short() -> void:
	_clean()
	Save.write(P, {"coins": Config.GACHA_PRICE_ONE - 1})
	var r := Gacha.pull(P, _seeded(1))
	check(not r.ok, "差 1 币抽不了")
	check_eq(Save.read(P).coins, Config.GACHA_PRICE_ONE - 1, "抽不了不扣钱")
	check_eq(Save.read(P).owned.size(), 0, "抽不了不产出")
	_clean()

func test_new_skin_goes_into_owned() -> void:
	_clean()
	Save.write(P, {"coins": Config.GACHA_PRICE_ONE})
	var r := Gacha.pull(P, _seeded(3))
	check(r.ok and not r.duplicate, "抽到新皮肤")
	check_eq(r.refund, 0, "新的不退币")
	check_eq(Save.read(P).owned, PackedStringArray([r.id]), "进已拥有")
	_clean()

func test_duplicate_refunds_and_keeps_owned_size() -> void:
	_clean()
	var rng := _seeded(11)
	Save.write(P, {"coins": Config.GACHA_PRICE_ONE * 200})
	var first := Gacha.pull(P, rng)
	var dup := Gacha.pull(P, rng)
	var guard := 0
	while not dup.duplicate and guard < 199:
		dup = Gacha.pull(P, rng)
		guard += 1
	check(dup.duplicate, "抽够多次总会重复")
	if dup.duplicate:
		check_eq(dup.refund, Config.GACHA_REFUND[dup.rarity], "退币金额按档位")
	_clean()

func test_duplicate_does_not_duplicate_owned_entry() -> void:
	_clean()
	Save.write(P, {"coins": Config.GACHA_PRICE_ONE * 200, "owned": PackedStringArray(["poop"])})
	var before := Save.read(P).owned.size()
	var rng := _seeded(5)
	var dup_found := false
	for i in 200:
		var r := Gacha.pull(P, rng)
		if r.duplicate:
			dup_found = true
			break
	check(dup_found, "200 抽里出现了重复")
	var after := Save.read(P).owned.size()
	check(
		after < before + 200,
		"重复的没把已拥有列表撑大（%d → %d）" % [before, after],
	)
	_clean()

func test_pity_resets_on_duplicate_top() -> void:
	_clean()
	# 已经拥有 hero，抽到重复的夯也要把保底归零
	Save.write(P, {
		"coins": Config.GACHA_PRICE_ONE * 60,
		"owned": PackedStringArray(["hero"]),
		"pity": Config.GACHA_PITY - 1,
	})
	var r := Gacha.pull(P, _seeded(9))
	check_eq(r.rarity, 4, "保底触发")
	check(r.duplicate, "抽到的是已拥有的夯")
	check_eq(Save.read(P).pity, 0, "重复的夯也归零")
	_clean()

func test_auto_equip_only_when_nothing_worn() -> void:
	_clean()
	Save.write(P, {"coins": Config.GACHA_PRICE_ONE})
	var r := Gacha.pull(P, _seeded(21))
	check_eq(Save.read(P).equipped, r.id, "还没穿东西时自动穿上")
	_clean()

func test_auto_equip_keeps_existing() -> void:
	_clean()
	Save.write(P, {
		"coins": Config.GACHA_PRICE_ONE * 3,
		"owned": PackedStringArray(["poop"]),
		"equipped": "poop",
	})
	Gacha.pull(P, _seeded(31))
	check_eq(Save.read(P).equipped, "poop", "已有穿戴时不被抢")
	_clean()

func test_ten_costs_ten_price_and_returns_ten() -> void:
	_clean()
	Save.write(P, {"coins": Config.GACHA_PRICE_TEN})
	var results := Gacha.pull_ten(P, _seeded(13))
	check_eq(results.size(), 10, "十连出十张")
	check_eq(Save.read(P).coins, 0, "十连正好扣 450")
	for r in results:
		check(r.ok, "每一抽都成功")
	_clean()

func test_ten_refused_when_short() -> void:
	_clean()
	Save.write(P, {"coins": Config.GACHA_PRICE_TEN - 1})
	var results := Gacha.pull_ten(P, _seeded(13))
	check_eq(results.size(), 0, "钱不够十连不出卡")
	check_eq(Save.read(P).coins, Config.GACHA_PRICE_TEN - 1, "钱不够不扣")
	_clean()

func test_full_collection_blocks_pulling() -> void:
	_clean()
	var all_ids := PackedStringArray()
	for skin in SkinCatalog.all():
		all_ids.append(skin.id)
	Save.write(P, {"coins": 9999, "owned": all_ids})
	check(not Gacha.can_pull_one(Save.read(P)), "集齐后不能单抽")
	check(not Gacha.can_pull_ten(Save.read(P)), "集齐后不能十连")
	check(not Gacha.pull(P, _seeded(1)).ok, "集齐后 pull 拒绝")
	_clean()
```

写完删掉 `tests/test_shop.gd`（三条 `purchase` 用例已被 `test_gacha.gd` 的对应场景覆盖）。

- [ ] **Step 2: 跑测试确认失败**

Run: `bash scripts/test.sh`
Expected: `无法加载 tests/test_gacha.gd`，因为 `Gacha` 和 `Config.GACHA_*` 还不存在。

- [ ] **Step 3: 加 `Config` 常量**

`game/config.gd` 在蘑菇币那一段追加：

```gdscript
# v4 皮肤抽卡（下标 = 档位：0 拉完了 / 1 NPC / 2 人上人 / 3 顶级 / 4 夯）
const GACHA_PRICE_ONE := 50
const GACHA_PRICE_TEN := 450
const GACHA_PITY := 50
const GACHA_WEIGHTS: Array[int] = [30, 30, 23, 12, 5]
const GACHA_REFUND: Array[int] = [10, 20, 40, 80, 150]
const RARITY_NAMES: Array[String] = ["拉完了", "NPC", "人上人", "顶级", "夯"]
const RARITY_COLORS: Array[Color] = [
	Color(0.55, 0.55, 0.58),
	Color(0.62, 0.72, 0.60),
	Color(0.42, 0.66, 0.88),
	Color(0.78, 0.45, 0.88),
	Color(0.98, 0.78, 0.26),
]
```

- [ ] **Step 4: 写 `Gacha`**

`game/systems/gacha.gd`：

```gdscript
class_name Gacha

## 抽卡规则，全是纯函数 + 一次落盘，方便无头测试。
## 币、已拥有、保底计数一起写，中途失败不会扣了钱没发卡。

static var _rng: RandomNumberGenerator


static func rng() -> RandomNumberGenerator:
	if _rng == null:
		_rng = RandomNumberGenerator.new()
		_rng.randomize()
	return _rng


## 保底：距上次出夯满 GACHA_PITY 抽就强制出夯。返回 0~4。
static func pick_rarity(generator: RandomNumberGenerator, pity: int) -> int:
	if pity >= Config.GACHA_PITY:
		return 4
	var roll := generator.randi_range(1, 100)
	var acc := 0
	for rarity in Config.GACHA_WEIGHTS.size():
		acc += Config.GACHA_WEIGHTS[rarity]
		if roll <= acc:
			return rarity
	return 0


## 同档内等概率。
static func pick_skin(generator: RandomNumberGenerator, rarity: int) -> MushroomSkin:
	var pool := SkinCatalog.by_rarity(rarity)
	if pool.is_empty():
		pool = SkinCatalog.all()
	return pool[generator.randi_range(0, pool.size() - 1)]


static func can_pull_one(data: Dictionary) -> bool:
	return (data["owned"] as PackedStringArray).size() < SkinCatalog.count() \
		and int(data["coins"]) >= Config.GACHA_PRICE_ONE


static func can_pull_ten(data: Dictionary) -> bool:
	return (data["owned"] as PackedStringArray).size() < SkinCatalog.count() \
		and int(data["coins"]) >= Config.GACHA_PRICE_TEN


static func pull(path: String = Save.PATH, generator: RandomNumberGenerator = null) -> Dictionary:
	return _pull(path, Config.GACHA_PRICE_ONE, generator)


static func pull_ten(path: String = Save.PATH, generator: RandomNumberGenerator = null) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var data := Save.read(path)
	if not can_pull_ten(data):
		return results
	for i in 10:
		var r := _pull(path, Config.GACHA_PRICE_ONE, generator)
		if not r["ok"]:
			break
		results.append(r)
	return results


static func _pull(path: String, price: int, generator: RandomNumberGenerator) -> Dictionary:
	var data := Save.read(path)
	if int(data["coins"]) < price:
		return {"ok": false, "coins": int(data["coins"])}
	var g := generator if generator != null else rng()
	var owned := data["owned"] as PackedStringArray
	var pity := int(data["pity"])
	var rarity := pick_rarity(g, pity)
	var skin := pick_skin(g, rarity)
	var duplicate := owned.has(skin.id)
	var refund := Config.GACHA_REFUND[rarity] if duplicate else 0
	# 出了夯（含重复的夯）就归零，没出就 +1
	pity = 0 if rarity == 4 else pity + 1
	var coins := int(data["coins"]) - price + refund
	var equipped := str(data["equipped"])
	if not duplicate:
		owned.append(skin.id)
		if equipped == "":
			equipped = skin.id
	Save.write(path, {"coins": coins, "owned": owned, "equipped": equipped, "pity": pity})
	return {
		"ok": true,
		"id": skin.id,
		"rarity": rarity,
		"duplicate": duplicate,
		"refund": refund,
		"coins": coins,
	}
```

**注意** `pull_ten` 每抽用同一份 `generator` 连续取随机数（而不是每抽新建），否则十连里十张卡的随机序列会重复。

- [ ] **Step 5: 跑测试确认通过**

Run: `bash scripts/test.sh`
Expected: `test_gacha.gd: 16 项，失败 0`。若 `test_pull_takes_exactly_price` 失败，检查 `_pull` 里的比较是不是 `>=`。

- [ ] **Step 6: 提交**

```bash
git add game/systems/gacha.gd game/config.gd tests/test_gacha.gd
git rm tests/test_shop.gd
git commit -m "抽卡：五档权重、50 抽硬保底、重复退币、首次抽到自动穿戴，逻辑独立成 Gacha"
```

---

## Task 5: 摊位抽卡界面

**Files:**
- Modify: `game/ui/shop_panel.gd`（重写）

**Interfaces:**
- Consumes: `Gacha.pull()` / `pull_ten()` / `can_pull_one()` / `can_pull_ten()`（Task 4）、`Config.GACHA_PRICE_*` / `RARITY_NAMES` / `RARITY_COLORS`（Task 4）
- Produces: 无（叶子节点）

- [ ] **Step 1: 重写面板**

`game/ui/shop_panel.gd` 全文替换。结构照现有 `_process()` 惰性找 stall 的模式，只换内容：

- 面板 `custom_minimum_size = Vector2(900.0, 0.0)`。
- `_coins: Label`（蘑菇币余额）。
- `_status: Label`（`已集齐 15/15` 或空）。
- `_one: Button`、`_ten: Button`，接到 `_on_pull_one` / `_on_pull_ten`。
- `_results: GridContainer`，`columns = 5`，`h_separation = 12`，`v_separation = 12`。
- `_refresh()`：读 `Save.read()`，`_one.text` / `_ten.text` / `disabled` 按余额和集齐状态给（文案 `单抽 · 50 币` / `还差 N 币` / `已集齐 15/15`），**不清空结果卡片**。
- `_on_pull_one()`：`var r := Gacha.pull()`；成功就 `_show_results([r])` 并 `_refresh()`。
- `_on_pull_ten()`：`var rs := Gacha.pull_ten()`；非空就 `_show_results(rs)` 并 `_refresh()`。
- `_show_results(results: Array)`：清空 `_results` 旧子节点，每张结果建一个卡片。
- 抽完调 `_apply_skin_to_player()`（保留现有那个函数）。
- `_process()` 里「刚进入摊位」那一下除 `_refresh()` 外要 `_clear_results()`；离开摊位时也 `_clear_results()`（结果不跨次保留）。

卡片（`_make_card(r: Dictionary) -> Control`）：

```gdscript
## 一张结果卡：档位色边框 + 皮肤帽色底 + 名字 + 档位名。重复的右下角补退币。
func _make_card(result: Dictionary) -> Control:
	var skin := SkinCatalog.by_id(str(result["id"]))
	var rarity := int(result["rarity"])
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(168.0, 150.0)
	var style := StyleBoxFlat.new()
	style.bg_color = skin.tint_cap.darkened(0.55) if skin != null else Color(0.2, 0.2, 0.2)
	style.border_color = Config.RARITY_COLORS[rarity]
	style.set_border_width_all(4 if rarity == 4 else 2)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(10.0)
	panel.add_theme_stylebox_override("panel", style)
	...
	return panel
```

卡片里竖排：`display_name`（字号 24）、`Config.RARITY_NAMES[rarity]`（字号 20，颜色用 `Config.RARITY_COLORS[rarity]`）、重复时 `重复 +%d 币`（字号 18）。

- [ ] **Step 2: 桌面跑起来看布局**

Run: `godot --path . 2>&1 | tee /tmp/run.log`
Expected: 没有 `SCRIPT ERROR`。走到摊位跟前，面板出现，按钮和文案正常。

在 `_refresh()` 开头临时加一行
`print("shop panel rect=", _root.get_child(1).get_child(0).get_rect())`
确认面板实际宽度 ≥ 900 且没超出屏幕（1280 宽的窗口里应该居中、左右各留 190）。看完删掉这行。

- [ ] **Step 3: 无头确认没语法错误**

Run: `bash scripts/test.sh`
Expected: 全绿（`shop_panel.gd` 会被编辑器扫到，语法错会让 `--editor --quit` 报错）。

- [ ] **Step 4: 提交**

```bash
git add game/ui/shop_panel.gd
git commit -m "摊位：改成单抽 / 十连，抽完列出档位色卡片，重复的标退币"
```

---

## Task 6: 真机验证与文档

**Files:**
- Modify: `AGENTS.md`（项目概述补 v4 一行）
- Modify: `docs/perf-log.md`（记录带零件的帧率）
- Modify: `game/config.gd`（版本号）

**Interfaces:**
- Consumes: 全部
- Produces: 无

- [ ] **Step 1: 桌面完整走一遍**

Run: `godot --path .`
Expected: 手动做一遍 —— 摊位连抽十次看卡片排布、去帐篷换一顶夯皮肤看剑和披风长出来、进教室 / 猫头鹰 / 传炸弹确认自己在小游戏里也是这身、退出重进确认皮肤和已拥有还在。有问题回对应 Task 修。

- [ ] **Step 2: 老存档迁移实测**

把 `%APPDATA%/Godot/app_userdata/<项目名>/save.cfg` 备份后改成 v3 样子：

```ini
[game]
coins=0
owned=true
equipped=true
```

Run: `godot --path .`
Expected: 进游戏身上是蓝莓帽，摊位显示 `已拥有 1/15`，帐篷里只有「默认红帽」和「蓝莓帽」。

- [ ] **Step 3: 出调试包装机**

```bash
godot --headless --path . --export-debug "Android" build/app.apk
adb install -r build/app.apk
adb shell monkey -p com.tuzki.fungiparty -c android.intent.category.LAUNCHER 1
```

- [ ] **Step 4: 看日志和帧率**

Run: `adb logcat -s godot`
Expected: 没有 `SCRIPT ERROR`。debug HUD 上的 FPS 在森林里 60 以上，穿菇勇者（剑 + 披风 + 角盔）时不低于 55。

把数字记进 `docs/perf-log.md`，一行：`2026-10-24 穿菇勇者（3 个零件）森林 60 FPS` 之类，实测到多少写多少。

- [ ] **Step 5: 更新 `AGENTS.md` 和版本号**

`AGENTS.md` 的项目概述里把 v3 那句补成 v4：摊位从买皮肤改成「抽卡：15 顶分夯/顶级/人上人/NPC/拉完了五档，蘑菇币单抽十连，50 抽保底，重复退币」，并把「皮肤数据（`.tres`）」那行改成「15 顶皮肤数据（`.tres`）+ 零件白名单」。

`game/config.gd` 或版本号所在处升到 `0.7.0`（按现有写法）。

- [ ] **Step 6: 提交**

```bash
git add AGENTS.md docs/perf-log.md game/config.gd
git commit -m "v4 抽卡：真机验证通过，补文档与版本号"
```

---

## 自检记录

- **Spec 覆盖**：数据模型 → Task 1；零件与 `use_skin` → Task 2；存档迁移与六处调用点、帐篷换装 → Task 3；抽卡规则（价格 / 权重 / 保底 / 重复退币 / 自动穿戴 / 集齐）→ Task 4；摊位 UI → Task 5；真机与文档 → Task 6。规格里的「留给实现者决定」三项（零件尺寸、卡片圆角、数值调参）分别在 Task 2 Step 5、Task 5 Step 1、Task 6 里落地。
- **Review Focus 五条**：①归 Task 4 `test_pull_takes_exactly_price`；②归 Task 3 `test_legacy_bool_owned_migrates`；③归 Task 2 `test_use_skin_null_resets` + Task 3 `test_equip_gone_id_is_ignored`；④归 Task 4 `test_pity_resets_on_duplicate_top`；⑤归 Task 4 `test_pull_refuses_when_short` + `test_ten_refused_when_short`。
