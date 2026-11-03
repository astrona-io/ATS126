#!/usr/bin/env bash
# PASS when a new PipelineRun of notice with two crew members, a title, an
# object value and a bound workspace outbox succeeds with
# line = "Alert: a / r1 deck 5 (2 crew)" and outbox = "bound". A Pipeline that
# hard-codes a value, or does not pass the workspace on, fails here.
set -uo pipefail

NS="starfleet"
EXPECTED_LINE="Alert: a / r1 deck 5 (2 crew)"

manifest="$(mktemp)"
trap 'rm -f "$manifest"' EXIT
cat > "$manifest" <<'YAML'
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  generateName: notice-grader-
  namespace: starfleet
  labels:
    astrona.io/grader: "true"
spec:
  pipelineRef:
    name: notice
  params:
    - name: title
      value: Alert
    - name: crew
      value:
        - a
        - b
    - name: release
      value:
        name: r1
        deck: "5"
  workspaces:
    - name: outbox
      emptyDir: {}
YAML

name="$(kubectl create -f "$manifest" -o jsonpath='{.metadata.name}' 2>/dev/null)"
if [ -z "$name" ]; then
  echo "FAIL: the grader could not create a PipelineRun of the Pipeline notice."
  exit 1
fi

status=""
for _ in $(seq 1 80); do
  status="$(kubectl -n "$NS" get pipelinerun "$name" -o jsonpath='{.status.conditions[?(@.type=="Succeeded")].status}' 2>/dev/null)"
  [ "$status" = "True" ] || [ "$status" = "False" ] && break
  sleep 3
done
reason="$(kubectl -n "$NS" get pipelinerun "$name" -o jsonpath='{.status.conditions[?(@.type=="Succeeded")].reason}' 2>/dev/null)"
line="$(kubectl -n "$NS" get pipelinerun "$name" -o jsonpath='{.status.results[?(@.name=="line")].value}' 2>/dev/null)"
outbox="$(kubectl -n "$NS" get pipelinerun "$name" -o jsonpath='{.status.results[?(@.name=="outbox")].value}' 2>/dev/null)"
kubectl -n "$NS" delete pipelinerun "$name" --wait=false >/dev/null 2>&1 || true

if [ "$status" != "True" ]; then
  echo "FAIL: a grader PipelineRun of notice did not succeed (Succeeded=${status:-none}, reason ${reason:-none})."
  exit 1
fi
if [ "$line" != "$EXPECTED_LINE" ]; then
  echo "FAIL: a grader PipelineRun reported line='${line}', expected '$EXPECTED_LINE'."
  exit 1
fi
if [ "$outbox" != "bound" ]; then
  echo "FAIL: a grader PipelineRun with a bound workspace outbox reported outbox='${outbox}', expected 'bound'."
  exit 1
fi

echo "PASS: a grader PipelineRun reports '$EXPECTED_LINE' and outbox 'bound'."
exit 0
