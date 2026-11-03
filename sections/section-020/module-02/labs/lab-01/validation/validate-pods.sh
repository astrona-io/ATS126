#!/usr/bin/env bash
# PASS when render-run succeeded and its pods really ran with the service account
# builder and user 1000, and the TaskRun of build carries the 128Mi limit.
set -uo pipefail

NS="starfleet"
PR="render-run"

status=""
for _ in $(seq 1 60); do
  status="$(kubectl -n "$NS" get pipelinerun "$PR" -o jsonpath='{.status.conditions[?(@.type=="Succeeded")].status}' 2>/dev/null)"
  [ "$status" = "True" ] || [ "$status" = "False" ] && break
  sleep 3
done
if [ "$status" != "True" ]; then
  reason="$(kubectl -n "$NS" get pipelinerun "$PR" -o jsonpath='{.status.conditions[?(@.type=="Succeeded")].reason}' 2>/dev/null)"
  echo "FAIL: PipelineRun $PR has not succeeded (Succeeded=${status:-none}, reason '${reason}')."
  exit 1
fi

for task in fetch build; do
  pod="$(kubectl -n "$NS" get taskruns -l "tekton.dev/pipelineRun=$PR,tekton.dev/pipelineTask=$task" -o jsonpath='{.items[0].status.podName}' 2>/dev/null)"
  if [ -z "$pod" ]; then
    echo "FAIL: the task $task of $PR has no pod."
    exit 1
  fi
  sa="$(kubectl -n "$NS" get pod "$pod" -o jsonpath='{.spec.serviceAccountName}')"
  uid="$(kubectl -n "$NS" get pod "$pod" -o jsonpath='{.spec.securityContext.runAsUser}')"
  if [ "$sa" != "builder" ] || [ "$uid" != "1000" ]; then
    echo "FAIL: the pod of $task ran with service account '${sa}' and user '${uid}', expected builder and 1000."
    exit 1
  fi
done

tr_limit="$(kubectl -n "$NS" get taskruns -l "tekton.dev/pipelineRun=$PR,tekton.dev/pipelineTask=build" -o jsonpath='{.items[0].spec.computeResources.limits.memory}' 2>/dev/null)"
if [ "$tr_limit" != "128Mi" ]; then
  echo "FAIL: the TaskRun of build has the memory limit '${tr_limit}', expected 128Mi."
  exit 1
fi

echo "PASS: both pods ran as builder and user 1000, and build carries the 128Mi limit."
exit 0
