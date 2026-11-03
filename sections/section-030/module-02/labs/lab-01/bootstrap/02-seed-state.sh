#!/usr/bin/env bash
# Creates the starting state for ats-126-lab-030-02.
#
# 1. Applies the shared catalog: the namespace ci-catalog with the Task announce
#    and the Pipeline release-flow.
# 2. Applies the Pipeline flow in starfleet, which fetches announce with the
#    cluster resolver and has a seeded fault in the namespace it asks for.
#
# Fixing flow and creating the two PipelineRuns is the task.
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

apply_with_retry "$MANIFESTS/catalog.yaml"
apply_with_retry "$MANIFESTS/pipeline-flow.yaml"

echo "[lab] Starting state ready."
kubectl -n ci-catalog get tasks,pipelines
kubectl -n starfleet get pipelines
echo "[lab] The Pipeline flow cannot find its Task yet. Fixing it and creating the runs is the task."
