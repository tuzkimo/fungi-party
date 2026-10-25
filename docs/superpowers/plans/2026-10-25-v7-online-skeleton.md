# 联机一期（骨架）实施计划

> **给执行的人：** 用 superpowers:executing-plans 逐任务执行。步骤用 `- [x]` 勾选。

**目标：** 把存档、钱包、抽卡搬到自己的 Linux 服务器上，客户端能登录、能注册，单机模式原样保留。这一期结束时联机还只能一个人待着——四款小游戏和共享森林在后续计划里。

**架构：** 服务器是同一份工程的无头导出，用 ENet 收原始字节包（不走节点 RPC，省掉节点路径对齐的坑）。客户端一次一条请求，服务器按 op 白名单在账号记录上结算，落盘后回整份存档；客户端把存档缓成镜像，`Save` 的所有既有调用点不改。

**技术栈：** Godot 4.7.2 / GDScript / ENetMultiplayerPeer（原始包 API）/ JSON 文件存储 / systemd。

**设计文档：** `docs/superpowers/specs/2026-10-25-online-shared-forest-design.md`

## 全局约束

- Godot 锁 4.7.2，服务端与客户端同版本；握手校验 `NetProtocol.VERSION`。
- 一切数字进 `Config` 的 `const`；`NetOps` 不许自己发明价格、体力、概率。
- 非平凡逻辑先写测试；纯函数抽 `static func`，测试放 `tests/test_*.gd`，跑 `bash scripts/test.sh`。
- 存档字典形状与 `Save.read()` 完全一致（coins/owned/equipped/character/pity/stamina/meals/day/day_time）。
- 浮层里动态拼的文字只用 ASCII 标点（真机系统字体没有全角标点）。
- 客户端不能改钱包、抽卡结果、保底计数：`NetOps` 的客户端 op 白名单之外一律拒绝。
- 提交信息用中文。

## Review Focus

- 昵称里带 `../`、`/`、`\` 或超长字符串 → 不能写到存档目录之外，也不能把服务器写崩。
- 客户端发来超长包或损坏字节 → 服务器丢弃并继续服务其他玩家，不崩、不卡。
- 未登录的连接直接发 op → 一律拒绝，不能靠猜 peer id 拿别人存档。
- 同一个账号在两台手机上登录 → 后进的人拿到的是服务器上最新的存档，不是早先的缓存。
- 服务器磁盘上的账号文件被机器重启打断 → 要么是完整的旧文件，要么是完整的新文件，不能半截。

---

### Task 1: 包信封

**Files:** Create `game/net/protocol.gd`, `tests/test_net_protocol.gd`

**Interfaces:**
- Produces: `NetProtocol.VERSION: int`；`NetProtocol.MAX_PACKET: int`；`NetProtocol.Msg` 枚举（HELLO/CHALLENGE/PROOF/WELCOME/OP/OP_RESULT/ERROR）；
  `static func pack(kind: int, body: Dictionary) -> PackedByteArray`；`static func unpack(bytes: PackedByteArray) -> Dictionary` 返回 `{ok, kind, body}`，失败时 `ok=false` 且 `reason` 是 `"garbage" | "version" | "size"`。

- [x] 步骤 1：写测试（往返、版本不符、垃圾字节、超长包）
- [x] 步骤 2：跑 `bash scripts/test.sh`，确认失败
- [x] 步骤 3：用 `var_to_bytes` / `bytes_to_var` 实现，`unpack` 先查长度再查 `v` 再查 `t`
- [x] 步骤 4：测试通过
- [x] 步骤 5：提交

### Task 2: 口令派生

**Files:** Create `game/net/auth.gd`, `tests/test_net_auth.gd`

**Interfaces:**
- Produces: `NetAuth.ITERATIONS: int`；`static func salt() -> PackedByteArray`（16 字节）；
  `static func derive(password: String, salt: PackedByteArray) -> PackedByteArray`（32 字节，迭代 SHA-256）；
  `static func proof(derived: PackedByteArray, nonce: PackedByteArray) -> PackedByteArray`；`static func hex(b) -> String`；`static func unhex(s) -> PackedByteArray`。

- [x] 步骤 1：写测试（同密码同盐相等、换盐不等、proof 随 nonce 变、hex 往返、空盐不崩）
- [x] 步骤 2：确认失败
- [x] 步骤 3：`HashingContext` 实现；迭代数按「单次派生 < 300 ms」定，实测后写死在 const
- [x] 步骤 4：测试通过 + 打印实测耗时
- [x] 步骤 5：提交

### Task 3: 账号记录

**Files:** Create `game/net/accounts.gd`, `tests/test_net_accounts.gd`；Modify `game/systems/save.gd`（加 `defaults()`，`read()` 用它兜底）

**Interfaces:**
- Produces: `Accounts.valid_name(name: String) -> bool`；`static func path_for(dir: String, name: String) -> String`；
  `static func exists(dir, name) -> bool`；`static func create(dir, name, password) -> Dictionary`（`{ok, error, salt}`）；
  `static func salt_and_proof(dir, name) -> Dictionary`（`{exists, salt}`）；`static func verify(dir, name, proof_hex) -> bool`；
  `static func read(dir, name) -> Dictionary`（存档字典）；`static func write(dir, name, data) -> void`（原子写）。
- Consumes: `Save.defaults()`、`NetAuth`。

- [x] 步骤 1：写测试（注册/登录/错口令/非法昵称含路径穿越/文件里没有明文口令/部分写入保留其他字段/写坏前不留 .tmp）
- [x] 步骤 2：确认失败
- [x] 步骤 3：实现（JSON，写 `名字.json.tmp` 再 `rename_absolute`）
- [x] 步骤 4：测试通过
- [x] 步骤 5：提交

### Task 4: 服务器 op

**Files:** Create `game/net/ops.gd`, `tests/test_net_ops.gd`；Modify `game/systems/gacha.gd`（加公开 `roll()` 包装 `_roll`）

**Interfaces:**
- Produces: `NetOps.CLIENT_OPS: Array[String]`；`static func apply(data: Dictionary, op: String, args: Dictionary) -> Dictionary`（`{ok, data, result, error}`）。
  op：`pull{n}`、`meal`、`spend_stamina{cost}`、`equip{skin}`、`set_character{id}`、`add_coins{amount}`、`patch_day_time{t}`、`sleep`。
- Consumes: `Day`、`Gacha.roll`、`SkinCatalog`、`BodyCatalog`。

- [x] 步骤 1：写测试（抽卡扣费与保底、重复退币、吃饭份数、体力不足拒开局、未拥有皮肤不能穿、白名单外的 op 拒绝、add_coins 拒绝负数与超过单局上限）
- [x] 步骤 2：确认失败
- [x] 步骤 3：实现（规则一律调 `Day` / `Gacha` 的既有函数，不重算）
- [x] 步骤 4：测试通过
- [x] 步骤 5：提交

### Task 5: 服务器主循环

**Files:** Create `game/net/server_main.gd`

**Interfaces:**
- Produces: `godot --headless --path . --script res://game/net/server_main.gd -- --port 7000 --saves <dir> --max 32`；启动日志打一行协议版本、端口、存档目录。
- Consumes: `NetProtocol`、`NetAuth`、`Accounts`、`NetOps`。

- [x] 步骤 1：实现（`SceneTree` 脚本，`_process` 里 `multiplayer.poll()` + 收包；每 peer 一份 `{name, authed, nonce}`；30 秒未认证踢掉）
- [x] 步骤 2：`godot --headless ... --port 7099` 起服务，日志正常、能 Ctrl-C
- [x] 步骤 3：提交

### Task 6: 客户端 + 存档镜像

**Files:** Create `game/net/client.gd`；Modify `game/systems/save.gd`

**Interfaces:**
- Produces: `NetClient extends Node`，`signal logged_in`、`signal changed`、`signal failed(reason)`；
  `func connect_to(host: String, port: int, player_name: String, password: String) -> void`；
  `func request(op: String, args: Dictionary) -> void`（排队，一次一条）；`var data: Dictionary`。
  `Save.remote: NetClient`、`static func online() -> bool`。
- Consumes: 全部前序任务。

- [x] 步骤 1：实现客户端握手（HELLO → CHALLENGE → PROOF → WELCOME，含注册分支）
- [x] 步骤 2：`Save` 加远端模式：`read()` 返回镜像副本；`write()` 只把 `day_time` 推给服务器；各 op 函数改走 `remote.request`
- [x] 步骤 3：`bash scripts/test.sh` 全绿（既有测试不受影响）
- [x] 步骤 4：提交

### Task 7: 启动菜单与登录

**Files:** Create `game/ui/start_menu.gd`；Modify `game/main.tscn`、`game/main.gd`、`game/config.gd`（`SERVER_HOST` / `SERVER_PORT`）

- [x] 步骤 1：启动时盖一层「单机 / 联机」，联机进登录表单（地址、昵称、密码、[登录/注册]），失败在表单里显示原因
- [x] 步骤 2：登录成功后设 `Save.remote`、刷新外观与 HUD、关掉浮层
- [x] 步骤 3：桌面跑一次（`godot --path .`）单机路径不受影响
- [x] 步骤 4：提交

### Task 8: 部署与真连通

**状态：** 一到八全部完成并验证（`bash scripts/test.sh` 282 项全绿、`bash scripts/net_smoke.sh` 通过）。

**Files:** Create `deploy/fungi-server.service`、`scripts/deploy-server.sh`、`scripts/net_smoke.sh`、`tools/net_smoke.gd`；Modify `export_presets.cfg`（Android 加 INTERNET 权限；新增 Linux Server 预设）

- [x] 步骤 1：`scripts/net_smoke.sh`：起真服务器子进程 → 跑 `tools/net_smoke.gd`（注册、抽一抽、重连验币）→ 杀进程
- [x] 步骤 2：跑通，输出每步结果
- [x] 步骤 3：部署脚本与 systemd unit（服务端二进制放 `/opt/fungi/`，存档 `/var/lib/fungi/saves`）
- [x] 步骤 4：提交

## 后续计划（不在这一期）

- 二期：四款小游戏上服务器（逻辑类上移 + 阶段机搬迁 + 邀请），顺序 教室 → 传炸弹 → 猫头鹰 → 赛跑（赛跑要先把真人物理体换成纯模型）。
- 三期：共享森林（位置广播 15 Hz、他人替身、POI 邀请、服务器世界时钟天色）。
