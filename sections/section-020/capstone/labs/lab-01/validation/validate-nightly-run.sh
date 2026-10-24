#!/usr/bin/env bash
# PASS when the PipelineRun nightly-run succeeded, warm-cache succeeded after
# at least one retry, integration succeeded, docs-check failed with the reason
# FailureIgnored, and report said "integration=Succeeded docs=Failed".
set -uo pipefail

NS="starfleet"
PR="nightly-run"
EXPECTED_MESSAGE="integration=Succeeded docs=Failed"

if ! kubectl -n "$NS" get pipelinerun "$PR" >/dev/null 2>&1; then
  echo "FAIL: PipelineRun $PR does not exist in $NS."
  exit 1
fi
pipeline_ref="$(kubectl -n "$NS" get pipelinerun "$PR" -o jsonpath='{.spec.pipelineRef.name}')"
if [ "$pipeline_ref" != "nightly" ]; then
  echo "FAIL: PipelineRun $PR must use pipelineRef name nightly (found '${pipeline_ref:-an embedded pipelineSpec}')."
  exit 1
fi

status=""
for _ in $(seq 1 80); do
  status="$(kubectl -n "$NS" get pipelinerun "$PR" -o jsonpath='{.status.conditions[?(@.type=="Succeeded")].status}')"
  [ "$status" = "True" ] || [ "$status" = "False" ] && break
  sleep 3
done
if [ "$status" != "True" ]; then
  reason="$(kubectl -n "$NS" get pipelinerun "$PR" -o jsonpath='{.status.conditions[?(@.type=="Succeeded")].reason}')"
  echo "FAIL: PipelineRun $PR has Succeeded=${status:-none} (reason: ${reason:-none})."
  exit 1
fi

taskrun_field() {
  # taskrun_field PIPELINE_TASK JSONPATH: reads one field of the TaskRun of a pipeline task.
  kubectl -n "$NS" get taskruns -l "tekton.dev/pipelineRun=$PR,tekton.dev/pipelineTask=$1" -o jsonpath="{.items[0]$2}" 2>/dev/null
}

cache_reason="$(taskrun_field warm-cache '.status.conditions[0].reason')"
cache_attempts="$(taskrun_field warm-cache '.status.retriesStatus[*].podName')"
if [ "$cache_reason" != "Succeeded" ] || [ -z "$cache_attempts" ]; then
  echo "FAIL: warm-cache must succeed after a retry (reason '${cache_reason:-none}', earlier attempts '${cache_attempts:-none}')."
  exit 1
fi

integration_reason="$(taskrun_field integration '.status.conditions[0].reason')"
if [ "$integration_reason" != "Succeeded" ]; then
  echo "FAIL: integration must succeed (reason '${integration_reason:-none}')."
  exit 1
fi

docs_reason="$(taskrun_field docs-check '.status.conditions[0].reason')"
if [ "$docs_reason" != "FailureIgnored" ]; then
  echo "FAIL: docs-check must fail with the reason FailureIgnored (found '${docs_reason:-none}')."
  exit 1
fi

message="$(taskrun_field report '.status.results[?(@.name=="message")].value')"
if [ "$message" != "$EXPECTED_MESSAGE" ]; then
  echo "FAIL: report said '${message:-nothing}', expected '$EXPECTED_MESSAGE'."
  exit 1
fi

echo "PASS: $PR succeeded; warm-cache was retried, docs-check was ignored, report said '$EXPECTED_MESSAGE'."
exit 0
