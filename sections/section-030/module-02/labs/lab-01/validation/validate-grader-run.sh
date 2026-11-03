#!/usr/bin/env bash
# PASS when a new PipelineRun of the Pipeline flow with another message also
# works, so the fix is real and not tied to the learner's own run.
set -uo pipefail

NS="starfleet"
PR="grader-flow"

kubectl -n "$NS" delete pipelinerun "$PR" --ignore-not-found --wait=true >/dev/null 2>&1
if ! kubectl -n "$NS" apply -f - >/dev/null <<YAML
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  name: $PR
  namespace: $NS
spec:
  pipelineRef:
    name: flow
  params:
    - name: message
      value: graded
YAML
then
  echo "FAIL: could not create the grader PipelineRun (does the Pipeline flow exist?)."
  exit 1
fi
status=""
for _ in $(seq 1 100); do
  status="$(kubectl -n "$NS" get pipelinerun "$PR" -o jsonpath='{.status.conditions[?(@.type=="Succeeded")].status}' 2>/dev/null)"
  [ "$status" = "True" ] || [ "$status" = "False" ] && break
  sleep 3
done
line="$(kubectl -n "$NS" get pipelinerun "$PR" -o jsonpath='{.status.results[?(@.name=="line")].value}' 2>/dev/null)"
reason="$(kubectl -n "$NS" get pipelinerun "$PR" -o jsonpath='{.status.conditions[?(@.type=="Succeeded")].reason}' 2>/dev/null)"
kubectl -n "$NS" delete pipelinerun "$PR" --ignore-not-found --wait=false >/dev/null 2>&1
if [ "$status" != "True" ] || [ "$line" != "announce: graded" ]; then
  echo "FAIL: the grader run of flow ended with Succeeded=${status:-none}, reason '${reason}', line '${line}'; expected True and 'announce: graded'."
  exit 1
fi

echo "PASS: a new run of flow reported 'announce: graded'."
exit 0
