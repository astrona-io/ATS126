# Prerequisites

Before starting this lab you should be able to:

- Write a `when` expression with `input`, `operator` and `values`.
- Add a `finally` task to a `Pipeline` and pass it `$(tasks.status)` and `$(tasks.<task>.status)`.
- Read `status.skippedTasks` of a `PipelineRun` and the results of a TaskRun.

## What the environment gives you

The lab environment builds itself before the task begins:

- A single-node `kind` Kubernetes cluster, with `kubectl` already pointed at it.
- **Tekton Pipelines v1.17.1** and the `tkn` command-line tool, version **0.46.2**.
- The Tasks `build-app`, `deploy-app` and `notify`, the Pipeline `ship`, and the finished PipelineRun `ship-feature-0` in the namespace `starfleet`.

## Working rules

- Everything is graded on the **final cluster state**. Leave the Pipeline and your two PipelineRuns in place.
- The grader runs the Pipeline once more with a build that fails on purpose, so the report must arrive on failure too.
