#!/usr/bin/env bash
# PASS when the PipelineRun bridge-ci-main uses the Pipeline bridge-ci on the
# branch main as ci-bot, succeeded with the reason Succeeded, followed the CI
# graph (checks after clone, test as a matrix over two images, build after all
# checks), deployed after build, and ran notify as a finally task.
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

check_graph() {
  # check_graph RUN: fails unless the TaskRuns of RUN follow the CI graph.
  local run="$1" clone_end start ends end build_start build_end deploy_start images
  clone_end="$(taskrun_field "$run" clone '.status.completionTime')"
  if [ -z "$clone_end" ]; then
    echo "FAIL: $run has no finished TaskRun for clone."
    return 1
  fi
  for task in lint test scan; do
    for start in $(taskrun_list "$run" "$task" '{.status.startTime}'); do
      # RFC 3339 times in UTC compare correctly as strings.
      if [[ "$start" < "$clone_end" ]]; then
        echo "FAIL: in $run, $task started at $start, before clone finished at $clone_end."
        return 1
      fi
    done
  done
  images="$(taskrun_list "$run" test '{.spec.params[?(@.name=="image")].value}' | sort | tr '\n' ' ')"
  if [ "$images" != "alpine:3.22.7 busybox:1.37.0 " ]; then
    echo "FAIL: in $run, test must run once with busybox:1.37.0 and once with alpine:3.22.7 through a matrix (found '${images}')."
    return 1
  fi
  build_start="$(taskrun_field "$run" build '.status.startTime')"
  if [ -z "$build_start" ]; then
    echo "FAIL: $run has no TaskRun for build."
    return 1
  fi
  ends="$(for task in lint test scan; do taskrun_list "$run" "$task" '{.status.completionTime}'; done)"
  for end in $ends; do
    if [[ "$build_start" < "$end" ]]; then
      echo "FAIL: in $run, build started at $build_start, before a check (lint, test or scan) finished at $end."
      return 1
    fi
  done
  if [ "$(printf '%s\n' "$ends" | grep -c .)" -lt 4 ]; then
    echo "FAIL: in $run, build must wait for lint, both test TaskRuns and scan."
    return 1
  fi
  return 0
}

PR="bridge-ci-main"
if ! kubectl -n "$NS" get pipelinerun "$PR" >/dev/null 2>&1; then
  echo "FAIL: PipelineRun $PR does not exist in $NS."
  exit 1
fi
if [ "$(run_field "$PR" '{.spec.pipelineRef.name}')" != "bridge-ci" ] || \
   [ "$(run_field "$PR" '{.spec.params[?(@.name=="branch")].value}')" != "main" ] || \
   [ "$(run_field "$PR" '{.spec.taskRunTemplate.serviceAccountName}')" != "ci-bot" ]; then
  echo "FAIL: $PR must use pipelineRef bridge-ci, branch=main and taskRunTemplate.serviceAccountName ci-bot."
  exit 1
fi

status="$(wait_for_run "$PR")"
reason="$(run_field "$PR" '{.status.conditions[?(@.type=="Succeeded")].reason}')"
if [ "$status" != "True" ] || [ "$reason" != "Succeeded" ]; then
  echo "FAIL: $PR ended with Succeeded=${status:-none} and reason '${reason}', expected True and Succeeded (no task skipped on main)."
  exit 1
fi

check_graph "$PR" || exit 1

build_end="$(taskrun_field "$PR" build '.status.completionTime')"
deploy_start="$(taskrun_field "$PR" deploy '.status.startTime')"
deploy_reason="$(taskrun_field "$PR" deploy '.status.conditions[0].reason')"
if [ "$deploy_reason" != "Succeeded" ] || [[ "$deploy_start" < "$build_end" ]]; then
  echo "FAIL: in $PR, deploy must run after build and succeed (reason '${deploy_reason:-no TaskRun}', start '${deploy_start}', build end '${build_end}')."
  exit 1
fi

member_of="$(taskrun_field "$PR" notify '.metadata.labels.tekton\.dev/memberOf')"
if [ "$member_of" != "finally" ]; then
  echo "FAIL: in $PR, notify must run as a finally task (memberOf '${member_of:-no TaskRun}')."
  exit 1
fi

echo "PASS: $PR succeeded, followed the CI graph with a two-image test matrix, deployed after build and notified from finally."
exit 0
