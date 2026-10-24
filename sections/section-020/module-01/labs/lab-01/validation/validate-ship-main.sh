#!/usr/bin/env bash
# PASS when the PipelineRun ship-main uses the Pipeline ship with branch=main, ended
# with the reason Succeeded, ran deploy, and its finally task notify reported
# "branch=main pipeline=Succeeded deploy=Succeeded".
set -uo pipefail

NS="starfleet"
PR="ship-main"
BRANCH="main"
EXPECTED_REASON="Succeeded"
EXPECTED_MESSAGE="branch=main pipeline=Succeeded deploy=Succeeded"

if ! kubectl -n "$NS" get pipelinerun "$PR" >/dev/null 2>&1; then
  echo "FAIL: PipelineRun $PR does not exist in $NS."
  exit 1
fi
pipeline_ref="$(kubectl -n "$NS" get pipelinerun "$PR" -o jsonpath='{.spec.pipelineRef.name}')"
branch="$(kubectl -n "$NS" get pipelinerun "$PR" -o jsonpath='{.spec.params[?(@.name=="branch")].value}')"
if [ "$pipeline_ref" != "ship" ] || [ "$branch" != "$BRANCH" ]; then
  echo "FAIL: PipelineRun $PR must use pipelineRef ship and branch=$BRANCH (found '${pipeline_ref:-an embedded pipelineSpec}', '${branch}')."
  exit 1
fi

status=""
for _ in $(seq 1 60); do
  status="$(kubectl -n "$NS" get pipelinerun "$PR" -o jsonpath='{.status.conditions[?(@.type=="Succeeded")].status}')"
  [ "$status" = "True" ] || [ "$status" = "False" ] && break
  sleep 3
done
reason="$(kubectl -n "$NS" get pipelinerun "$PR" -o jsonpath='{.status.conditions[?(@.type=="Succeeded")].reason}')"
if [ "$status" != "True" ] || [ "$reason" != "$EXPECTED_REASON" ]; then
  echo "FAIL: PipelineRun $PR ended with Succeeded=${status:-none} and reason '${reason}', expected True and '$EXPECTED_REASON'."
  exit 1
fi

deploy_reason="$(kubectl -n "$NS" get taskruns -l "tekton.dev/pipelineRun=$PR,tekton.dev/pipelineTask=deploy" -o jsonpath='{.items[0].status.conditions[0].reason}' 2>/dev/null)"
skip_reason="$(kubectl -n "$NS" get pipelinerun "$PR" -o jsonpath='{.status.skippedTasks[?(@.name=="deploy")].reason}')"
if [ "$deploy_reason" != "Succeeded" ]; then
  echo "FAIL: in $PR the task deploy must run and succeed (TaskRun reason '${deploy_reason:-no TaskRun}', skipped '${skip_reason}')."
  exit 1
fi

member_of="$(kubectl -n "$NS" get taskruns -l "tekton.dev/pipelineRun=$PR,tekton.dev/pipelineTask=notify" -o jsonpath='{.items[0].metadata.labels.tekton\.dev/memberOf}' 2>/dev/null)"
message="$(kubectl -n "$NS" get taskruns -l "tekton.dev/pipelineRun=$PR,tekton.dev/pipelineTask=notify" -o jsonpath='{.items[0].status.results[?(@.name=="message")].value}' 2>/dev/null)"
if [ "$member_of" != "finally" ]; then
  echo "FAIL: in $PR the task notify must run as a finally task (memberOf '${member_of:-no TaskRun}')."
  exit 1
fi
if [ "$message" != "$EXPECTED_MESSAGE" ]; then
  echo "FAIL: in $PR notify reported '${message}', expected '$EXPECTED_MESSAGE'."
  exit 1
fi

echo "PASS: $PR ended $EXPECTED_REASON and notify reported '$EXPECTED_MESSAGE'."
exit 0
