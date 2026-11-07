#!/usr/bin/env bash
# 在服务器上跑：把已上传的 .new 换成正式版、重启 systemd 服务、验 UDP 端口真的在听。
# 由 CI（.github/workflows/deploy-server.yml）和 scripts/deploy-server.sh 共用这一份，
# 改健康检查逻辑只改这里。
# 用法：bash remote-restart.sh <部署目录> [端口]
set -eu
DIR="${1:?用法: bash remote-restart.sh <部署目录> [端口]}"
PORT="${2:-7000}"

cd "$DIR"
# 旧包留一份，出事就地回滚：mv fungi-party-server.prev fungi-party-server && sudo systemctl restart fungi-party-server
[ -f fungi-party-server ] && cp -f fungi-party-server fungi-party-server.prev || true
mv -f fungi-party-server.new fungi-party-server
chmod +x fungi-party-server

# 服务没有 HTTP 端点：进程活着 + UDP 端口真的 bind 上，才算起来了。
# 崩过的 unit 会被 systemd 限流（start-limit-hit），那时连手动 restart 都会被拒，
# 先清失败计数；sudoers 没授权这一条就跳过，不挡住正常重启。
# sudo -n：CI 跑不了交互密码，没配 NOPASSWD 就立刻失败（见 docs/server-deploy.md 1.4）。
sudo -n systemctl reset-failed fungi-party-server 2>/dev/null || true
sudo -n systemctl restart fungi-party-server
for i in $(seq 1 20); do
	if systemctl is-active --quiet fungi-party-server && [ -n "$(ss -lunH "sport = :$PORT")" ]; then
		echo "健康检查通过：UDP $PORT 已在监听"
		exit 0
	fi
	sleep 2
done
echo "健康检查失败：40 秒内没看到 UDP $PORT 在监听，最近 50 行日志："
journalctl -u fungi-party-server -n 50 --no-pager || sudo -n journalctl -u fungi-party-server -n 50 --no-pager || true
exit 1
