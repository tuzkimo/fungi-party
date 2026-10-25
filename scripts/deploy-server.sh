#!/usr/bin/env bash
# 把服务端发到自己的云主机：本机导出 Linux 无头构建 → scp → 重启 systemd 服务。
# 用法：bash scripts/deploy-server.sh fungi@你的主机 [端口]
# 第一次部署见 deploy/README.md。
set -euo pipefail
cd "$(dirname "$0")/.."
HOST="${1:?用法: bash scripts/deploy-server.sh 用户@主机}"
PORT="${2:-7000}"
BIN="build/fungi-party-server.x86_64"

echo "导出 Linux 无头构建..."
godot --headless --path . --export-release "Linux Server" "$BIN"

echo "上传到 $HOST..."
scp "$BIN" "$HOST:/opt/fungi/fungi-party-server.new"

echo "换上新版本并重启（在线的人会被踢下线）..."
ssh "$HOST" "set -e
	mv /opt/fungi/fungi-party-server.new /opt/fungi/fungi-party-server
	chmod +x /opt/fungi/fungi-party-server
	systemctl restart fungi-party-server
	sleep 2
	systemctl is-active fungi-party-server
	journalctl -u fungi-party-server -n 5 --no-pager"

echo "完成。服务器端口 $PORT（UDP），客户端在登录界面填 主机:$PORT"
