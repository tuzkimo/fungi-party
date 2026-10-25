# 第二个角色：海鲜菇与可换体型 实现计划

**Spec:** `docs/superpowers/specs/2026-10-25-second-character-design.md`

**目标:** 把体型从 `MushroomMesh` 里拆成「门面 + 基类 + 每体型一个子类」，红蘑菇外观零变化；新增海鲜菇；15 顶皮肤两头共用；帐篷里免费换角色。

**红线（每条都有测试钉住）：**

1. 红蘑菇的节点名、位置、尺寸和现在一模一样——现有 `tests/test_mushroom_mesh.gd` 原样通过。
2. 零件挂载参数化：15 顶皮肤 × 2 体型，剑不埋帽、冠不卡杆。
3. 存档里写了不存在的角色 id 要回落到红蘑菇，不能崩。
4. 小游戏里写死的进度条/标记高度改成按 `top()` 反算（否则 2.1 米的角色穿模）。

## Task 1 存档：`character` 键

- `game/systems/save.gd`：`read()` 返回 `character`（缺省 `"red"`），新增 `set_character(id, path)`，非法 id 不写盘。
- `tests/test_save_fields.gd`：读写、缺省、非法 id。

## Task 2 体型目录

- `game/player/body/catalog.gd`（`BodyCatalog`）：显式 `BODIES` 表、`ids()`、`display_name()`、`normalize()`、`create()`。
- `tests/test_body_catalog.gd`：默认 id 存在、`normalize("乱写") == "red"`、名字非空、每个脚本能 load。

## Task 3 拆出基类，红蘑菇原样搬

- `game/player/body/mushroom_body.gd`：帽子旋转体（尖度改成字段）、脸、斑点、零件、材质、轮廓、CapPivot。
- `game/player/body/body_red.gd`：胶囊 + 白肚皮 + 十字 + 两只手。
- `game/player/mushroom_mesh.gd` 变门面：`use_body()` / `use_saved_look()` / `top()`，其余 API 与字段不变。
- 验证：`bash scripts/test.sh` 全绿，`test_mushroom_mesh.gd` 一条都不许改。

## Task 4 零件挂载参数化

横向 `×(cap_radius/0.70)`；帽上的纵向跟 `cap_height`；披风顶 `cap_base()+cap_height*0.9`、底 `body_height*0.243`。红蘑菇代进去必须退化成原值。

- `tests/test_skin_on_bodies.gd`（新）：15 皮肤 × 2 体型全量 build，剑在帽外、冠齿半径在 `(0.5~1.1)×cap_radius`、宽檐 `≤1.25×cap_radius`。

## Task 5 海鲜菇

- `game/player/body/body_seafood.gd`：细长锥杆（旋转体，顶粗底细、两端圆润）+ 小扁帽 + 四根黑棍 + 腮红 + 菌褶盘 + 两道淡环纹。
- `tests/test_body_seafood.gd`：节点齐、无肚皮、`top() ≈ 2.1`。

## Task 6 四处「显示玩家本人」收敛 + 小游戏高度

- `MushroomMesh.use_saved_look()`：读存档 → `use_body` + `use_skin` + `build()`。
- `player.gd`、`bomb_seat.setup(true)`、`classroom.gd`、`owl.gd` 改调它。
- `seat_visual` 的 `BAR_Y`/`MARK_Y`、`bomb_seat.MARK_Y` 改成按 `_mesh.top()` 算；`owl_actor.mouth_point()` 改用 `top()`。

## Task 7 帐篷 UI

- `game/ui/tent_panel.gd`：「换角色」一行，常驻，当前角色禁用。

## Task 8 收尾

- `bash scripts/test.sh` 全绿；桌面跑一遍看海鲜菇正面/侧面、戴皇冠、戴剑；截图存 `shots/`。
- 更新 `AGENTS.md` 的场景说明（多一个 `game/player/body/`）。
