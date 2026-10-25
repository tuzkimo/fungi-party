# 同屏双人 实现计划

设计见 `docs/superpowers/specs/2026-10-26-party-coop-design.md`。

## 1 会话与外观

1. `game/systems/party.gd`：`joined / count / join / leave / human(seat) / name_of(seat) / look(seat)`。
2. `MushroomMesh.use_look(body_id, skin_id)`；`use_saved_look()` 变成它的特例；新增 `use_party_look(seat)`。
3. 四个小游戏里「座位 0 穿上玩家的样子」改成按座位调用。

## 2 输入

4. `TouchControls` 改成每人一组摇杆 + 动作键；`move(i)` / `held(i)`；森林那张场景 `duo = false`。
5. `EatInput` 按落点分左右半屏；`pressing(player)`。
6. `CamRig` 不再只避开摇杆手指，改成避开任何控制手指。

## 3 森林

7. `Player` 加 `seat` / `leader`：有 leader 就追到它身后，不读输入、不建相机。
8. `main.gd` 负责生灭二号位；`JoinPanel` 选角色 + 皮肤 + 离队。

## 4 四款小游戏

9. 教室：座位位置重排（人坐中间两张）、`StealEat.humans`、UI 双人一行、结算相加。
10. 猫头鹰：`OwlRound.humans`、座位 X 重排、结算相加。
11. 传炸弹：`BombRound.request_throw(seat, side)`、`queued` 改成按座位、UI 四键。
12. 赛跑：两个 RacePlayer、分屏 SubViewport、RaceUI 双人 HUD、`RACE_RANK_COINS` 补到五名。

## 5 收尾

13. 测试：`test_party`、`test_eat_input` 重写、`test_touch_controls` 补双人布局、`test_player_input` 补跟随、`BombRound/OwlRound/StealEat/RaceScore` 补双人分支。
14. `bash scripts/test.sh` 全绿；`tools/shot_ingame.gd` 截图看森林。
15. AGENTS.md 补同屏双人的约定；perf-log 记赛跑分屏待真机验。
