# Overview: Parameters, Variables And Workspaces In Depth (Playground)

This is a **playground**, not a lab. It starts a fresh cluster, installs Tekton Pipelines and the `tkn` command-line tool, and gives you an empty namespace for your own Tasks and Pipelines. There is no task, no `astrona submit` and no pass or fail. Explore, break things, `astrona destroy`, start over.

## What's in the box

- A single-node `kind` Kubernetes cluster. `kubectl` is already pointed at it. Its default StorageClass `standard` (the local-path provisioner) creates the volumes for `volumeClaimTemplate` workspaces.
- **Tekton Pipelines v1.17.1**, installed from its release manifest. Its Deployments are:

  | Deployment | Namespace | What it does |
  | --- | --- | --- |
  | `tekton-pipelines-controller` | `tekton-pipelines` | Turns each `PipelineRun` into TaskRuns and each `TaskRun` into a pod, and writes their status |
  | `tekton-pipelines-webhook` | `tekton-pipelines` | Sets defaults on and validates Tekton objects when they are created |
  | `tekton-events-controller` | `tekton-pipelines` | Sends CloudEvents about runs, when a sink is configured |
  | `tekton-pipelines-remote-resolvers` | `tekton-pipelines-resolvers` | Fetches Tasks and Pipelines from other namespaces, Git, bundles, hubs or URLs |

- The Tekton command-line tool `tkn`, version **0.46.2**, on your PATH.
- An empty namespace `starfleet` for your Tasks, Pipelines and runs.
- The image `busybox:1.37.0`, already loaded on the node, for your steps.

A `Pipeline` is a definition and never runs by itself. A `PipelineRun` is one execution of a `Pipeline`; the controller creates one `TaskRun` per pipeline task, in the order of the graph.

## Helpers

Paste these once in each new terminal. `show_graph` lists the TaskRuns of one `PipelineRun` in start order, with their pipeline task, start and end times and reason. `show_status` prints the condition, the pipeline results and the skipped tasks of one `PipelineRun`.

```sh
show_graph() {
  kubectl get taskruns -n starfleet -l "tekton.dev/pipelineRun=$1" --sort-by=.status.startTime \
    -o custom-columns='TASK:.metadata.labels.tekton\.dev/pipelineTask,START:.status.startTime,END:.status.completionTime,REASON:.status.conditions[0].reason'
}
show_status() {
  kubectl get pipelinerun "$1" -n starfleet -o jsonpath='{.status.conditions[0].status} {.status.conditions[0].reason}: {.status.conditions[0].message}{"\n"}results:{range .status.results[*]} {.name}={.value}{end}{"\n"}skipped:{range .status.skippedTasks[*]} {.name} ({.reason}){end}{"\n"}'
}
```

Use them like this: `show_graph greeting-1`, `show_status greeting-1`.

## Practice tasks

- Run a Pipeline with an array parameter and pass a plain string instead of a list. Read the reason of the `Succeeded` condition.
- Declare an object parameter with two keys and leave one key out of the `PipelineRun`. Which reason does the run show?
- Print `$(context.pipelineRun.uid)` from a Pipeline through a parameter and compare it with `kubectl get pipelinerun <RUN> -o jsonpath='{.metadata.uid}'`.
- Bind a workspace to a ConfigMap and try to write a file into it. Read the step log.
- Bind the same existing PersistentVolumeClaim in two runs and check what the second run finds.
- Mark a workspace optional in the Task but not in the Pipeline, and read the reason of a run that does not bind it.
