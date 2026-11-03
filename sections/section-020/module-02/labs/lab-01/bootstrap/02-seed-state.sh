#!/usr/bin/env bash
# Creates the starting state for ats-126-lab-020-02.
#
# 1. Applies the ServiceAccount builder.
# 2. Applies the Pipeline render (two tasks, fetch and build, no settings).
#
# Creating the PipelineRun render-run with its settings is the task.
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

apply_with_retry "$MANIFESTS/serviceaccount-builder.yaml"
apply_with_retry "$MANIFESTS/pipeline-render.yaml"

echo "[lab] Starting state ready."
kubectl -n starfleet get serviceaccounts,pipelines
echo "[lab] The Pipeline render has no settings. Creating the PipelineRun render-run with them is the task."
