#!/usr/bin/env bash
# PASS when the image of the head commit of main is in the registry, tagged
# with the short commit, and the ConfigMap bridge-release records that image,
# its digest and the commit. A run that deployed a feature branch fails here.
set -uo pipefail

NS="starfleet"

wait_for_run() {
  # wait_for_run NAME: waits up to 6 minutes until the PipelineRun has ended,
  # then prints True or False (empty if it never ended).
  local status=""
  for _ in $(seq 1 120); do
    status="$(kubectl -n "$NS" get pipelinerun "$1" -o jsonpath='{.status.conditions[?(@.type=="Succeeded")].status}' 2>/dev/null)"
    if [ "$status" = "True" ] || [ "$status" = "False" ]; then
      break
    fi
    sleep 3
  done
  printf '%s' "$status"
}

run_field() {
  # run_field RUN JSONPATH: reads one field of a PipelineRun.
  kubectl -n "$NS" get pipelinerun "$1" -o jsonpath="$2" 2>/dev/null
}

taskrun_field() {
  # taskrun_field RUN PIPELINE_TASK JSONPATH: reads a field of the first TaskRun of a pipeline task.
  kubectl -n "$NS" get taskruns -l "tekton.dev/pipelineRun=$1,tekton.dev/pipelineTask=$2" -o jsonpath="{.items[0]$3}" 2>/dev/null
}

taskrun_list() {
  # taskrun_list RUN PIPELINE_TASK JSONPATH: prints a field of every TaskRun of a pipeline task, one per line.
  kubectl -n "$NS" get taskruns -l "tekton.dev/pipelineRun=$1,tekton.dev/pipelineTask=$2" -o jsonpath="{range .items[*]}$3{\"\n\"}{end}" 2>/dev/null
}

PR="bridge-ci-main"
REPOSITORY="registry.registry.svc.cluster.local:5000/starfleet/bridge"

branch_json="$(kubectl get --raw /api/v1/namespaces/gitea/services/gitea-http:http/proxy/api/v1/repos/starfleet/bridge/branches/main 2>/dev/null)"
head_commit="$(printf '%s' "$branch_json" | grep -o '"id":"[0-9a-f]\{40\}"' | head -n 1 | cut -d'"' -f4 || true)"
if [ -z "$head_commit" ]; then
  echo "FAIL: could not read the head commit of main from Gitea."
  exit 1
fi
short_commit="$(printf '%s' "$head_commit" | cut -c1-7)"

cloned="$(taskrun_field "$PR" clone '.status.results[?(@.name=="commit")].value')"
if [ "$cloned" != "$head_commit" ]; then
  echo "FAIL: $PR cloned '${cloned:-nothing}', but the head of main is $head_commit."
  exit 1
fi

tags="$(kubectl get --raw /api/v1/namespaces/registry/services/registry:http/proxy/v2/starfleet/bridge/tags/list 2>/dev/null)"
case "$tags" in
  *"\"$short_commit\""*) ;;
  *)
    echo "FAIL: the registry has no tag $short_commit for starfleet/bridge (tags: ${tags:-none})."
    exit 1 ;;
esac

image="$(kubectl -n "$NS" get configmap bridge-release -o jsonpath='{.data.image}' 2>/dev/null)"
digest="$(kubectl -n "$NS" get configmap bridge-release -o jsonpath='{.data.digest}' 2>/dev/null)"
commit="$(kubectl -n "$NS" get configmap bridge-release -o jsonpath='{.data.commit}' 2>/dev/null)"
if [ "$image" != "$REPOSITORY:$short_commit" ] || [ "$commit" != "$head_commit" ]; then
  echo "FAIL: bridge-release must record $REPOSITORY:$short_commit and commit $head_commit (found image '${image}', commit '${commit}')."
  exit 1
fi
case "$digest" in
  sha256:*) ;;
  *)
    echo "FAIL: bridge-release must record the image digest (found '${digest}')."
    exit 1 ;;
esac

echo "PASS: $REPOSITORY:$short_commit is in the registry and bridge-release records it with its digest."
exit 0
