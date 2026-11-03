#!/usr/bin/env bash
# PASS when the Pipeline flow still fetches announce with the cluster resolver
# and asks for kind task, name announce and namespace ci-catalog.
set -uo pipefail

NS="starfleet"
get() { kubectl -n "$NS" get pipeline flow -o jsonpath="$1" 2>/dev/null; }

if ! kubectl -n "$NS" get pipeline flow >/dev/null 2>&1; then
  echo "FAIL: Pipeline flow does not exist in $NS."
  exit 1
fi
resolver="$(get '{.spec.tasks[?(@.name=="call")].taskRef.resolver}')"
if [ "$resolver" != "cluster" ]; then
  echo "FAIL: the pipeline task call must keep using the cluster resolver (found '${resolver}')."
  exit 1
fi
for pair in kind=task name=announce namespace=ci-catalog; do
  key="${pair%%=*}"; want="${pair#*=}"
  got="$(get "{.spec.tasks[?(@.name==\"call\")].taskRef.params[?(@.name==\"$key\")].value}")"
  if [ "$got" != "$want" ]; then
    echo "FAIL: resolver parameter $key of call is '${got}', expected '$want'."
    exit 1
  fi
done

echo "PASS: flow fetches announce from ci-catalog with the cluster resolver."
exit 0
