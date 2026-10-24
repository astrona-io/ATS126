#!/usr/bin/env bash
# Reference solution, applied only by `astrona test` (the `testing:` block).
# `astrona run` never runs this, so the lab stays in its starting state.
# Taken from solution.md - if one changes, change the other.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 1. Guard deploy with a when expression and add the finally task notify.
kubectl apply -f "$SCRIPT_DIR/pipeline-ship.yaml"

# 2. Run the Pipeline for main and for a feature branch.
for run in ship-main ship-feature; do
  kubectl -n starfleet delete pipelinerun "$run" --ignore-not-found --wait=true
  kubectl apply -f "$SCRIPT_DIR/pipelinerun-$run.yaml"
done
for run in ship-main ship-feature; do
  kubectl -n starfleet wait --for=condition=Succeeded "pipelinerun/$run" --timeout=300s
done
