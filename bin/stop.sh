#!/usr/bin/env bash
cd "$(dirname "$0")/.."
for p in feed gw rdb hdb tp; do
  if [[ -f logs/$p.pid ]]; then kill "$(cat logs/$p.pid)" 2>/dev/null && echo "stopped $p"; rm -f logs/$p.pid; fi
done
