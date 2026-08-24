#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
version=$(python -c 'import json,sys; print(json.load(open(sys.argv[1]))["version"])' "$root/manifest.json")
output_dir=${1:-"$root/dist"}
archive="$output_dir/denizkin.protonvpn-$version.tar.gz"

mkdir -p -- "$output_dir"
tar --sort=name --mtime='@0' --owner=0 --group=0 --numeric-owner \
  --exclude='__pycache__' --exclude='*.pyc' \
  -czf "$archive" -C "$root" \
  LICENSE Model.js Panel.qml ProtonVpnIcon.qml Service.qml qmldir manifest.json \
  README.md CHANGELOG.md DISTRIBUTION.md preview.png \
  protonvpn-data-helper protonvpn-system-helper protonvpn-signin-terminal \
  assets tests tools
sha256sum "$archive" | tee "$archive.sha256"
