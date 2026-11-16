#!/usr/bin/env bash
# Start the whole stack from the repo root. Logs go to logs/<proc>.log
# Usage: bin/start.sh [--seed] [--cpp-feed]
set -euo pipefail
cd "$(dirname "$0")/.."
Q=${Q:-q}
mkdir -p logs tplogs hdb
TP=5010; RDB=5011; HDB=5012; GW=5013

if [[ " $* " == *" --seed "* ]]; then
  echo "seeding HDB ..."; $Q tick/hdb_seed.q -hdbdir hdb -days 10 -q
fi

start() { local name=$1; shift; nohup "$@" > "logs/$name.log" 2>&1 & echo $! > "logs/$name.pid"; echo "started $name (pid $!)"; sleep 1; }

start tp   $Q tick/tp.q  -p $TP  -logdir tplogs -batch 0
start hdb  $Q tick/hdb.q -p $HDB -hdbdir hdb
start rdb  $Q tick/rdb.q -p $RDB -tp $TP -hdb $HDB -hdbdir hdb
start gw   $Q tick/gw.q  -p $GW  -rdb $RDB -hdb $HDB
if [[ " $* " == *" --cpp-feed "* ]]; then
  start feed cpp/build/feed_handler localhost $TP 2000 100
else
  start feed $Q tick/feedsim.q -tp $TP -ms 100 -n 50
fi
echo "stack up. try:  q tick/client_demo.q"
