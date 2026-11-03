# Prerequisites

Before starting this lab you should be able to:

- Declare string, array and object parameters, and pass them from a `Pipeline` to a `Task` with `$(params.name[*])`.
- Read the reason and message of the `Succeeded` condition of a `PipelineRun`.
- Explain what an optional workspace is and how a pipeline task passes a workspace to its Task.

## What the environment gives you

The lab environment builds itself before the task begins:

- A single-node `kind` Kubernetes cluster, with `kubectl` already pointed at it.
- **Tekton Pipelines v1.17.1** in the namespaces `tekton-pipelines` and `tekton-pipelines-resolvers`.
- The `tkn` command-line tool, version **0.46.2**, on your PATH. You can solve the lab with `kubectl` alone.
- The Task `write-notice`, the Pipeline `notice` and the failed PipelineRun `notice-run` in the namespace `starfleet`.

## Working rules

- Everything is graded on the **final cluster state**. Leave the Pipeline and the PipelineRun in place.
- The grader runs the Pipeline once more with its own values and a bound workspace, so the Pipeline must work for any list, any release and any title.
