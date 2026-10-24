#!/usr/bin/env bash
# PASS when the PipelineRun bridge-ci-feature on feature/banner built the image
# but skipped deploy by its when expression, ended Completed, and notify wrote
# status=Completed, deploy=None; and the notification of bridge-ci-main says
# status=Succeeded, deploy=Succeeded.
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

PR="bridge-ci-feature"
if ! kubectl -n "$NS" get pipelinerun "$PR" >/dev/null 2>&1; then
  echo "FAIL: PipelineRun $PR does not exist in $NS."
  exit 1
fi
if [ "$(run_field "$PR" '{.spec.pipelineRef.name}')" != "bridge-ci" ] || \
   [ "$(run_field "$PR" '{.spec.params[?(@.name=="branch")].value}')" != "feature/banner" ] || \
   [ "$(run_field "$PR" '{.spec.taskRunTemplate.serviceAccountName}')" != "ci-bot" ]; then
  echo "FAIL: $PR must use pipelineRef bridge-ci, branch=feature/banner and taskRunTemplate.serviceAccountName ci-bot."
  exit 1
fi

status="$(wait_for_run "$PR")"
reason="$(run_field "$PR" '{.status.conditions[?(@.type=="Succeeded")].reason}')"
if [ "$status" != "True" ] || [ "$reason" != "Completed" ]; then
  echo "FAIL: $PR ended with Succeeded=${status:-none} and reason '${reason}', expected True and Completed."
  exit 1
fi

build_reason="$(taskrun_field "$PR" build '.status.conditions[0].reason')"
deploy_runs="$(taskrun_list "$PR" deploy '{.metadata.name}')"
skip_reason="$(run_field "$PR" '{.status.skippedTasks[?(@.name=="deploy")].reason}')"
if [ "$build_reason" != "Succeeded" ]; then
  echo "FAIL: in $PR, build must run and succeed on a feature branch too (reason '${build_reason:-no TaskRun}')."
  exit 1
fi
if [ -n "$deploy_runs" ] || [ "$skip_reason" != "When Expressions evaluated to false" ]; then
  echo "FAIL: in $PR, deploy must be skipped by its when expression (TaskRun '${deploy_runs}', skip reason '${skip_reason:-not skipped}')."
  exit 1
fi

check_notification() {
  # check_notification RUN BRANCH STATUS DEPLOY
  local data_branch data_status data_deploy
  data_branch="$(kubectl -n "$NS" get configmap "ci-notification-$1" -o jsonpath='{.data.branch}' 2>/dev/null)"
  data_status="$(kubectl -n "$NS" get configmap "ci-notification-$1" -o jsonpath='{.data.status}' 2>/dev/null)"
  data_deploy="$(kubectl -n "$NS" get configmap "ci-notification-$1" -o jsonpath='{.data.deploy}' 2>/dev/null)"
  if [ "$data_branch" != "$2" ] || [ "$data_status" != "$3" ] || [ "$data_deploy" != "$4" ]; then
    echo "FAIL: ConfigMap ci-notification-$1 must say branch=$2 status=$3 deploy=$4 (found branch='${data_branch}' status='${data_status}' deploy='${data_deploy}')."
    return 1
  fi
}
check_notification bridge-ci-feature feature/banner Completed None || exit 1
check_notification bridge-ci-main main Succeeded Succeeded || exit 1

echo "PASS: $PR built without deploying and ended Completed; both runs were notified with the right status."
exit 0
