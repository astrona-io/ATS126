#!/usr/bin/env bash
# PASS when the PipelineRun release-notes-run uses the Pipeline, binds the
# workspace source, succeeded with notice = "notes-v1.4 to launch-news: 3
# lines, 11 words", ran lint and spellcheck at overlapping times, and started
# publish only after both had finished.
set -uo pipefail

NS="starfleet"
PR="release-notes-run"
EXPECTED="notes-v1.4 to launch-news: 3 lines, 11 words"

if ! kubectl -n "$NS" get pipelinerun "$PR" >/dev/null 2>&1; then
  echo "FAIL: PipelineRun $PR does not exist in $NS."
  exit 1
fi
pipeline_ref="$(kubectl -n "$NS" get pipelinerun "$PR" -o jsonpath='{.spec.pipelineRef.name}')"
workspace="$(kubectl -n "$NS" get pipelinerun "$PR" -o jsonpath='{.spec.workspaces[*].name}')"
version="$(kubectl -n "$NS" get pipelinerun "$PR" -o jsonpath='{.spec.params[?(@.name=="version")].value}')"
if [ "$pipeline_ref" != "release-notes" ] || [ "$workspace" != "source" ] || [ "$version" != "v1.4" ]; then
  echo "FAIL: PipelineRun $PR must use pipelineRef release-notes, version v1.4 and the workspace source (found '${pipeline_ref}', '${version}', '${workspace}')."
  exit 1
fi

status=""
for _ in $(seq 1 60); do
  status="$(kubectl -n "$NS" get pipelinerun "$PR" -o jsonpath='{.status.conditions[?(@.type=="Succeeded")].status}')"
  [ "$status" = "True" ] || [ "$status" = "False" ] && break
  sleep 3
done
if [ "$status" != "True" ]; then
  reason="$(kubectl -n "$NS" get pipelinerun "$PR" -o jsonpath='{.status.conditions[?(@.type=="Succeeded")].reason}')"
  echo "FAIL: PipelineRun $PR has Succeeded=${status:-none} (reason: ${reason:-none})."
  exit 1
fi

notice="$(kubectl -n "$NS" get pipelinerun "$PR" -o jsonpath='{.status.results[?(@.name=="notice")].value}')"
if [ "$notice" != "$EXPECTED" ]; then
  echo "FAIL: PipelineRun $PR has notice='${notice}', expected '$EXPECTED'."
  exit 1
fi

taskrun_time() {
  # taskrun_time PIPELINE_TASK FIELD: prints startTime or completionTime of the TaskRun.
  kubectl -n "$NS" get taskruns -l "tekton.dev/pipelineRun=$PR,tekton.dev/pipelineTask=$1" \
    -o jsonpath="{.items[0].status.$2}" 2>/dev/null
}
lint_start="$(taskrun_time lint startTime)"
lint_end="$(taskrun_time lint completionTime)"
spell_start="$(taskrun_time spellcheck startTime)"
spell_end="$(taskrun_time spellcheck completionTime)"
publish_start="$(taskrun_time publish startTime)"

# RFC 3339 times in UTC compare correctly as strings.
if ! [[ "$spell_start" < "$lint_end" && "$lint_start" < "$spell_end" ]]; then
  echo "FAIL: lint ($lint_start to $lint_end) and spellcheck ($spell_start to $spell_end) did not overlap. They must run in parallel."
  exit 1
fi
if [[ "$publish_start" < "$lint_end" ]] || [[ "$publish_start" < "$spell_end" ]]; then
  echo "FAIL: publish started at $publish_start, before lint ($lint_end) or spellcheck ($spell_end) finished."
  exit 1
fi

echo "PASS: $PR succeeded with '$EXPECTED'; lint and spellcheck overlapped and publish waited for both."
exit 0
