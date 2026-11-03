# Overview: Defaults, Service Accounts And Resources (Playground)

This is a **playground**, not a lab. It starts a fresh cluster, installs Tekton Pipelines and the `tkn` command-line tool, and gives you an empty namespace for your own Tasks and Pipelines. There is no task, no `astrona submit` and no pass or fail. Explore, break things, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster. `kubectl` is already pointed at it.
- **Tekton Pipelines v1.17.1**, installed from its release manifest. The ConfigMap `feature-flags` in `tekton-pipelines` has its default values; `enable-cel-in-whenexpression` is `"false"` until you change it.

  | Deployment | Namespace | What it does |
  | --- | --- | --- |
  | `tekton-pipelines-controller` | `tekton-pipelines` | Runs PipelineRuns and TaskRuns, evaluates `when`, starts `finally`, applies retries and timeouts |
  | `tekton-pipelines-webhook` | `tekton-pipelines` | Sets defaults on and validates Tekton objects, for example CEL expressions and `retries` with `onError` |
  | `tekton-events-controller` | `tekton-pipelines` | Sends CloudEvents about runs, when a sink is configured |
  | `tekton-pipelines-remote-resolvers` | `tekton-pipelines-resolvers` | Fetches Tasks and Pipelines from other places |

- The Tekton command-line tool `tkn`, version **0.46.2**, on your PATH.
- An empty namespace `starfleet` for your Tasks, Pipelines and runs.
- The image `busybox:1.37.0`, already loaded on the node, for your steps.

## Helpers

Paste these once in each new terminal. `show_status` prints the condition of one `PipelineRun`. `show_taskruns` lists its TaskRuns with their reason and service account.

```sh
show_status() {
  kubectl get pipelinerun "$1" -n starfleet -o jsonpath='{.status.conditions[0].status} {.status.conditions[0].reason}: {.status.conditions[0].message}{"\n"}'
}
show_taskruns() {
  kubectl get taskruns -n starfleet -l "tekton.dev/pipelineRun=$1" \
    -o custom-columns='TASK:.metadata.labels.tekton\.dev/pipelineTask,REASON:.status.conditions[0].reason,SA:.spec.serviceAccountName'
}
```

Use them like this: `show_status <run>`, `show_taskruns <run>`.

## Practice tasks

- Read the ConfigMap `config-defaults` in `tekton-pipelines` and write down the value of `default-timeout-minutes`.
- Create a ServiceAccount and run a Pipeline with `taskRunTemplate.serviceAccountName`. Read the account from the pod.
- Give one pipeline task more memory than the others with `taskRunSpecs` and `computeResources`, and read the result in its TaskRun.
- Reference a Task that does not exist and read the reason of the PipelineRun.
- Create a ResourceQuota with `pods: "1"`, run two parallel tasks and watch the reason `ExceededResourceQuota`.
