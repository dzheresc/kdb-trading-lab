#!/usr/bin/env bash
# Wipe all generated data (journals, HDB, logs).
cd "$(dirname "$0")/.."
bin/stop.sh
rm -rf tplogs hdb logs /tmp/kdblab_*
echo "clean"
