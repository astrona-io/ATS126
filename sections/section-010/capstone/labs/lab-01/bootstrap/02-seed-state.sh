#!/usr/bin/env bash
# Creates the starting state for ats-126-capstone-010.
#
# 1. Applies the Tasks fetch-notes, lint-notes, spellcheck-notes, publish-notes.
# 2. Applies the Pipeline release-notes (spellcheck chained after lint, and no
#    value for the Task parameter channel).
# 3. Applies the PipelineRun release-notes-run (wrong workspace name) and waits
#    until it has failed, so the learner starts from a failure.
#
# Finding and fixing the three faults is the task.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFESTS="$SCRIPT_DIR/../manifests"

apply_with_retry() {
  # apply_with_retry FILE: the webhook can refuse the first objects while it starts.
  local attempt
  for attempt in $(seq 1 30); do
    kubectl apply -f "$1" && return 0
    echo "[capstone] kubectl apply -f $1 failed (attempt $attempt), retrying in 5s..."
    sleep 5
  done
  return 1
}

wait_for_pipelinerun_end() {
  # wait_for_pipelinerun_end NAME: waits until the Succeeded condition is True or False.
  local status=""
  for _ in $(seq 1 100); do
    status="$(kubectl -n starfleet get pipelinerun "$1" \
      -o jsonpath='{.status.conditions[?(@.type=="Succeeded")].status}' 2>/dev/null || true)"
    if [ "$status" = "True" ] || [ "$status" = "False" ]; then
      echo "[capstone] PipelineRun $1 ended with Succeeded=$status."
      return 0
    fi
    sleep 3
  done
  echo "ERROR: PipelineRun $1 did not end in time." >&2
  return 1
}

apply_with_retry "$MANIFESTS/tasks-release-notes.yaml"
apply_with_retry "$MANIFESTS/pipeline-release-notes.yaml"
apply_with_retry "$MANIFESTS/pipelinerun-release-notes-run.yaml"
wait_for_pipelinerun_end release-notes-run

echo "[capstone] Starting state ready."
kubectl -n starfleet get tasks,pipelines,pipelineruns
echo "[capstone] The PipelineRun release-notes-run failed. Finding out why and fixing it is the task."
