# Prerequisites

Before starting this lab you should be able to:

- Read a `Pipeline`: its `params`, `workspaces`, `tasks` and `results`, and how a pipeline task passes them to a Task.
- Read the `Succeeded` condition of a `PipelineRun` and list its TaskRuns with the label `tekton.dev/pipelineRun`.
- Explain the two ways to order pipeline tasks: `runAfter` and result references.

## What the environment gives you

The lab environment builds itself before the task begins:

- A single-node `kind` Kubernetes cluster, with `kubectl` already pointed at it.
- **Tekton Pipelines v1.17.1** in the namespaces `tekton-pipelines` and `tekton-pipelines-resolvers`.
- The `tkn` command-line tool, version **0.46.2**, on your PATH. You can solve the lab with `kubectl` alone.
- The Tasks `write-manifest`, `count-crew` and `report`, the Pipeline `launch-check` and the failed PipelineRun `launch-check-run` in the namespace `starfleet`.

## Working rules

- Everything is graded on the **final cluster state**. Leave the Pipeline and the PipelineRun in place.
- The grader runs the Pipeline once more with its own values, so the Pipeline must work for any crew list, not only for the one in `launch-check-run`.
