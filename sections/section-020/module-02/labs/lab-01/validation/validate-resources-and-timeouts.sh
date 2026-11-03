#!/usr/bin/env bash
# PASS when render-run limits only the pipeline task build to 128Mi of memory and
# sets the timeouts pipeline 10m, tasks 8m and finally 2m.
set -uo pipefail

NS="starfleet"
PR="render-run"

if ! kubectl -n "$NS" get pipelinerun "$PR" >/dev/null 2>&1; then
  echo "FAIL: PipelineRun $PR does not exist in $NS."
  exit 1
fi
limit="$(kubectl -n "$NS" get pipelinerun "$PR" -o jsonpath='{.spec.taskRunSpecs[?(@.pipelineTaskName=="build")].computeResources.limits.memory}')"
if [ "$limit" != "128Mi" ]; then
  echo "FAIL: taskRunSpecs for the pipeline task build must set limits.memory to 128Mi (found '${limit}')."
  exit 1
fi
other="$(kubectl -n "$NS" get pipelinerun "$PR" -o jsonpath='{.spec.taskRunSpecs[?(@.pipelineTaskName=="fetch")].computeResources.limits.memory}')"
if [ -n "$other" ]; then
  echo "FAIL: only build may get the memory limit; fetch has '${other}'."
  exit 1
fi
pipeline="$(kubectl -n "$NS" get pipelinerun "$PR" -o jsonpath='{.spec.timeouts.pipeline}')"
tasks="$(kubectl -n "$NS" get pipelinerun "$PR" -o jsonpath='{.spec.timeouts.tasks}')"
fin="$(kubectl -n "$NS" get pipelinerun "$PR" -o jsonpath='{.spec.timeouts.finally}')"
if [ "$pipeline" != "10m0s" ] || [ "$tasks" != "8m0s" ] || [ "$fin" != "2m0s" ]; then
  echo "FAIL: timeouts must be pipeline 10m, tasks 8m, finally 2m (found '${pipeline}', '${tasks}', '${fin}')."
  exit 1
fi

echo "PASS: build is limited to 128Mi and the timeouts are 10m, 8m and 2m."
exit 0
