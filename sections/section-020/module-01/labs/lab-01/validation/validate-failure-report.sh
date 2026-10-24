#!/usr/bin/env bash
# PASS when a new PipelineRun of ship for main with fail=true fails, does not
# deploy, and still runs the finally task notify, which reports
# "branch=main pipeline=Failed deploy=None". A notify task under spec.tasks,
# or one that consumes a result of build or deploy, fails here.
set -uo pipefail

NS="starfleet"
EXPECTED_MESSAGE="branch=main pipeline=Failed deploy=None"

manifest="$(mktemp)"
trap 'rm -f "$manifest"' EXIT
cat > "$manifest" <<'YAML'
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  generateName: ship-grader-
  namespace: starfleet
  labels:
    astrona.io/grader: "true"
spec:
  pipelineRef:
    name: ship
  params:
    - name: branch
      value: main
    - name: fail
      value: "true"
YAML

name="$(kubectl create -f "$manifest" -o jsonpath='{.metadata.name}' 2>/dev/null)"
if [ -z "$name" ]; then
  echo "FAIL: the grader could not create a PipelineRun of the Pipeline ship."
  exit 1
fi

status=""
for _ in $(seq 1 60); do
  status="$(kubectl -n "$NS" get pipelinerun "$name" -o jsonpath='{.status.conditions[?(@.type=="Succeeded")].status}' 2>/dev/null)"
  [ "$status" = "True" ] || [ "$status" = "False" ] && break
  sleep 3
done
deploy_runs="$(kubectl -n "$NS" get taskruns -l "tekton.dev/pipelineRun=$name,tekton.dev/pipelineTask=deploy" -o name 2>/dev/null)"
message="$(kubectl -n "$NS" get taskruns -l "tekton.dev/pipelineRun=$name,tekton.dev/pipelineTask=notify" -o jsonpath='{.items[0].status.results[?(@.name=="message")].value}' 2>/dev/null)"
skipped="$(kubectl -n "$NS" get pipelinerun "$name" -o jsonpath='{range .status.skippedTasks[*]}{.name}: {.reason}; {end}' 2>/dev/null)"
kubectl -n "$NS" delete pipelinerun "$name" --wait=false >/dev/null 2>&1 || true

if [ "$status" != "False" ]; then
  echo "FAIL: a grader PipelineRun of ship with fail=true must fail (Succeeded=${status:-none})."
  exit 1
fi
if [ -n "$deploy_runs" ]; then
  echo "FAIL: a grader PipelineRun with a failed build still ran deploy."
  exit 1
fi
if [ "$message" != "$EXPECTED_MESSAGE" ]; then
  echo "FAIL: after a failed build, notify reported '${message:-nothing}' (skipped tasks: ${skipped:-none}); expected '$EXPECTED_MESSAGE'."
  exit 1
fi

echo "PASS: a failed build was reported by notify as '$EXPECTED_MESSAGE'."
exit 0
