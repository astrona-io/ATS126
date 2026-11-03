#!/usr/bin/env bash
# PASS when the PipelineRun release-run fetches the Pipeline release-flow from
# ci-catalog with the cluster resolver, target=prod, succeeded, and reports
# the result summary "deploy prod".
set -uo pipefail

NS="starfleet"
PR="release-run"

if ! kubectl -n "$NS" get pipelinerun "$PR" >/dev/null 2>&1; then
  echo "FAIL: PipelineRun $PR does not exist in $NS."
  exit 1
fi
get() { kubectl -n "$NS" get pipelinerun "$PR" -o jsonpath="$1" 2>/dev/null; }
resolver="$(get '{.spec.pipelineRef.resolver}')"
if [ "$resolver" != "cluster" ]; then
  echo "FAIL: $PR must fetch its Pipeline with the cluster resolver (found '${resolver:-no resolver}')."
  exit 1
fi
for pair in kind=pipeline name=release-flow namespace=ci-catalog; do
  key="${pair%%=*}"; want="${pair#*=}"
  got="$(get "{.spec.pipelineRef.params[?(@.name==\"$key\")].value}")"
  if [ "$got" != "$want" ]; then
    echo "FAIL: resolver parameter $key of $PR is '${got}', expected '$want'."
    exit 1
  fi
done
target="$(get '{.spec.params[?(@.name=="target")].value}')"
if [ "$target" != "prod" ]; then
  echo "FAIL: $PR must set the parameter target to prod (found '${target}')."
  exit 1
fi
status=""
for _ in $(seq 1 60); do
  status="$(get '{.status.conditions[?(@.type=="Succeeded")].status}')"
  [ "$status" = "True" ] || [ "$status" = "False" ] && break
  sleep 3
done
if [ "$status" != "True" ]; then
  reason="$(get '{.status.conditions[?(@.type=="Succeeded")].reason}')"
  echo "FAIL: $PR has not succeeded (Succeeded=${status:-none}, reason '${reason}')."
  exit 1
fi
summary="$(get '{.status.results[?(@.name=="summary")].value}')"
if [ "$summary" != "deploy prod" ]; then
  echo "FAIL: the result summary of $PR is '${summary}', expected 'deploy prod'."
  exit 1
fi

echo "PASS: $PR resolved release-flow from ci-catalog and reported 'deploy prod'."
exit 0
