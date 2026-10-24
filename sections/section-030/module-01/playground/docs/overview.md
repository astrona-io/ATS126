# Overview: Fan Out And Build A CI Pipeline (Playground)

This is a **playground**, not a lab. It starts a fresh cluster with Tekton Pipelines, a Git server, a container registry and a set of CI Tasks, so you can build pipelines against a real repository. There is no task, no `astrona submit` and no pass or fail. Explore, break things, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster. `kubectl` is already pointed at it.
- **Tekton Pipelines v1.17.1** and the Tekton command-line tool `tkn`, version **0.46.2**.
- **Gitea**, a Git server, in the namespace `gitea`, at `http://gitea-http.gitea.svc.cluster.local:3000` inside the cluster. It has the user `starfleet` (password `starfleet-password`, lab only) and two public repositories:

  | Repository | What it holds |
  | --- | --- |
  | `starfleet/bridge` | A tiny shell application: `bridge.sh`, its tests `test.sh` and a `Dockerfile`. Branches `main`, `feature/banner` (adds `banner.txt`) and `broken` (adds `scripts/cleanup.sh`, which ShellCheck rejects) |
  | `starfleet/tekton-catalog` | One Task file, `tasks/say-hello.yaml`, for the Git resolver |

- A container **registry** in the namespace `registry`, at `registry.registry.svc.cluster.local:5000` inside the cluster, over plain HTTP (lab only).
- A `tester` pod in `gitea` with `curl`, for calls from inside the cluster.
- The ServiceAccount `ci-bot` in `starfleet`, which may create and update ConfigMaps there.
- These Tasks in `starfleet`:

  | Task | Image | What it does |
  | --- | --- | --- |
  | `git-clone` | `alpine/git:v2.49.1` | Clones one branch into the workspace `output`; results `commit`, `short-commit` |
  | `shellcheck` | `koalaman/shellcheck-alpine:v0.11.0` | Runs ShellCheck on every `.sh` file in the workspace `source` |
  | `unit-test` | from the parameter `image` | Runs `test.sh` with the shell of that image |
  | `secret-scan` | `busybox:1.37.0` | A stand-in scanner: fails on lines that assign a password, token or secret |
  | `build-image` | `ghcr.io/osscontainertools/kaniko:v1.28.5-debug` | Builds the `Dockerfile` with kaniko and pushes it; results `IMAGE_URL`, `IMAGE_DIGEST` |
  | `deploy` | `alpine/kubectl:1.34.2` | Records the release in the ConfigMap `bridge-release` |
  | `notify` | `alpine/kubectl:1.34.2` | Writes the outcome of a run to the ConfigMap `ci-notification-<run>` |

All images are already loaded on the node. The kaniko build pulls its base image `mirror.gcr.io/library/busybox:1.37.0` from the internet.

To browse Gitea from your machine, run `kubectl -n gitea port-forward svc/gitea-http 3300:3000` in a second terminal and open `http://localhost:3300`.

## Helpers

Paste these once in each new terminal. `show_graph` lists the TaskRuns of one `PipelineRun` in start order with their pipeline task, times and reason. `show_tags` lists the tags of the image `starfleet/bridge` in the registry. `show_notification` prints the ConfigMap that `notify` wrote for one run.

```sh
show_graph() {
  kubectl get taskruns -n starfleet -l "tekton.dev/pipelineRun=$1" --sort-by=.status.startTime \
    -o custom-columns='TASK:.metadata.labels.tekton\.dev/pipelineTask,START:.status.startTime,END:.status.completionTime,REASON:.status.conditions[0].reason'
}
show_tags() {
  kubectl get --raw /api/v1/namespaces/registry/services/registry:http/proxy/v2/starfleet/bridge/tags/list; echo
}
show_notification() {
  kubectl get configmap "ci-notification-$1" -n starfleet -o jsonpath='{.data}'; echo
}
```

Use them like this: `show_graph <run>`, `show_tags`, `show_notification <run>`.

## Practice tasks

- Add a third image to the matrix of the unit tests and check that `$(tasks.test.matrix.length)` changes.
- Commit a line `password = hunter2` to a new branch through the Gitea web page and run the CI pipeline on it. Which task fails, and which tasks are skipped?
- Point a pipeline task at `say-hello` in `starfleet/tekton-catalog` with the Git resolver, change the file in Gitea, and run again. When does the new version arrive?
- Run the CI pipeline twice on `main`. Why is there still only one tag in the registry?
- Remove the Role binding of `ci-bot` and read why `notify` fails.
