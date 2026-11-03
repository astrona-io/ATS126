#!/usr/bin/env bash
# PASS when the PipelineRun flow-run uses pipelineRef flow with message=ready,
# succeeded, and reports the result line "announce: ready".
set -uo pipefail

NS="starfleet"
PR="flow-run"

if ! kubectl -n "$NS" get pipelinerun "$PR" >/dev/null 2>&1; then
  echo "FAIL: PipelineRun $PR does not exist in $NS."
  exit 1
fi
ref="$(kubectl -n "$NS" get pipelinerun "$PR" -o jsonpath='{.spec.pipelineRef.name}')"
message="$(kubectl -n "$NS" get pipelinerun "$PR" -o jsonpath='{.spec.params[?(@.name=="message")].value}')"
if [ "$ref" != "flow" ] || [ "$message" != "ready" ]; then
  echo "FAIL: $PR must use pipelineRef flow with message=ready (found '${ref:-an embedded pipelineSpec}', '${message}')."
  exit 1
fi
status=""
for _ in $(seq 1 60); do
  status="$(kubectl -n "$NS" get pipelinerun "$PR" -o jsonpath='{.status.conditions[?(@.type=="Succeeded")].status}')"
  [ "$status" = "True" ] || [ "$status" = "False" ] && break
  sleep 3
done
if [ "$status" != "True" ]; then
  reason="$(kubectl -n "$NS" get pipelinerun "$PR" -o jsonpath='{.status.conditions[?(@.type=="Succeeded")].reason}')"
  echo "FAIL: $PR has not succeeded (Succeeded=${status:-none}, reason '${reason}')."
  exit 1
fi
line="$(kubectl -n "$NS" get pipelinerun "$PR" -o jsonpath='{.status.results[?(@.name=="line")].value}')"
if [ "$line" != "announce: ready" ]; then
  echo "FAIL: the result line of $PR is '${line}', expected 'announce: ready'."
  exit 1
fi

echo "PASS: $PR succeeded with the line 'announce: ready'."
exit 0
