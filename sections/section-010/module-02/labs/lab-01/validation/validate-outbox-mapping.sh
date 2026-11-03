#!/usr/bin/env bash
# PASS when the Pipeline notice keeps its workspace outbox optional and the
# pipeline task write passes it on to the Task. The grader run checks the
# behaviour; this check names the exact field.
set -uo pipefail

NS="starfleet"

optional="$(kubectl -n "$NS" get pipeline notice -o jsonpath='{.spec.workspaces[?(@.name=="outbox")].optional}')"
if [ "$optional" != "true" ]; then
  echo "FAIL: the workspace outbox of the Pipeline notice must stay optional (found '${optional}')."
  exit 1
fi

mapped="$(kubectl -n "$NS" get pipeline notice -o jsonpath='{.spec.tasks[?(@.name=="write")].workspaces[?(@.name=="outbox")].workspace}')"
if [ "$mapped" != "outbox" ]; then
  echo "FAIL: the pipeline task write must pass the Pipeline workspace outbox to the Task workspace outbox (found '${mapped}')."
  exit 1
fi

echo "PASS: outbox is optional in the Pipeline notice and the pipeline task write passes it on."
exit 0
