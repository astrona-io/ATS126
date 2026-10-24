#!/usr/bin/env bash
# PASS when a new PipelineRun of nightly with break=true fails because
# integration fails, and the finally task report still runs and says
# "integration=Failed docs=Failed".
set -uo pipefail

NS="starfleet"
EXPECTED_MESSAGE="integration=Failed docs=Failed"

manifest="$(mktemp)"
trap 'rm -f "$manifest"' EXIT
cat > "$manifest" <<'YAML'
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  generateName: nightly-grader-
  namespace: starfleet
  labels:
    astrona.io/grader: "true"
spec:
  pipelineRef:
    name: nightly
  params:
    - name: break
      value: "true"
YAML

name="$(kubectl create -f "$manifest" -o jsonpath='{.metadata.name}' 2>/dev/null)"
if [ -z "$name" ]; then
  echo "FAIL: the grader could not create a PipelineRun of the Pipeline nightly."
  exit 1
fi

status=""
for _ in $(seq 1 80); do
  status="$(kubectl -n "$NS" get pipelinerun "$name" -o jsonpath='{.status.conditions[?(@.type=="Succeeded")].status}' 2>/dev/null)"
  [ "$status" = "True" ] || [ "$status" = "False" ] && break
  sleep 3
done
integration_reason="$(kubectl -n "$NS" get taskruns -l "tekton.dev/pipelineRun=$name,tekton.dev/pipelineTask=integration" -o jsonpath='{.items[0].status.conditions[0].reason}' 2>/dev/null)"
message="$(kubectl -n "$NS" get taskruns -l "tekton.dev/pipelineRun=$name,tekton.dev/pipelineTask=report" -o jsonpath='{.items[0].status.results[?(@.name=="message")].value}' 2>/dev/null)"
skipped="$(kubectl -n "$NS" get pipelinerun "$name" -o jsonpath='{range .status.skippedTasks[*]}{.name}: {.reason}; {end}' 2>/dev/null)"
kubectl -n "$NS" delete pipelinerun "$name" --wait=false >/dev/null 2>&1 || true

if [ "$status" != "False" ]; then
  echo "FAIL: a grader PipelineRun of nightly with break=true must fail (Succeeded=${status:-none})."
  exit 1
fi
if [ "$integration_reason" != "StepFailed" ] && [ "$integration_reason" != "Failed" ]; then
  echo "FAIL: in the grader run, integration should fail in its step (reason '${integration_reason:-no TaskRun}')."
  exit 1
fi
if [ "$message" != "$EXPECTED_MESSAGE" ]; then
  echo "FAIL: after failed tests, report said '${message:-nothing}' (skipped tasks: ${skipped:-none}); expected '$EXPECTED_MESSAGE'."
  exit 1
fi

echo "PASS: failed tests were reported as '$EXPECTED_MESSAGE'."
exit 0
