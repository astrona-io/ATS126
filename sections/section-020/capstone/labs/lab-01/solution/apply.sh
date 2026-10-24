#!/usr/bin/env bash
# Reference solution, applied only by `astrona test` (the `testing:` block).
# `astrona run` never runs this, so the capstone stays broken for the learner.
# Taken from solution.md - if one changes, change the other.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 1. Fix the Pipeline: retries, timeout, onError and a report without results.
kubectl apply -f "$SCRIPT_DIR/pipeline-nightly.yaml"

# 2. A PipelineRun runs once: delete it and create it again.
kubectl -n starfleet delete pipelinerun nightly-run --ignore-not-found --wait=true
kubectl apply -f "$SCRIPT_DIR/pipelinerun-nightly-run.yaml"
kubectl -n starfleet wait --for=condition=Succeeded pipelinerun/nightly-run --timeout=300s
