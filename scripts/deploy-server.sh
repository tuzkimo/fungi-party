#!/usr/bin/env bash
# 手动把服务端发上去：本机导出 Linux 无头构建 → rsync → 远端跑 deploy/remote-restart.sh。
# 平时不用它：push 到 main 会自动部署（.github/workflows/deploy-server.yml）。
# 用法：bash scripts/deploy-server.sh 用户@主机 [端口]
# 服务器侧的一次性准备见 docs/server-deploy.md。
set -euo pipefail
cd "$(dirname "$0")/.."
HOST="${1:?用法: bash scripts/deploy-server.sh 用户@主机}"
PORT="${2:-7000}"
BIN="build/fungi-party-server.x86_64"

echo "导出 Linux 无头构建..."
godot --headless --path . --editor --quit > /dev/null 2>&1
godot --headless --path . --export-release "Linux Server" "$BIN"

echo "上传到 $HOST:~/fungi/..."
# 路径相对远端家目录，和 CI 落在同一个地方（~/fungi）
rsync -z --partial "$BIN" "$HOST:fungi/fungi-party-server.new"

echo "换上新版本并重启（在线的人会被踢下线）..."
ssh "$HOST" "bash -s -- \"\$HOME/fungi\" $PORT" < deploy/remote-restart.sh

echo "完成。服务器端口 $PORT（UDP），客户端在登录界面填 主机:$PORT"
