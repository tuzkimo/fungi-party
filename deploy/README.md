# 服务器部署

**自动上线（推荐）**：push 到 main，GitHub Actions 自动测试、导出、上传、重启。
一次性准备步骤（建目录、systemd、sudo 规则、GitHub 密钥）都在 **`docs/server-deploy.md`**，照那个敲一遍就行。

本文只剩下手动通道。

## 手动发一次

```bash
bash scripts/deploy-server.sh 用户@主机
```

它在本机导出 Linux 无头构建、rsync 到服务器的 `~/fungi/`、重启 systemd 服务，最后打一次端口检查。
**重启会把在线的人踢下线**（一期没有重连），挑没人的时候。

前置：服务器上按 `docs/server-deploy.md` 第 1 节建好了 `~/fungi/saves`、装好了 unit、配了 sudo 规则。

## 布局

| 路径 | 放什么 |
|---|---|
| `~/fungi/fungi-party-server` | 服务端二进制（CI 每次覆盖） |
| `~/fungi/fungi-party-server.prev` | 上一版，回滚用 |
| `~/fungi/saves/` | 存档，一个账号一个 json，`700` |

服务以你自己的用户身份跑（unit 里 `User=`），所以不需要 `/opt`，也不需要额外的系统用户。
唯一需要 sudo 的是 `systemctl restart fungi-party-server`，靠 `docs/server-deploy.md` 1.4 那条 NOPASSWD 规则。

## 注意

- 协议版本 `NetProtocol.VERSION` 一变，老客户端就连不上（会收到 version 错误）。客户端和服务端要一起发。
- 忘了密码没有找回：删掉 `~/fungi/saves/<昵称>.json`（币和皮肤一起没），或者手工改它的 `key`。
- 这版服务端能裸跑公网：口令不过网、操作有白名单。但它没有限流、没有封禁、没有 TLS，
  按「给自己朋友玩」的规格做的，别拿去接陌生人。
- `deploy/fungi-party-server.service` 是老的 `/opt/fungi` + 独立 `fungi` 用户布局的样本，
  **不要和自动部署混用**（两个 unit 抢同一个 UDP 端口）。用自动部署就照 `docs/server-deploy.md` 生成 unit。
