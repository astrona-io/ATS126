#!/usr/bin/env bash
# Reference solution, applied only by `astrona test` (the `testing:` block).
# `astrona run` never runs this, so the capstone stays broken for the learner.
# Taken from solution.md - if one changes, change the other.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 1. Fix the Pipeline: resolver namespace, matrix parameter, when operator,
#    and a notify task without results.
kubectl apply -f "$SCRIPT_DIR/pipeline-bridge-ci.yaml"

# 2. Run main and feature/banner again.
for run in bridge-ci-main bridge-ci-feature; do
  kubectl -n starfleet delete pipelinerun "$run" --ignore-not-found --wait=true
  kubectl apply -f "$SCRIPT_DIR/pipelinerun-$run.yaml"
done
for run in bridge-ci-main bridge-ci-feature; do
  kubectl -n starfleet wait --for=condition=Succeeded "pipelinerun/$run" --timeout=600s
done
