# Prerequisites

Before starting this lab you should be able to:

- Write a `PipelineRun` that refers to a Pipeline with `pipelineRef`.
- Set `timeouts` on a `PipelineRun`.
- Explain what `taskRunTemplate` and `taskRunSpecs` do, and which one names a pipeline task.

## What the environment gives you

The lab environment builds itself before the task begins:

- A single-node `kind` Kubernetes cluster, with `kubectl` already pointed at it.
- **Tekton Pipelines v1.17.1** in the namespaces `tekton-pipelines` and `tekton-pipelines-resolvers`.
- The `tkn` command-line tool, version **0.46.2**, on your PATH. You can solve the lab with `kubectl` alone.
- The ServiceAccount `builder` and the Pipeline `render` in the namespace `starfleet`. The Pipeline has two tasks, `fetch` and then `build`, and no settings.

## Working rules

- Everything is graded on the **final cluster state**. Leave the PipelineRun in place.
- Do not change the Pipeline `render`. All settings belong to the run.
