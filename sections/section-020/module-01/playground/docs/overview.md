# Overview: Control How A Pipeline Runs (Playground)

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

Paste these once in each new terminal. `show_status` prints the condition, the skipped tasks with their reasons and the `finallyStartTime` of one `PipelineRun`. `show_taskruns` lists its TaskRuns with their list (`tasks` or `finally`), reason and number of retries.

```sh
show_status() {
  kubectl get pipelinerun "$1" -n starfleet -o jsonpath='{.status.conditions[0].status} {.status.conditions[0].reason}: {.status.conditions[0].message}{"\n"}skipped:{range .status.skippedTasks[*]} {.name} ({.reason}){end}{"\n"}finally started: {.status.finallyStartTime}{"\n"}'
}
show_taskruns() {
  kubectl get taskruns -n starfleet -l "tekton.dev/pipelineRun=$1" \
    -o custom-columns='TASK:.metadata.labels.tekton\.dev/pipelineTask,LIST:.metadata.labels.tekton\.dev/memberOf,REASON:.status.conditions[0].reason,RETRIES:.spec.retries'
}
```

Use them like this: `show_status <run>`, `show_taskruns <run>`.

## Practice tasks

- Guard one task with two `when` expressions, one `in` and one `notin`, and find the input values for which it runs.
- Write a `when` expression that uses a result of an earlier task, and check with the TaskRun times that the guarded task waited for it.
- Add a `finally` task guarded by `when` with `input: $(tasks.build.status)`, `operator: in`, `values: ["Failed"]`, so it only runs after a failed build.
- Set `retries: 1` on a task that always fails and count its pods.
- Set `timeouts.pipeline: 30s` on a run whose task sleeps for a minute, and compare its reason with that of a task-level `timeout`.
- Try to apply a Pipeline with `retries: 1` and `onError: continue` on the same task, and read the webhook's error.
