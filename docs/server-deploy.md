# 服务器部署 · 小白教程

目标：**以后 `git push` 到 main，服务器上的游戏服务自己就更新了**，不用再手动导出、scp、重启。

- 部署流程（`.github/workflows/deploy-server.yml`）已经写好在仓库里，你不用改。
- 你只需要在**服务器上做一次准备**（第 1 节），在 **GitHub 网页填 4 个密钥**（第 1.7 节），然后手动跑一次（第 2 节）。
- 之后就是正常 push（第 3 节）。

> 每段命令前面都标了**在哪台机器上敲**。代码块里的行整段复制粘贴即可，`#` 开头的是注释、不用手动改。

---

## 1. 一次性准备（做完就不用再碰）

### 1.1 建部署目录

**在服务器上**（用你平时 ssh 登录的普通用户，不是 root）：

```bash
mkdir -p ~/fungi/saves
chmod 700 ~/fungi/saves
id -un          # 记下这个用户名，1.4 和 1.7 步要用
echo $HOME      # 应该是 /home/你的用户名
rsync --version | head -1                              # 上传靠它
command -v ss systemctl journalctl                     # 健康检查靠这三个
```

`rsync` 没有的话装一下：`sudo apt install -y rsync`（Debian/Ubuntu）或 `sudo dnf install -y rsync`（RHEL 系）。

目录约定：

| 路径 | 放什么 |
|---|---|
| `~/fungi/fungi-party-server` | 游戏服务端二进制（CI 每次覆盖它） |
| `~/fungi/fungi-party-server.prev` | 上一版，回滚用 |
| `~/fungi/saves/` | 玩家存档，一个账号一个 json（**只有你能进**） |

### 1.2 生成一把只给这个仓库用的部署钥匙

**在服务器上**：

```bash
mkdir -p ~/.ssh && chmod 700 ~/.ssh
ssh-keygen -t ed25519 -f ~/.ssh/fungi-deploy -N ''
cat ~/.ssh/fungi-deploy.pub >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
cat ~/.ssh/fungi-deploy        # 把这一整段复制下来，1.7 步要填
```

为什么在服务器上生成：公钥本来就要留在服务器，直接在这儿生成最省事，你电脑完全不参与。
单独一把钥匙的意思是——哪天想收回 GitHub 的部署权限，删掉 `authorized_keys` 里对应那一行就行，不影响你自己的 ssh 登录。

复制私钥时要从 `-----BEGIN OPENSSH PRIVATE KEY-----` 一直复制到 `-----END OPENSSH PRIVATE KEY-----`，**一行都不能少**。

### 1.3 装服务（systemd）

**在服务器上**，整段粘进去（`$(id -un)` 和 `$HOME` 会自动换成你的用户名和家目录）：

```bash
sudo tee /etc/systemd/system/fungi-party-server.service > /dev/null <<EOF
[Unit]
Description=FungiParty 游戏服务器（无头）
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$(id -un)
WorkingDirectory=$HOME/fungi
Environment=HOME=$HOME/fungi
ExecStart=$HOME/fungi/fungi-party-server --headless -- --port 7000 --saves $HOME/fungi/saves --max 8
Restart=always
RestartSec=3
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable fungi-party-server
```

检查一眼有没有落到你期望的路径：

```bash
systemctl cat fungi-party-server | grep -E 'User|WorkingDirectory|ExecStart'
```

> **以前装过这个 unit 的话要重跑这一节**：导出的服务端二进制不支持 `--script`（那是编辑器版才有的），
> 现在靠主场景起服务，`ExecStart` 后面不能再带 `--script res://game/net/server_main.gd`。

> 现在先别 `start`。二进制还没上传，会启动失败并一直重试——等第 2 节第一次部署完它会自己起来。

### 1.4 允许免密重启这一个服务

CI 上传完文件后要重启服务，但普通用户重启系统服务需要 sudo。给它一条**只允许重启这一个服务**的规则，就不用把密码交给 CI，也不用开大权限。

**在服务器上**：

```bash
command -v systemctl    # 一般是 /usr/bin/systemctl，下面那行要对上
sudo visudo -f /etc/sudoers.d/fungi-party
```

在打开的编辑器里粘进这一行（把 `你的用户名` 换成 `id -un` 打印的那个；三个命令用逗号隔开，别换行断开），保存退出：

```
你的用户名 ALL=(root) NOPASSWD: /usr/bin/systemctl restart fungi-party-server, /usr/bin/systemctl is-active fungi-party-server, /usr/bin/journalctl -u fungi-party-server *
```

验证（应该直接重启成功、不问你密码）：

```bash
sudo -n systemctl restart fungi-party-server; echo "退出码 $?"
```

打印出 `退出码 0` 就对了。如果打印 `sudo: a password is required`，说明规则没生效：检查用户名拼写、`systemctl` 路径、以及 `visudo` 保存时有没有报语法错。

### 1.5 放行 UDP 7000

游戏走 UDP，不是 http，浏览器打不开是正常的。

**在服务器上**：

```bash
sudo ufw allow 7000/udp        # 如果没装 ufw 会提示 command not found，就跳过
sudo ss -lun | grep 7000       # 服务起来后能在这里看到 7000
```

**在云厂商控制台**：安全组 / 防火墙里再加一条「入方向 UDP 7000」。这一步 ufw 管不到，很多人就是漏了这一条导致真机连不上。

### 1.6 以前按老 README 装到 `/opt/fungi` 了？把存档搬过来

老的 unit 名字也叫 `fungi-party-server`，1.3 那一步已经把它覆盖成新路径了，所以不用手动停，只要确认一下：

```bash
systemctl cat fungi-party-server | grep -E 'User|WorkingDirectory'
# 应该是 User=你的用户名、WorkingDirectory=/home/你的用户名/fungi
# 如果还是 /opt/fungi，说明 1.3 没执行成功，回头重做

# 老存档搬过来（没在老布局上跑过就跳过）
sudo cp -a /var/lib/fungi/saves/. ~/fungi/saves/ 2>/dev/null
sudo chown -R "$(id -un):" ~/fungi/saves
ls -la ~/fungi/saves
```

### 1.7 在 GitHub 网页填 4 个密钥

打开仓库 → **Settings** → 左侧 **Secrets and variables** → **Actions** → 右上 **New repository secret**，一条一条加：

| Name（必须一模一样） | Value |
|---|---|
| `DEPLOY_HOST` | 服务器 IP 或域名。**不要**带 `user@`，不要带端口 |
| `DEPLOY_USER` | 1.1 里 `id -un` 打印的用户名 |
| `DEPLOY_PORT` | ssh 端口，默认 `22` |
| `DEPLOY_SSH_KEY` | 1.2 里 `cat ~/.ssh/fungi-deploy` 的**全文** |

四个都加完，列表里应该正好看到 4 条。

---

## 2. 第一次上线

仓库 → **Actions** → 左边选 `deploy-server` → 右边 **Run workflow** → 选 `main` → 绿色按钮。

跑起来会依次看到两个方块：

1. **build**（约 5-10 分钟）：装 Godot、跑单测、导出 Linux 无头构建。这一步红了就是代码/测试的问题，看日志。
2. **deploy**（几分钟到几十分钟，取决于服务器带宽）：上传 → 校验哈希 → 换上新包 → 重启 → 健康检查。

最后日志里有这么几行才算成功：

```
校验一致：<一串 sha256>
健康检查通过：UDP 7000 已在监听
```

**在服务器上验一遍**：

```bash
systemctl status fungi-party-server --no-pager    # active (running)
sudo ss -lun | grep 7000                          # UNCONN ... 0.0.0.0:7000
journalctl -u fungi-party-server -n 5 --no-pager  # 应该有「菌子派对服务器 协议 vN 端口 7000 存档 ...」
```

**真机上**打开游戏 → 启动菜单「联网」→ 地址填 `你的域名或IP:7000` → 用已有的账号登录，币和皮肤都在，就说明存档目录接对了。

---

## 3. 以后每次上线

```bash
git add -A && git commit -m "改了什么" && git push origin main
```

只要改动落在 `game/`、`project.godot`、`export_presets.cfg` 或这个 workflow 自己身上，部署就自动开始；只改文档/测试不会触发（省一次 74 MB 传输）。

看结果：仓库 → **Actions** → `deploy-server` → 点最新那次。

**注意**：每次部署都会重启服务，**在线的人会被踢下线**（一期没有重连），挑没人的时候 push。

---

## 4. 出问题对照表

先看是哪个 job 红，再看这一节。

| 报错 | 原因 | 怎么办 |
|---|---|---|
| `Permission denied (publickey)` | 私钥没填全 / 公钥没进 `authorized_keys` / `DEPLOY_USER` 写错 | 重贴 `DEPLOY_SSH_KEY` 全文；服务器上 `cat ~/.ssh/authorized_keys` 核对 |
| `ssh: connect to host ... port ...` | `DEPLOY_HOST` / `DEPLOY_PORT` 错 | 在你电脑上 `ssh -p 端口 用户@主机` 先确认能登 |
| `sudo: a password is required` | 1.4 的 sudoers 规则没生效 | `sudo -n systemctl restart fungi-party-server` 手动跑一遍，按 1.4 检查 |
| `rsync: ... No such file or directory` | `~/fungi` 没建，或 `DEPLOY_USER` 和建目录的不是同一个用户 | 回 1.1 |
| `校验不一致` | 传输中途坏了 | 不用管，重跑同一次 job（`Re-run jobs`）会从头传 |
| `健康检查失败` + 日志里 `监听失败` | 端口被别的程序占了 | `sudo ss -lunp \| grep 7000` 看是谁，`sudo systemctl stop` 掉旧的 |
| `健康检查失败` + 日志里 `存档目录` / 权限报错 | `saves` 目录权限不对 | `ls -ld ~/fungi/saves` 要是 `700 你的用户` |
| `rsync: command not found` | 服务器上没装 rsync | `sudo apt install -y rsync` |
| job 全绿但真机连不上 | 云安全组没开 UDP 7000 | 云控制台加规则（1.5） |

### 回滚到上一版

**在服务器上**：

```bash
cd ~/fungi
mv -f fungi-party-server.prev fungi-party-server
sudo systemctl restart fungi-party-server
ss -lun | grep 7000
```

（另一条路：本地 `git revert` 掉那次改动再 push，CI 会自己把旧版重新部署上去。）

### 只想手动发一次（不走 GitHub）

```bash
bash scripts/deploy-server.sh 用户@主机    # 本机导出 + 上传 + 重启（老办法，还能用）
```

---

## 5. 这套东西的边界

- 协议版本 `NetProtocol.VERSION` 一改，老客户端立刻连不上（服务端会回 version 错误）。这是自动部署的代价，客户端和服务端要一起发。
- 没有零停机、没有重连、没有 TLS、没有限流。按「给自己朋友玩」的规格做的。
- 服务器上只持久化 `~/fungi/saves/`，备份就是拷这个目录。
- Godot 版本升级要同时改两个 workflow（`release-android.yml` 和 `deploy-server.yml` 里的 `GODOT_RELEASE`）。
