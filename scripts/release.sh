#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

version="$(awk -F'[ +]' '/^version:/ {print $2; exit}' pubspec.yaml)"
os="$(uname -s)"
mkdir -p dist

case "$os" in
  Darwin)
    flutter build macos --release
    slug="macos-aarch64"
    stem="localport-${version}-${slug}"
    rm -rf "dist/${stem}"
    mkdir -p "dist/${stem}"
    cp -R build/macos/Build/Products/Release/LocalPort.app "dist/${stem}/LocalPort.app"
    cp LICENSE README.md "dist/${stem}/"
    (cd dist && tar -czf "${stem}.tar.gz" "${stem}")
    echo "Created dist/${stem}.tar.gz"
    ;;
  Linux)
    flutter build linux --release
    slug="linux-x86_64"
    stem="localport-${version}-${slug}"
    rm -rf "dist/${stem}"
    mkdir -p "dist/${stem}"
    cp -R build/linux/x64/release/bundle/. "dist/${stem}/"
    cp LICENSE README.md "dist/${stem}/"
    (cd dist && tar -czf "${stem}.tar.gz" "${stem}")
    echo "Created dist/${stem}.tar.gz"
    ;;
  *)
    echo "Unsupported host for scripts/release.sh: ${os}" >&2
    exit 1
    ;;
esac
