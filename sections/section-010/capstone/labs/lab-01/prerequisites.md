# Prerequisites

Before starting this capstone you should be able to:

- Read the `Succeeded` condition of a `PipelineRun`, its reason and its message.
- Bind a Pipeline workspace to a `volumeClaimTemplate` in a `PipelineRun`.
- Read the start and end times of the TaskRuns of a `PipelineRun` and tell which tasks ran in parallel.

## What the environment gives you

The capstone environment builds itself before the task begins:

- A single-node `kind` Kubernetes cluster, with `kubectl` already pointed at it.
- **Tekton Pipelines v1.17.1** and the `tkn` command-line tool, version **0.46.2**.
- The namespace `starfleet` with the Tasks `fetch-notes`, `lint-notes`, `spellcheck-notes` and `publish-notes`, the Pipeline `release-notes`, and the failed PipelineRun `release-notes-run`.

## Working rules

- Everything is graded on the **final cluster state**. Leave the Pipeline and the PipelineRun in place.
- Each fix shows the next fault. Expect to create the PipelineRun more than once.
