#!/usr/bin/env bash
# Reference solution, applied only by `astrona test` (the `testing:` block).
# `astrona run` never runs this, so the lab stays broken for the learner.
# Taken from solution.md - if one changes, change the other.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 1. Fix the Pipeline: crew is an array, and write receives the workspace outbox.
kubectl apply -f "$SCRIPT_DIR/pipeline-notice.yaml"

# 2. A PipelineRun runs once: delete it and create it again.
kubectl -n starfleet delete pipelinerun notice-run --ignore-not-found --wait=true
kubectl apply -f "$SCRIPT_DIR/pipelinerun-notice-run.yaml"
kubectl -n starfleet wait --for=condition=Succeeded pipelinerun/notice-run --timeout=300s
