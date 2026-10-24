#!/usr/bin/env bash
# Creates the starting state for ats-126-lab-010-01.
#
# 1. Applies the Tasks write-manifest, count-crew and report.
# 2. Applies the Pipeline launch-check (a misspelled result reference, and no
#    edge between write and count).
# 3. Applies the PipelineRun launch-check-run and waits until it has failed,
#    so the learner starts from a failure.
#
# Finding and fixing both faults is the task.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFESTS="$SCRIPT_DIR/../manifests"

apply_with_retry() {
  # apply_with_retry FILE: the webhook can refuse the first objects while it starts.
  local attempt
  for attempt in $(seq 1 30); do
    kubectl apply -f "$1" && return 0
    echo "[lab] kubectl apply -f $1 failed (attempt $attempt), retrying in 5s..."
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
      echo "[lab] PipelineRun $1 ended with Succeeded=$status."
      return 0
    fi
    sleep 3
  done
  echo "ERROR: PipelineRun $1 did not end in time." >&2
  return 1
}

for task in task-write-manifest task-count-crew task-report; do
  apply_with_retry "$MANIFESTS/$task.yaml"
done
apply_with_retry "$MANIFESTS/pipeline-launch-check.yaml"
apply_with_retry "$MANIFESTS/pipelinerun-launch-check-run.yaml"
wait_for_pipelinerun_end launch-check-run

echo "[lab] Starting state ready."
kubectl -n starfleet get tasks,pipelines,pipelineruns
echo "[lab] The PipelineRun launch-check-run failed. Finding out why and fixing it is the task."
