# 后端自动部署（CI/CD）设计

日期：2026-11-01　状态：待确认

## 要解决什么

现在上线一次服务器要人工做：本机 `godot --headless --export-release "Linux Server"` →
`scp` 74 MB 二进制 → ssh 上去 `mv` + `systemctl restart`（`scripts/deploy-server.sh`）。
换台机器、忘记导出、忘了重启都会让线上和仓库不一致。

目标：**push 到 main 之后自动测试、自动出包、自动上服务器**，全过程 GitHub 上可见，失败会红。
就自家人玩，重启把在线的人踢下线可以接受。

## 不做什么（非目标）

- 不做零停机 / 滚动发布（一期没有重连，做不到也没必要）。
- 不做 Docker / GHCR / compose。参考的 wee-cook 是 Go + postgres + redis + Caddy 的 HTTP 服务，
  才需要镜像分层缓存和 `/healthz`；这里只有一个 74 MB 的 Godot 无头二进制、UDP 游戏协议、systemd 单进程。
- 不做「服务器自己 pull」的拉模式。
- 不动客户端发版流程（`release-android.yml` 保持打 tag 才出包）。
- 不删 `scripts/deploy-server.sh`：临时热修、本机验包还用它。

## 方案对比

| 方案 | 做法 | 代价 |
|---|---|---|
| A. 推二进制 + systemd（选这个） | CI 里装 Godot 导出 Linux 无头构建 → `rsync` 到 `/opt/fungi/fungi-party-server.new` → ssh `mv` + `systemctl restart` + 健康检查 | 服务器上要一个能跑的 Godot 导出环境（CI 端）；没有镜像分层可省流量 |
| B. Docker 镜像 + GHCR + compose | 照抄 wee-cook | Godot 无头二进制把整个 pck 嵌在里面，改一行 gdscript 就整体变，**分层缓存一点省不下来**；服务器上还要多养一个 Docker 和一个反向代理。对单进程 UDP 服务是纯加壳 |
| C. 服务器上 git pull 自己导出 | 服务器装 Godot + 导出模板，systemd 跑 `scripts/deploy-server.sh` 的服务器版 | 服务器是 2 核 2G 的机器，每次部署在上面跑一遍 Godot 导出，和游戏进程抢 CPU；而且要两个项目在同一台机器上争这份模板 |

选 A：链路最短，服务器侧除了 systemd 什么都不用加，和现有的 `deploy/README.md`、`deploy/fungi-party-server.service` 完全兼容。

### A 的一个硬伤和它的补丁

Godot 服务端到外网很慢（wee-cook 那边实测 13 KB/s 量级），74 MB 一次传不完/session 断了要重来。
所以传输用 `rsync -z --partial`：断线后**重跑同一次 job 会接着传**，正常情况按块比对只传变了的块。
（不要用 `--append-verify`：目标位置可能是上一版构建留下的 `.new`，它假设前缀一定对，
等于把旧字节当新版 —— 2026-11-07 实测因此校验失败过一次。）
校验兜底：传完立刻比对 `sha256sum`，不一致就删掉 `.new` 并让 job 红，绝不会把坏包推上线。

## 触发条件

- `push` 到 `main`，且改动落在 `game/**`、`project.godot`、`export_presets.cfg`、本 workflow 自己。
- `workflow_dispatch` 手动触发（重传 / 改完服务器环境后补一发）。
- `concurrency: deploy-server`，不取消进行中的（避免两个 job 抢同一个 `.new`）。
- 只改 docs/tests/tools 不触发：这些也进 pck，但服务器不跑它们，不值 74 MB。

## 两个 job

```
build（装 Godot → 无头测试 → 导出 → 上传 artifact）──► deploy
```

合成一个 job 是因为装 Godot 每次要拉两百多 MB，分两个 job 就拉两遍；测试不过自然就不会走到导出那一步。

1. **build**：装 Godot 4.7.2 + Linux 导出模板 → `bash scripts/test.sh` →
   `godot --headless --path . --editor --quit`（刷导入缓存，新 runner 上没有 `.godot/`）→
   `godot --headless --path . --export-release "Linux Server" build/fungi-party-server.x86_64` → `upload-artifact`。
2. **deploy**（`ubuntu-latest`，拿 artifact）：
   - 先验 4 个 secret 齐不齐，缺哪个直接报哪个名字。
   - 写私钥到 `~/.ssh/deploy`（600），`known_hosts` 用 `ssh-keyscan -p 端口`。
   - `rsync -z --partial -e "ssh ..."` 到 `~/fungi/fungi-party-server.new`（校验不一致就删掉重传）。
   - 比对 `sha256sum`（本地 vs 远端）。不一致 → 删远端 `.new`、job 红。
   - ssh 把仓库里的 `deploy/remote-restart.sh` 用 `bash -s -- <目录> <端口>` 推过去执行：备份旧包成 `.prev`
     → `mv .new` 到位 → `chmod +x` → `sudo -n systemctl restart` → 轮询最多 40 秒，
     `systemctl is-active --quiet` **且** `ss -lunH "sport = :7000"` 有输出才算过。
   - 超时：打 `journalctl -u fungi-party-server -n 50 --no-pager` 并退出非零（否则 restart 失败也会显示绿色）。

健康检查为什么是这两条：服务没有 HTTP 端点。`is-active` 只证明进程没死，
UDP 端口真的 bind 上才证明它没在 `_peer.create_server()` 那步失败（那里失败只打一行 `printerr` 就退）。

## 服务器侧一次性准备（定稿：home 目录 + 一条 sudo 规则）

服务器上只有普通用户 + sudo，不折腾建系统用户和 `/opt`：

- 部署目录 `/home/<DEPLOY_USER>/fungi`（CI 里由 `DEPLOY_USER` 拼出来，不多加 secret）：
  `fungi-party-server` / `fungi-party-server.prev` / `saves/`（700）。
- systemd unit 的 `User=` 就是登录用户本身，`WorkingDirectory=/home/<user>/fungi`，
  `Environment=HOME=/home/<user>/fungi`。
- 唯一需要 root 的动作是 `systemctl restart`，给一条 NOPASSWD 规则：
  `restart fungi-party-server` + `is-active fungi-party-server` + `journalctl -u fungi-party-server *`
  （journal 只是读不到时的兜底）。CI 用 `sudo -n` 调，没配就立刻失败，不会挂在等密码上。
- 防火墙上开的还是 UDP 7000；云厂商安全组是另一个开关，容易漏。

逐步小白教程：[`docs/server-deploy.md`](../server-deploy.md)。
老的 `/opt/fungi` + 独立 `fungi` 用户布局（`deploy/fungi-party-server.service`）保留作参考，不混用。

`DEPLOY_USER` 需要对 `~/fungi` 有写权限、能免密 `systemctl restart fungi-party-server`。

## 需要的 GitHub Secrets

| Name | 内容 |
|---|---|
| `DEPLOY_HOST` | 主机名 / IP，不带 `user@`、不带端口 |
| `DEPLOY_USER` | ssh 用户（见上面权限要求） |
| `DEPLOY_PORT` | ssh 端口 |
| `DEPLOY_SSH_KEY` | 部署私钥全文 |

路径不进 secret：`/home/$DEPLOY_USER/fungi` 由 workflow 从已有的 `DEPLOY_USER` 拼出来，
少一个配置项就少一个排错点。

## 风险

- **协议版本一起变**：`NetProtocol.VERSION` 一改就自动上线，老客户端立刻连不上。这是自动部署的
  代价，接受（客户端和服务端本来就约好一起发）。
- **所有人被踢下线**：每次 push main 都重启一次。接受，之后可以再优化（比如只在没人时重启）。
- **runner 的 IP 不受控**：`ssh-keyscan` + `StrictHostKeyChecking` 首次接受，理论上中间人可截。
  自家人玩的规格下接受；真要收紧就把服务器主机公钥钉进一个 secret。
- **二进制 74 MB**：日常一次部署就是传这么多，链路慢的时候会慢。可以忍；真要优化再拆 pck 外置。

## 怎么算做完（验收）

1. 服务器上按 `docs/server-deploy.md` 做完第 1 节，4 个 secret 配好。
2. 手动跑一次 `deploy-server` workflow，两个 job（build / deploy）全绿，最后打出「健康检查通过」。
3. 服务器上 `systemctl status fungi-party-server` 是 active，`ss -lun | grep 7000` 有输出。
4. 真机上的游戏能连上并用已有账号登录（存档没丢）。
5. 故意把导出的 preset 名写错 push 一次，workflow 变红并打出服务器日志。验完 revert。
6. `docs/server-deploy.md` 已写完：日常怎么用、怎么看日志、怎么回滚。

## 文档

- `docs/server-deploy.md`：小白教程（服务器侧一次性准备 + 日常使用 + 排错对照表）。
- `deploy/README.md`：改成手动通道说明 + 指向教程。
- `deploy/remote-restart.sh`：重启 + 健康检查那段（CI 和手动脚本共用一份，不写在 YAML 里
  省得跟 heredoc 缩进、引号缠斗）。
- `scripts/deploy-server.sh`：跟上新布局（`~/fungi` + `sudo -n systemctl restart`），保留当热修通道。

## 落地时撞到的坑（2026-11-07 实装记录）

1. **deploy job 也要 `actions/checkout`**：重启那段是仓库里的 `deploy/remote-restart.sh`，
   不 checkout 就只有 artifact。
2. **`rsync --append-verify` 不能用**：目标位置可能是上一版构建留下的 `.new`，它假设前缀一定对，
   等于把旧字节当新版。改 `--partial`，哈希校验保留兜底。
3. **导出的运行时二进制没有 `--script`**（编辑器/工具版独有）。原来的部署方式
   `fungi-party-server --headless --script res://game/net/server_main.gd` 从来没生效过：
   包只会跑主场景 `main.tscn`，起来就 `Parent node is busy setting up children` 退出，UDP 一直没绑上。
   解法：`server_main.gd` 改成 `extends Node`，加 `game/net/server.tscn`，
   `project.godot` 里 `run/main_scene.dedicated_server` 指向它（实测 feature-tag 覆盖生效）；
   本地/测试用 `game/net/server_local.gd` 的 SceneTree 壳。
   systemd 的 `ExecStart` 因此改成 `--headless -- --port 7000 ...`。
4. **CI 加了一条闸**：导出后先在本机跑一遍这个二进制、等 UDP 端口 bind 上，再上传。
   前三条里的第 3 条就是「包能导出但起不来」，没这条闸只能到服务器上才发现。
