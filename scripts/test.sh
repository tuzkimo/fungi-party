#!/usr/bin/env bash
# 先让编辑器扫描一次，刷新全局类缓存（--script 模式不会自己扫）
set -e
cd "$(dirname "$0")/.."
godot --headless --path . --editor --quit > /dev/null 2>&1
godot --headless --path . --script res://tests/run_tests.gd
