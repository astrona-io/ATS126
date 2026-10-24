#!/usr/bin/env bash
# Reference solution, applied only by `astrona test` (the `testing:` block).
# `astrona run` never runs this, so the capstone stays broken for the learner.
# Taken from solution.md - if one changes, change the other.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 1. Fix the Pipeline: lint and spellcheck in parallel, publish gets channel.
kubectl apply -f "$SCRIPT_DIR/pipeline-release-notes.yaml"

# 2. Create the PipelineRun again with the workspace name "source".
kubectl -n starfleet delete pipelinerun release-notes-run --ignore-not-found --wait=true
kubectl apply -f "$SCRIPT_DIR/pipelinerun-release-notes-run.yaml"
kubectl -n starfleet wait --for=condition=Succeeded pipelinerun/release-notes-run --timeout=300s
