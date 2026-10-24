#!/usr/bin/env bash
# PASS when the PipelineRun launch-check-run refers to the Pipeline
# launch-check (not an embedded pipelineSpec), passes release=r42, succeeded,
# and reports the pipeline result summary = "r42-manifest: 3 crew ready".
set -uo pipefail

NS="starfleet"
PR="launch-check-run"
EXPECTED="r42-manifest: 3 crew ready"

if ! kubectl -n "$NS" get pipelinerun "$PR" >/dev/null 2>&1; then
  echo "FAIL: PipelineRun $PR does not exist in $NS."
  exit 1
fi

pipeline_ref="$(kubectl -n "$NS" get pipelinerun "$PR" -o jsonpath='{.spec.pipelineRef.name}')"
if [ "$pipeline_ref" != "launch-check" ]; then
  echo "FAIL: PipelineRun $PR must use pipelineRef name launch-check (found '${pipeline_ref:-an embedded pipelineSpec}')."
  exit 1
fi

release="$(kubectl -n "$NS" get pipelinerun "$PR" -o jsonpath='{.spec.params[?(@.name=="release")].value}')"
if [ "$release" != "r42" ]; then
  echo "FAIL: PipelineRun $PR must pass release=r42 (found '${release}')."
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
  echo "FAIL: PipelineRun $PR has Succeeded=${status:-none} (reason: ${reason:-none})."
  exit 1
fi

summary="$(kubectl -n "$NS" get pipelinerun "$PR" -o jsonpath='{.status.results[?(@.name=="summary")].value}')"
if [ "$summary" != "$EXPECTED" ]; then
  echo "FAIL: PipelineRun $PR has the pipeline result summary='${summary}', expected '$EXPECTED'."
  exit 1
fi

echo "PASS: PipelineRun $PR uses the Pipeline launch-check, succeeded, and reports summary='$EXPECTED'."
exit 0
