# Prerequisites

Before starting this capstone you should be able to:

- Read the reasons of the TaskRuns of a `PipelineRun`, including `TaskRunTimeout`, `FailureIgnored` and `ToBeRetried`, and its `skippedTasks`.
- Set `retries`, `timeout` and `onError` on a pipeline task.
- Pass execution status to a `finally` task.

## What the environment gives you

The capstone environment builds itself before the task begins:

- A single-node `kind` Kubernetes cluster, with `kubectl` already pointed at it.
- **Tekton Pipelines v1.17.1** and the `tkn` command-line tool, version **0.46.2**.
- The namespace `starfleet` with the Tasks `warm-cache`, `integration`, `docs-check` and `report`, the Pipeline `nightly`, and the failed PipelineRun `nightly-run`.

## Working rules

- Everything is graded on the **final cluster state**. Leave the Pipeline and the PipelineRun in place.
- Each fix shows the next fault. Expect to create the PipelineRun more than once; one run takes about a minute.
