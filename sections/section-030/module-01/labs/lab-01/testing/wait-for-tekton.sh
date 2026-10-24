#!/usr/bin/env bash
# Runs before the reference solution is applied.
#
# `astrona test` bootstraps and applies in one go. Wait until every Tekton
# Deployment, Gitea, the tester pod and the registry are Available, so the
# reference solution never races a component that is still starting.
set -euo pipefail

for namespace in tekton-pipelines tekton-pipelines-resolvers gitea registry; do
  deployments="$(kubectl -n "$namespace" get deployment -o name 2>/dev/null || true)"
  for deployment in $deployments; do
    replicas="$(kubectl -n "$namespace" get "$deployment" -o jsonpath='{.spec.replicas}')"
    [ "$replicas" = "0" ] && continue
    kubectl -n "$namespace" rollout status "$deployment" --timeout=300s
  done
done
kubectl get namespace starfleet >/dev/null
echo "[test] Tekton, Gitea and the registry are ready."
