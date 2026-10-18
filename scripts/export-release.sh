#!/usr/bin/env bash
# 本地出正式签名的 release 包。keystore 和密码放在仓库外（默认 ~/.fungi-party），
# 所以这个脚本可以进 git，凭据不会。
set -euo pipefail
cd "$(dirname "$0")/.."

DIR="${FUNGI_KEYSTORE_DIR:-$HOME/.fungi-party}"
VERSION=$(sed -n 's/^version\/name="\(.*\)"/\1/p' export_presets.cfg)
[ -n "$VERSION" ] || { echo "export_presets.cfg 里读不到 version/name" >&2; exit 1; }
[ -f "$DIR/fungi-party-release.keystore" ] || { echo "找不到 $DIR/fungi-party-release.keystore" >&2; exit 1; }

export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$DIR/fungi-party-release.keystore"
export GODOT_ANDROID_KEYSTORE_RELEASE_USER="fungi-party"
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="$(cat "$DIR/password.txt")"

OUT="build/fungi_party_${VERSION}_arm64.apk"
mkdir -p build
godot --headless --path . --export-release "Android" "$OUT"
echo "出包：$OUT"
