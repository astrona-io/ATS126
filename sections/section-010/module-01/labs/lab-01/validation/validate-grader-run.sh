#!/usr/bin/env bash
# PASS when a new PipelineRun of launch-check with four crew members and the
# release r7 succeeds with summary = "r7-manifest: 4 crew ready". A Pipeline
# or Task that hard-codes the summary or the count fails here.
set -uo pipefail

NS="starfleet"
EXPECTED="r7-manifest: 4 crew ready"

manifest="$(mktemp)"
trap 'rm -f "$manifest"' EXIT
cat > "$manifest" <<'YAML'
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  generateName: launch-check-grader-
  namespace: starfleet
  labels:
    astrona.io/grader: "true"
spec:
  pipelineRef:
    name: launch-check
  params:
    - name: crew
      value: "probe shuttle scout bridge"
    - name: release
      value: r7
  workspaces:
    - name: shared
      volumeClaimTemplate:
        spec:
          accessModes:
            - ReadWriteOnce
          resources:
            requests:
              storage: 16Mi
YAML

name="$(kubectl create -f "$manifest" -o jsonpath='{.metadata.name}' 2>/dev/null)"
if [ -z "$name" ]; then
  echo "FAIL: the grader could not create a PipelineRun of the Pipeline launch-check."
  exit 1
fi

status=""
for _ in $(seq 1 80); do
  status="$(kubectl -n "$NS" get pipelinerun "$name" -o jsonpath='{.status.conditions[?(@.type=="Succeeded")].status}' 2>/dev/null)"
  [ "$status" = "True" ] || [ "$status" = "False" ] && break
  sleep 3
done
reason="$(kubectl -n "$NS" get pipelinerun "$name" -o jsonpath='{.status.conditions[?(@.type=="Succeeded")].reason}' 2>/dev/null)"
summary="$(kubectl -n "$NS" get pipelinerun "$name" -o jsonpath='{.status.results[?(@.name=="summary")].value}' 2>/dev/null)"
kubectl -n "$NS" delete pipelinerun "$name" --wait=false >/dev/null 2>&1 || true

if [ "$status" != "True" ]; then
  echo "FAIL: a grader PipelineRun of launch-check (four crew members, release r7) did not succeed (Succeeded=${status:-none}, reason ${reason:-none})."
  exit 1
fi
if [ "$summary" != "$EXPECTED" ]; then
  echo "FAIL: a grader PipelineRun reported summary='${summary}', expected '$EXPECTED'."
  exit 1
fi

echo "PASS: a grader PipelineRun with four crew members reports '$EXPECTED'."
exit 0
