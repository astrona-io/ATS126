#!/usr/bin/env bash
# Creates the starting state for ats-126-lab-010-02.
#
# 1. Applies the Task write-notice.
# 2. Applies the Pipeline notice (a crew parameter of the wrong type, and an
#    optional workspace that the pipeline task never passes on).
# 3. Applies the PipelineRun notice-run and waits until it has failed, so the
#    learner starts from a failure.
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

apply_with_retry "$MANIFESTS/task-write-notice.yaml"
apply_with_retry "$MANIFESTS/pipeline-notice.yaml"
apply_with_retry "$MANIFESTS/pipelinerun-notice-run.yaml"
wait_for_pipelinerun_end notice-run

echo "[lab] Starting state ready."
kubectl -n starfleet get tasks,pipelines,pipelineruns
echo "[lab] The PipelineRun notice-run failed. Finding out why and fixing it is the task."
