#!/usr/bin/env bash
# 联机冒烟：起一个真服务器子进程，跑客户端脚本，验存档确实落在服务器上。
# 用法：bash scripts/net_smoke.sh [端口]
set -u
cd "$(dirname "$0")/.."
PORT="${1:-7099}"
SAVES="build/net_smoke_saves"
LOG_SERVER="build/net_smoke_server.log"
LOG_CLIENT="build/net_smoke_client.log"
mkdir -p build
rm -rf "$SAVES"
# 每次换一个账号名，免得重跑时撞上上一次的记录
NAME="冒烟$(date +%H%M%S)"

godot --headless --path . --editor --quit > /dev/null 2>&1

godot --headless --path . --script res://game/net/server_main.gd -- \
	--port "$PORT" --saves "$SAVES" > "$LOG_SERVER" 2>&1 &
SRV=$!
trap 'kill $SRV 2>/dev/null' EXIT

sleep 2
if ! kill -0 $SRV 2>/dev/null; then
	echo "服务器没起来："
	cat "$LOG_SERVER"
	exit 1
fi

godot --headless --path . --script res://tools/net_smoke.gd -- \
	--port "$PORT" --name "$NAME" 2>&1 | tee "$LOG_CLIENT"
STATUS=${PIPESTATUS[0]}

echo "--- 服务器日志 ---"
grep -v "^$" "$LOG_SERVER" | tail -10
if [ "$STATUS" -ne 0 ]; then
	echo "冒烟失败（客户端退出码 $STATUS）"
	exit 1
fi
if ! grep -q "SMOKE OK" "$LOG_CLIENT"; then
	echo "冒烟失败：客户端没有输出 SMOKE OK"
	exit 1
fi
echo "冒烟通过"
