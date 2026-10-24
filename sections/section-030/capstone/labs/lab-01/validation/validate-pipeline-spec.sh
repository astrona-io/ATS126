#!/usr/bin/env bash
# PASS when the Pipeline bridge-ci fetches build-image from ci-catalog with
# the cluster resolver (and no copy of the Task sits in starfleet), its test
# matrix passes image with both images, deploy runs only for main, and the
# finally task notify uses no results.
set -uo pipefail

NS="starfleet"

pipeline_field() {
  # pipeline_field JSONPATH: reads one field of the Pipeline bridge-ci.
  kubectl -n "$NS" get pipeline bridge-ci -o jsonpath="$1" 2>/dev/null
}

if ! kubectl -n "$NS" get pipeline bridge-ci >/dev/null 2>&1; then
  echo "FAIL: the Pipeline bridge-ci does not exist in $NS."
  exit 1
fi

resolver="$(pipeline_field '{.spec.tasks[?(@.name=="build")].taskRef.resolver}')"
resolver_ns="$(pipeline_field '{.spec.tasks[?(@.name=="build")].taskRef.params[?(@.name=="namespace")].value}')"
resolver_name="$(pipeline_field '{.spec.tasks[?(@.name=="build")].taskRef.params[?(@.name=="name")].value}')"
if [ "$resolver" != "cluster" ] || [ "$resolver_ns" != "ci-catalog" ] || [ "$resolver_name" != "build-image" ]; then
  echo "FAIL: build must use the cluster resolver for build-image in ci-catalog (found resolver '${resolver}', namespace '${resolver_ns}', name '${resolver_name}')."
  exit 1
fi
if kubectl -n "$NS" get task build-image >/dev/null 2>&1; then
  echo "FAIL: a copy of the Task build-image exists in $NS. The team keeps one copy, in ci-catalog; fix the resolver reference instead."
  exit 1
fi

matrix_names="$(pipeline_field '{.spec.tasks[?(@.name=="test")].matrix.params[*].name}')"
matrix_values="$(pipeline_field '{.spec.tasks[?(@.name=="test")].matrix.params[?(@.name=="image")].value[*]}')"
if [ "$matrix_names" != "image" ] || [ "$matrix_values" != "busybox:1.37.0 alpine:3.22.7" ]; then
  echo "FAIL: the matrix of test must pass only image with busybox:1.37.0 and alpine:3.22.7 (found names '${matrix_names}', values '${matrix_values}')."
  exit 1
fi

input="$(pipeline_field '{.spec.tasks[?(@.name=="deploy")].when[0].input}')"
operator="$(pipeline_field '{.spec.tasks[?(@.name=="deploy")].when[0].operator}')"
values="$(pipeline_field '{.spec.tasks[?(@.name=="deploy")].when[0].values[*]}')"
if [ "$input" != '$(params.branch)' ] || [ "$operator" != "in" ] || [ "$values" != "main" ]; then
  echo "FAIL: deploy must run only when \$(params.branch) is in [main] (found input '${input}', operator '${operator}', values '${values}')."
  exit 1
fi

notify_params="$(pipeline_field '{.spec.finally[?(@.name=="notify")].params[*].value}')"
if [ -z "$notify_params" ]; then
  echo "FAIL: notify must stay a finally task with its parameters."
  exit 1
fi
case "$notify_params" in
  *'.results.'*)
    echo "FAIL: the finally task notify still consumes a result ('$notify_params'); it is skipped whenever build does not run."
    exit 1 ;;
esac

echo "PASS: build uses the cluster resolver for ci-catalog, test fans out over image, deploy is guarded by branch in [main], notify uses no results."
exit 0
