#!/usr/bin/env bash
# PASS when the Pipeline nightly retries warm-cache once or twice, gives
# integration a timeout between 1m and 5m, lets docs-check fail with
# onError: continue (and no retries), and keeps report under finally without
# consuming a result of integration.
set -uo pipefail

NS="starfleet"

pipeline_field() {
  # pipeline_field JSONPATH: reads one field of the Pipeline nightly.
  kubectl -n "$NS" get pipeline nightly -o jsonpath="$1" 2>/dev/null
}

duration_seconds() {
  # duration_seconds GO_DURATION: converts 1h2m3s, 2m0s, 90s to seconds.
  local value="$1" total=0 number unit
  while [[ "$value" =~ ^([0-9]+)(h|m|s)(.*)$ ]]; do
    number="${BASH_REMATCH[1]}"; unit="${BASH_REMATCH[2]}"; value="${BASH_REMATCH[3]}"
    case "$unit" in
      h) total=$((total + number * 3600)) ;;
      m) total=$((total + number * 60)) ;;
      s) total=$((total + number)) ;;
    esac
  done
  [ -z "$value" ] || { echo -1; return; }
  echo "$total"
}

if ! kubectl -n "$NS" get pipeline nightly >/dev/null 2>&1; then
  echo "FAIL: the Pipeline nightly does not exist in $NS."
  exit 1
fi

retries="$(pipeline_field '{.spec.tasks[?(@.name=="warm-cache")].retries}')"
if [ "${retries:-0}" -lt 1 ] || [ "${retries:-0}" -gt 2 ]; then
  echo "FAIL: warm-cache must have retries 1 or 2 (found '${retries:-none}')."
  exit 1
fi

timeout="$(pipeline_field '{.spec.tasks[?(@.name=="integration")].timeout}')"
seconds="$(duration_seconds "${timeout:-}")"
if [ -z "$timeout" ] || [ "$seconds" -lt 60 ] || [ "$seconds" -gt 300 ]; then
  echo "FAIL: integration must have a timeout between 1m and 5m (found '${timeout:-none}')."
  exit 1
fi

on_error="$(pipeline_field '{.spec.tasks[?(@.name=="docs-check")].onError}')"
docs_retries="$(pipeline_field '{.spec.tasks[?(@.name=="docs-check")].retries}')"
if [ "$on_error" != "continue" ] || { [ -n "$docs_retries" ] && [ "$docs_retries" != "0" ]; }; then
  echo "FAIL: docs-check must have onError: continue and no retries (found onError '${on_error:-none}', retries '${docs_retries:-none}')."
  exit 1
fi

report_ref="$(pipeline_field '{.spec.finally[?(@.name=="report")].taskRef.name}')"
report_params="$(pipeline_field '{.spec.finally[?(@.name=="report")].params[*].value}')"
if [ "$report_ref" != "report" ]; then
  echo "FAIL: report must stay a finally task that uses the Task report (found '${report_ref:-not under finally}')."
  exit 1
fi
case "$report_params" in
  *'.results.'*)
    echo "FAIL: the finally task report still consumes a result ('$report_params'). It is skipped whenever that result is missing."
    exit 1 ;;
esac

echo "PASS: warm-cache retries $retries, integration timeout $timeout, docs-check onError continue, report uses no results."
exit 0
