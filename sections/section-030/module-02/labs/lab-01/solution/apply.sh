#!/usr/bin/env bash
# Reference solution, applied only by `astrona test` (the `testing:` block).
# `astrona run` never runs this, so the lab stays in its starting state.
# Taken from solution.md - if one changes, change the other.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

kubectl apply -f "$SCRIPT_DIR/pipeline-flow.yaml"
for run in flow-run release-run; do
  kubectl -n starfleet delete pipelinerun "$run" --ignore-not-found --wait=true
  kubectl apply -f "$SCRIPT_DIR/pipelinerun-$run.yaml"
done
for run in flow-run release-run; do
  kubectl -n starfleet wait --for=condition=Succeeded "pipelinerun/$run" --timeout=300s
done
