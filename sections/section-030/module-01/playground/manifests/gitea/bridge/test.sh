#!/bin/sh
# Unit tests for bridge.sh: checks the status line for two inputs.
set -eu

expect() {
  actual="$(sh ./bridge.sh "$1")"
  if [ "$actual" != "$2" ]; then
    echo "FAIL: bridge.sh $1 printed '$actual', expected '$2'"
    exit 1
  fi
  echo "ok: bridge.sh $1"
}

expect scout "Bridge online for scout"
expect probe "Bridge online for probe"
