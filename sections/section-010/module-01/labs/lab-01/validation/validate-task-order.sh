#!/usr/bin/env bash
# PASS when, in the PipelineRun launch-check-run, the TaskRun of count started
# only after the TaskRun of write had finished, and report started after both.
# A Pipeline where count and write start together fails here, even if count
# happened to find the file.
set -uo pipefail

NS="starfleet"
PR="launch-check-run"

taskrun_time() {
  # taskrun_time PIPELINE_TASK FIELD: prints startTime or completionTime of the TaskRun.
  kubectl -n "$NS" get taskruns -l "tekton.dev/pipelineRun=$PR,tekton.dev/pipelineTask=$1" \
    -o jsonpath="{.items[0].status.$2}" 2>/dev/null
}

write_end="$(taskrun_time write completionTime)"
count_start="$(taskrun_time count startTime)"
count_end="$(taskrun_time count completionTime)"
report_start="$(taskrun_time report startTime)"

if [ -z "$write_end" ] || [ -z "$count_start" ] || [ -z "$count_end" ] || [ -z "$report_start" ]; then
  echo "FAIL: PipelineRun $PR must have finished TaskRuns for write, count and report (write end '${write_end}', count start '${count_start}', report start '${report_start}')."
  exit 1
fi

# RFC 3339 times in UTC compare correctly as strings.
if [[ "$count_start" < "$write_end" ]]; then
  echo "FAIL: count started at $count_start, before write finished at $write_end. count reads the file write creates, so it must wait for write."
  exit 1
fi
if [[ "$report_start" < "$count_end" ]] || [[ "$report_start" < "$write_end" ]]; then
  echo "FAIL: report started at $report_start, before write ($write_end) or count ($count_end) finished."
  exit 1
fi

run_after="$(kubectl -n "$NS" get pipeline launch-check -o jsonpath='{.spec.tasks[?(@.name=="count")].runAfter[*]}')"
case " $run_after " in
  *" write "*) ;;
  *)
    echo "FAIL: the pipeline task count in the Pipeline launch-check must declare runAfter: [write] (found '${run_after}')."
    exit 1 ;;
esac

echo "PASS: write finished at $write_end, count started at $count_start, report started at $report_start."
exit 0
