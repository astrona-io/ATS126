#!/usr/bin/env bash
# PASS when the PipelineRun render-run uses pipelineRef render, names the service
# account builder and runs its pods as user 1000 through taskRunTemplate.
set -uo pipefail

NS="starfleet"
PR="render-run"

if ! kubectl -n "$NS" get pipelinerun "$PR" >/dev/null 2>&1; then
  echo "FAIL: PipelineRun $PR does not exist in $NS."
  exit 1
fi
ref="$(kubectl -n "$NS" get pipelinerun "$PR" -o jsonpath='{.spec.pipelineRef.name}')"
if [ "$ref" != "render" ]; then
  echo "FAIL: PipelineRun $PR must use pipelineRef render (found '${ref:-an embedded pipelineSpec}')."
  exit 1
fi
sa="$(kubectl -n "$NS" get pipelinerun "$PR" -o jsonpath='{.spec.taskRunTemplate.serviceAccountName}')"
if [ "$sa" != "builder" ]; then
  echo "FAIL: taskRunTemplate.serviceAccountName of $PR is '${sa}', expected builder."
  exit 1
fi
uid="$(kubectl -n "$NS" get pipelinerun "$PR" -o jsonpath='{.spec.taskRunTemplate.podTemplate.securityContext.runAsUser}')"
nonroot="$(kubectl -n "$NS" get pipelinerun "$PR" -o jsonpath='{.spec.taskRunTemplate.podTemplate.securityContext.runAsNonRoot}')"
if [ "$uid" != "1000" ] || [ "$nonroot" != "true" ]; then
  echo "FAIL: the pod template of $PR needs runAsUser 1000 and runAsNonRoot true (found '${uid}', '${nonroot}')."
  exit 1
fi

echo "PASS: $PR uses the Pipeline render with service account builder and user 1000."
exit 0
