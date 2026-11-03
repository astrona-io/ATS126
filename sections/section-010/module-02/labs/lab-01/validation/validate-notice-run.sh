#!/usr/bin/env bash
# PASS when the PipelineRun notice-run refers to the Pipeline notice (not an
# embedded pipelineSpec), the Pipeline declares crew as an array, the run
# succeeded, and it reports line = "Notice: bridge / r9 deck 3 (3 crew)".
set -uo pipefail

NS="starfleet"
PR="notice-run"
EXPECTED="Notice: bridge / r9 deck 3 (3 crew)"

if ! kubectl -n "$NS" get pipelinerun "$PR" >/dev/null 2>&1; then
  echo "FAIL: PipelineRun $PR does not exist in $NS."
  exit 1
fi

pipeline_ref="$(kubectl -n "$NS" get pipelinerun "$PR" -o jsonpath='{.spec.pipelineRef.name}')"
if [ "$pipeline_ref" != "notice" ]; then
  echo "FAIL: PipelineRun $PR must use pipelineRef name notice (found '${pipeline_ref:-an embedded pipelineSpec}')."
  exit 1
fi

crew_type="$(kubectl -n "$NS" get pipeline notice -o jsonpath='{.spec.params[?(@.name=="crew")].type}')"
if [ "$crew_type" != "array" ]; then
  echo "FAIL: the Pipeline notice must declare the parameter crew with type array (found '${crew_type}')."
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

line="$(kubectl -n "$NS" get pipelinerun "$PR" -o jsonpath='{.status.results[?(@.name=="line")].value}')"
if [ "$line" != "$EXPECTED" ]; then
  echo "FAIL: PipelineRun $PR has the pipeline result line='${line}', expected '$EXPECTED'."
  exit 1
fi

echo "PASS: PipelineRun $PR uses the Pipeline notice, succeeded, and reports line='$EXPECTED'."
exit 0
