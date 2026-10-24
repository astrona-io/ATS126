#!/usr/bin/env bash
# PASS when a new PipelineRun of release-notes with version v2.0 and channel
# outpost-news succeeds with notice = "notes-v2.0 to outpost-news: 3 lines,
# 11 words". A Pipeline that hard-codes the channel or the notice fails here.
set -uo pipefail

NS="starfleet"
EXPECTED="notes-v2.0 to outpost-news: 3 lines, 11 words"

manifest="$(mktemp)"
trap 'rm -f "$manifest"' EXIT
cat > "$manifest" <<'YAML'
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  generateName: release-notes-grader-
  namespace: starfleet
  labels:
    astrona.io/grader: "true"
spec:
  pipelineRef:
    name: release-notes
  params:
    - name: version
      value: v2.0
    - name: channel
      value: outpost-news
  workspaces:
    - name: source
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
  echo "FAIL: the grader could not create a PipelineRun of the Pipeline release-notes."
  exit 1
fi

status=""
for _ in $(seq 1 80); do
  status="$(kubectl -n "$NS" get pipelinerun "$name" -o jsonpath='{.status.conditions[?(@.type=="Succeeded")].status}' 2>/dev/null)"
  [ "$status" = "True" ] || [ "$status" = "False" ] && break
  sleep 3
done
reason="$(kubectl -n "$NS" get pipelinerun "$name" -o jsonpath='{.status.conditions[?(@.type=="Succeeded")].reason}' 2>/dev/null)"
notice="$(kubectl -n "$NS" get pipelinerun "$name" -o jsonpath='{.status.results[?(@.name=="notice")].value}' 2>/dev/null)"
kubectl -n "$NS" delete pipelinerun "$name" --wait=false >/dev/null 2>&1 || true

if [ "$status" != "True" ]; then
  echo "FAIL: a grader PipelineRun of release-notes (version v2.0, channel outpost-news) did not succeed (Succeeded=${status:-none}, reason ${reason:-none})."
  exit 1
fi
if [ "$notice" != "$EXPECTED" ]; then
  echo "FAIL: a grader PipelineRun reported notice='${notice}', expected '$EXPECTED'."
  exit 1
fi

echo "PASS: a grader PipelineRun with channel outpost-news reports '$EXPECTED'."
exit 0
