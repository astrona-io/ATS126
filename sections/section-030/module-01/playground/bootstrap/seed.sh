#!/usr/bin/env bash
# Seeds the playground ats-126-playground-030-01 after Tekton is installed.
#
# Playground preparation only. There is no task and no grading. This script:
#   1. starts Gitea, the registry and the tester pod, and waits until they answer,
#   2. creates the Gitea user starfleet and the public repository
#      starfleet/bridge with the branches main, feature/banner and broken,
#   3. creates the public repository starfleet/tekton-catalog with one Task file,
#   4. applies the ServiceAccount ci-bot, its Role, and the CI Tasks in starfleet.
LOG="[playground]"
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFESTS="$SCRIPT_DIR/../manifests"
GIT_USER="starfleet"
GIT_PASSWORD="starfleet-password"
GITEA_URL="http://gitea-http.gitea:3000"

apply_with_retry() {
  # apply_with_retry ARGS...: kubectl apply, retried while the API server or
  # the Tekton webhook is still starting.
  local attempt
  for attempt in $(seq 1 30); do
    if kubectl apply "$@"; then
      return 0
    fi
    echo "$LOG kubectl apply failed (attempt $attempt), retrying in 5s..."
    sleep 5
  done
  echo "ERROR: kubectl apply $* kept failing." >&2
  return 1
}

echo "$LOG Applying Gitea, the registry and the tester pod..."
apply_with_retry -f "$MANIFESTS/lab-start.yaml"
kubectl -n gitea rollout status deployment/gitea --timeout=300s
kubectl -n gitea rollout status deployment/tester --timeout=300s
kubectl -n registry rollout status deployment/registry --timeout=300s

wait_for_gitea() {
  # Gitea is Ready a moment before its API answers; ask its health endpoint
  # from inside the cluster until it reports "pass".
  local answer
  for _ in $(seq 1 60); do
    answer="$(kubectl -n gitea exec deploy/tester -- curl -fsS "$GITEA_URL/api/healthz" 2>/dev/null || true)"
    case "$answer" in
      *'"status"'*pass*) echo "$LOG Gitea answers."; return 0 ;;
    esac
    sleep 3
  done
  echo "ERROR: Gitea did not report a healthy status within 3 minutes." >&2
  return 1
}

wait_for_registry() {
  # The registry answers GET /v2/ with 200 once it is ready.
  for _ in $(seq 1 60); do
    if kubectl get --raw /api/v1/namespaces/registry/services/registry:http/proxy/v2/ >/dev/null 2>&1; then
      echo "$LOG The registry answers."
      return 0
    fi
    sleep 3
  done
  echo "ERROR: the registry did not answer /v2/ within 3 minutes." >&2
  return 1
}

wait_for_gitea
wait_for_registry

gitea_api() {
  # gitea_api METHOD PATH [JSON]: calls the Gitea API from the tester pod.
  # The JSON body goes in as an argument, not through stdin, because
  # kubectl exec -i can drop the end of its input.
  local method="$1" path="$2" body="${3:-}"
  if [ -n "$body" ]; then
    kubectl -n gitea exec deploy/tester -- \
      curl -fsS -u "$GIT_USER:$GIT_PASSWORD" -X "$method" -H 'Content-Type: application/json' \
      --data "$body" "$GITEA_URL/api/v1$path"
  else
    kubectl -n gitea exec deploy/tester -- \
      curl -fsS -u "$GIT_USER:$GIT_PASSWORD" -X "$method" "$GITEA_URL/api/v1$path"
  fi
}

seed_file() {
  # seed_file REPO LOCAL_FILE REPO_PATH BRANCH [NEW_BRANCH]: commits one new
  # file. With NEW_BRANCH, Gitea creates that branch from BRANCH first.
  local repo="$1" local_file="$2" repo_path="$3" branch="$4" new_branch="${5:-}" content body attempt
  content="$(base64 < "$local_file" | tr -d '\n')"
  body="{\"content\":\"$content\",\"message\":\"Add $repo_path\",\"branch\":\"$branch\""
  [ -n "$new_branch" ] && body="$body,\"new_branch\":\"$new_branch\""
  body="$body}"
  for attempt in 1 2 3; do
    if gitea_api POST "/repos/$GIT_USER/$repo/contents/$repo_path" "$body" >/dev/null; then
      return 0
    fi
    echo "$LOG Committing $repo_path to $repo failed (attempt $attempt), retrying..."
    sleep 3
  done
  echo "ERROR: could not commit $repo_path to $GIT_USER/$repo." >&2
  return 1
}

create_repo() {
  # create_repo NAME: creates a public repository with a first commit on main.
  if ! gitea_api GET "/repos/$GIT_USER/$1" >/dev/null 2>&1; then
    gitea_api POST "/user/repos" "{\"name\":\"$1\",\"auto_init\":true,\"default_branch\":\"main\",\"private\":false}" >/dev/null
  fi
}

branch_exists() {
  # branch_exists REPO BRANCH: true when the branch is in the repository.
  local branches
  branches="$(gitea_api GET "/repos/$GIT_USER/$1/branches?limit=50" 2>/dev/null || true)"
  case "$branches" in
    *"\"name\":\"$2\""*) return 0 ;;
  esac
  return 1
}

echo "$LOG Creating the Gitea user $GIT_USER..."
gitea_user_ready=false
for _ in $(seq 1 30); do
  if kubectl -n gitea exec deploy/gitea -- gitea admin user create \
      --username "$GIT_USER" --password "$GIT_PASSWORD" --email starfleet@example.com \
      --admin --must-change-password=false >/dev/null 2>&1; then
    gitea_user_ready=true; break
  fi
  users="$(kubectl -n gitea exec deploy/gitea -- gitea admin user list 2>/dev/null || true)"
  if printf '%s\n' "$users" | awk 'NR > 1 {print $2}' | grep -x "$GIT_USER" >/dev/null; then
    gitea_user_ready=true; break
  fi
  sleep 2
done
[ "$gitea_user_ready" = true ] || { echo "ERROR: could not create the Gitea user $GIT_USER." >&2; exit 1; }

echo "$LOG Creating and seeding the repository $GIT_USER/bridge..."
create_repo bridge
if ! gitea_api GET "/repos/$GIT_USER/bridge/contents/bridge.sh" >/dev/null 2>&1; then
  for file in bridge.sh test.sh Dockerfile; do
    seed_file bridge "$MANIFESTS/gitea/bridge/$file" "$file" main
  done
fi
branch_exists bridge feature/banner || \
  seed_file bridge "$MANIFESTS/gitea/feature-banner/banner.txt" banner.txt main feature/banner
branch_exists bridge broken || \
  seed_file bridge "$MANIFESTS/gitea/broken/scripts/cleanup.sh" scripts/cleanup.sh main broken
for branch in main feature/banner broken; do
  branch_exists bridge "$branch" || { echo "ERROR: the branch $branch is missing in $GIT_USER/bridge." >&2; exit 1; }
done
echo "$LOG The repository $GIT_USER/bridge has the branches main, feature/banner and broken."

echo "$LOG Applying the ServiceAccount ci-bot and its Role..."
apply_with_retry -f "$MANIFESTS/ci-rbac.yaml"

echo "$LOG Creating and seeding the repository $GIT_USER/tekton-catalog..."
create_repo tekton-catalog
if ! gitea_api GET "/repos/$GIT_USER/tekton-catalog/contents/tasks/say-hello.yaml" >/dev/null 2>&1; then
  seed_file tekton-catalog "$MANIFESTS/gitea/tekton-catalog/tasks/say-hello.yaml" tasks/say-hello.yaml main
fi

echo "$LOG Applying the CI Tasks..."
apply_with_retry -f "$MANIFESTS/ci-tasks.yaml"

echo "$LOG Environment ready."
kubectl -n starfleet get tasks,serviceaccounts
echo "$LOG To browse Gitea, run in a second terminal:"
echo "  kubectl -n gitea port-forward svc/gitea-http 3300:3000"
