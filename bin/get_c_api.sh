#!/usr/bin/env bash
# Fetch the kdb+ C API (k.h + c.o for Linux x86_64) into cpp/third_party
set -euo pipefail
cd "$(dirname "$0")/.."
tmp=$(mktemp -d)
git clone -q --depth 1 https://github.com/KxSystems/kdb "$tmp/kdb"
mkdir -p cpp/third_party
cp "$tmp/kdb/c/c/k.h" "$tmp/kdb/l64/c.o" cpp/third_party/
rm -rf "$tmp"
echo "k.h and c.o copied to cpp/third_party"
