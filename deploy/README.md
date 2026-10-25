# 服务器部署

一台自己的 Linux 云主机（x86_64，有 root），游戏逻辑和存档都跑在它上面。
客户端连不上就回登录界面，没有重连。

## 第一次部署

```bash
# 在服务器上（一次性）
adduser --system --group --home /var/lib/fungi fungi
mkdir -p /opt/fungi /var/lib/fungi/saves
chown -R fungi:fungi /var/lib/fungi
# 存档目录只有 fungi 能进
chmod 700 /var/lib/fungi/saves
```

把 `deploy/fungi-party-server.service` 拷到 `/etc/systemd/system/`，然后：

```bash
systemctl daemon-reload
systemctl enable --now fungi-party-server
# 放行 UDP 端口（7000 是默认）
ufw allow 7000/udp    # 或者对应云厂商安全组里开 UDP 7000
journalctl -u fungi-party-server -f   # 看日志
```

## 之后每次更新

```bash
bash scripts/deploy-server.sh fungi@你的主机
```

它会导出 Linux 无头构建、scp 上去、重启服务。**重启会把在线的人踢下线**（一期没有重连），
最好挑没人的时候。

## 注意

- 协议版本 `NetProtocol.VERSION` 一变，老客户端就连不上（会收到 version 错误）。客户端和服务端要一起发。
- 存档是 `/var/lib/fungi/saves/<昵称>.json`，一个账号一个文件。备份就是拷这个目录。
- 忘了密码没有找回：直接删了那个 json（会连同币和皮肤一起没），或者手工改它的 `key`。
- 这版服务端能裸跑公网：口令不过网、操作有白名单。但它没有限流、没有封禁、没有 TLS，
  按「给自己朋友玩」的规格做的，别拿去接陌生人。
