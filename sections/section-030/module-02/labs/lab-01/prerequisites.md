# Prerequisites

Before starting this lab you should be able to:

- Write a `taskRef` and a `pipelineRef` that use the `cluster` resolver, with `kind`, `name` and `namespace`.
- Read the reason and message of the `Succeeded` condition of a `PipelineRun`.
- Explain in which namespace a resolved definition runs.

## What the environment gives you

The lab environment builds itself before the task begins:

- A single-node `kind` Kubernetes cluster, with `kubectl` already pointed at it.
- **Tekton Pipelines v1.17.1** in the namespaces `tekton-pipelines` and `tekton-pipelines-resolvers`.
- The `tkn` command-line tool, version **0.46.2**, on your PATH. You can solve the lab with `kubectl` alone.
- The shared namespace `ci-catalog` with the Task `announce` and the Pipeline `release-flow`.
- The Pipeline `flow` in the namespace `starfleet`, which fetches `announce` from the catalog.

## Working rules

- Everything is graded on the **final cluster state**. Leave the Pipeline and the PipelineRuns in place.
- The grader runs `flow` once more with its own message, so the fix must be in the Pipeline.
