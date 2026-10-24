#!/usr/bin/env bash
# Reference solution, applied only by `astrona test` (the `testing:` block).
# `astrona run` never runs this, so the lab stays broken for the learner.
# Taken from solution.md - if one changes, change the other.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 1. Fix the Pipeline: the right result name, and runAfter between write and count.
kubectl apply -f "$SCRIPT_DIR/pipeline-launch-check.yaml"

# 2. A PipelineRun runs once: delete it and create it again.
kubectl -n starfleet delete pipelinerun launch-check-run --ignore-not-found --wait=true
kubectl apply -f "$SCRIPT_DIR/pipelinerun-launch-check-run.yaml"
kubectl -n starfleet wait --for=condition=Succeeded pipelinerun/launch-check-run --timeout=300s
