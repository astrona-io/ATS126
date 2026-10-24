#!/usr/bin/env bash
# PASS when the Pipeline ship guards deploy with a when expression on the
# parameter branch with the operator in and the value main, and runs the
# Task notify as a finally task.
set -uo pipefail

NS="starfleet"

if ! kubectl -n "$NS" get pipeline ship >/dev/null 2>&1; then
  echo "FAIL: the Pipeline ship does not exist in $NS."
  exit 1
fi

input="$(kubectl -n "$NS" get pipeline ship -o jsonpath='{.spec.tasks[?(@.name=="deploy")].when[0].input}')"
operator="$(kubectl -n "$NS" get pipeline ship -o jsonpath='{.spec.tasks[?(@.name=="deploy")].when[0].operator}')"
values="$(kubectl -n "$NS" get pipeline ship -o jsonpath='{.spec.tasks[?(@.name=="deploy")].when[0].values[*]}')"
if [ "$input" != '$(params.branch)' ] || [ "$operator" != "in" ] || [ "$values" != "main" ]; then
  echo "FAIL: deploy must have the when expression input \$(params.branch), operator in, values [main] (found input '${input}', operator '${operator}', values '${values}')."
  exit 1
fi

finally_ref="$(kubectl -n "$NS" get pipeline ship -o jsonpath='{.spec.finally[?(@.name=="notify")].taskRef.name}')"
if [ "$finally_ref" != "notify" ]; then
  echo "FAIL: the Pipeline ship must have a finally task named notify that uses the Task notify (found '${finally_ref}')."
  exit 1
fi
in_tasks="$(kubectl -n "$NS" get pipeline ship -o jsonpath='{.spec.tasks[?(@.name=="notify")].name}')"
if [ -n "$in_tasks" ]; then
  echo "FAIL: notify is also listed under spec.tasks. It belongs under spec.finally only."
  exit 1
fi

echo "PASS: deploy is guarded by branch in [main], and notify runs as a finally task."
exit 0
