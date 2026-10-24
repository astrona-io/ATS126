#!/usr/bin/env bash
# PASS when a new PipelineRun of bridge-ci on the branch broken fails in lint,
# never builds or deploys, and notify still writes status=Failed, deploy=None.
# A notify task outside finally, or one that consumes a result of build, fails
# here.
set -uo pipefail

NS="starfleet"

wait_for_run() {
  # wait_for_run NAME: waits up to 6 minutes until the PipelineRun has ended,
  # then prints True or False (empty if it never ended).
  local status=""
  for _ in $(seq 1 120); do
    status="$(kubectl -n "$NS" get pipelinerun "$1" -o jsonpath='{.status.conditions[?(@.type=="Succeeded")].status}' 2>/dev/null)"
    if [ "$status" = "True" ] || [ "$status" = "False" ]; then
      break
    fi
    sleep 3
  done
  printf '%s' "$status"
}

run_field() {
  # run_field RUN JSONPATH: reads one field of a PipelineRun.
  kubectl -n "$NS" get pipelinerun "$1" -o jsonpath="$2" 2>/dev/null
}

taskrun_field() {
  # taskrun_field RUN PIPELINE_TASK JSONPATH: reads a field of the first TaskRun of a pipeline task.
  kubectl -n "$NS" get taskruns -l "tekton.dev/pipelineRun=$1,tekton.dev/pipelineTask=$2" -o jsonpath="{.items[0]$3}" 2>/dev/null
}

taskrun_list() {
  # taskrun_list RUN PIPELINE_TASK JSONPATH: prints a field of every TaskRun of a pipeline task, one per line.
  kubectl -n "$NS" get taskruns -l "tekton.dev/pipelineRun=$1,tekton.dev/pipelineTask=$2" -o jsonpath="{range .items[*]}$3{\"\n\"}{end}" 2>/dev/null
}

manifest="$(mktemp)"
trap 'rm -f "$manifest"' EXIT
cat > "$manifest" <<'YAML'
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  generateName: bridge-ci-grader-
  namespace: starfleet
  labels:
    astrona.io/grader: "true"
spec:
  pipelineRef:
    name: bridge-ci
  params:
    - name: branch
      value: broken
  taskRunTemplate:
    serviceAccountName: ci-bot
  workspaces:
    - name: source
      volumeClaimTemplate:
        spec:
          accessModes:
            - ReadWriteOnce
          resources:
            requests:
              storage: 64Mi
YAML

name="$(kubectl create -f "$manifest" -o jsonpath='{.metadata.name}' 2>/dev/null)"
if [ -z "$name" ]; then
  echo "FAIL: the grader could not create a PipelineRun of the Pipeline bridge-ci."
  exit 1
fi

status="$(wait_for_run "$name")"
lint_reason="$(taskrun_field "$name" lint '.status.conditions[0].reason')"
build_runs="$(taskrun_list "$name" build '{.metadata.name}')"
deploy_runs="$(taskrun_list "$name" deploy '{.metadata.name}')"
skipped="$(run_field "$name" '{range .status.skippedTasks[*]}{.name}: {.reason}; {end}')"
data_status="$(kubectl -n "$NS" get configmap "ci-notification-$name" -o jsonpath='{.data.status}' 2>/dev/null)"
data_deploy="$(kubectl -n "$NS" get configmap "ci-notification-$name" -o jsonpath='{.data.deploy}' 2>/dev/null)"
kubectl -n "$NS" delete pipelinerun "$name" --wait=false >/dev/null 2>&1 || true
kubectl -n "$NS" delete configmap "ci-notification-$name" --ignore-not-found >/dev/null 2>&1 || true

if [ "$status" != "False" ]; then
  echo "FAIL: a grader run on the branch broken must fail (Succeeded=${status:-none})."
  exit 1
fi
if [ "$lint_reason" != "StepFailed" ] && [ "$lint_reason" != "Failed" ]; then
  echo "FAIL: in the grader run on broken, lint should fail (reason '${lint_reason:-no TaskRun}')."
  exit 1
fi
if [ -n "$build_runs" ] || [ -n "$deploy_runs" ]; then
  echo "FAIL: the grader run on broken built or deployed although lint failed (build '${build_runs}', deploy '${deploy_runs}')."
  exit 1
fi
if [ "$data_status" != "Failed" ] || [ "$data_deploy" != "None" ]; then
  echo "FAIL: after a failed lint, notify must write status=Failed deploy=None (found status='${data_status:-no ConfigMap}', deploy='${data_deploy}'; skipped: ${skipped:-none})."
  exit 1
fi

echo "PASS: a run on broken failed in lint, built nothing, and notify reported status=Failed deploy=None."
exit 0
