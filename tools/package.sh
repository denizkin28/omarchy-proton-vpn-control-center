#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
version=$(python -c 'import json,sys; print(json.load(open(sys.argv[1]))["version"])' "$root/manifest.json")
output_dir=${1:-"$root/dist"}
archive_name="denizkin.protonvpn-$version.tar.gz"
archive="$output_dir/$archive_name"

mkdir -p -- "$output_dir"
tar --sort=name --mtime='@0' --owner=0 --group=0 --numeric-owner \
  --exclude='__pycache__' --exclude='*.pyc' \
  -czf "$archive" -C "$root" \
  LICENSE Model.js Panel.qml ProtonVpnIcon.qml Service.qml qmldir manifest.json \
  README.md CHANGELOG.md DISTRIBUTION.md SECURITY.md preview.png \
  protonvpn-data-helper protonvpn-system-helper protonvpn-signin-terminal \
  assets tests tools
(cd "$output_dir" && sha256sum "$archive_name") | tee "$archive.sha256"
