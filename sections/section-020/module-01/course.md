# Control How A Pipeline Runs

Last week a feature branch of the `starfleet` team went all the way to production, because the Pipeline deploys on every run. The week before, a build failed and nobody heard about it, because the notification task sat after the build and never started. Both problems have the same root: the Pipeline runs every task, every time, and stops at the first failure. This module shows how to change that.

Tekton gives a `Pipeline` four kinds of control. A `when` expression decides before a task starts whether it runs at all. A `finally` task runs after all other tasks have finished, whatever their outcome. Timeouts limit how long the run and its tasks may take. `retries` and `onError` decide what a failed task means for the run. The tekton-pipelines-controller applies all four, and it writes each decision into the status of the `PipelineRun`.

Keep one sentence in mind: **every task in a PipelineRun either ran or was skipped, and the status says why.** A TaskRun that exists has a reason such as `Succeeded`, `Failed`, `TaskRunTimeout` or `FailureIgnored`. A task that never ran is in `status.skippedTasks` with a reason such as `When Expressions evaluated to false` or `PipelineRun was stopping`.

The module has three parts. **Guard Tasks With when Expressions** skips a deploy on branches other than `main` and shows what happens to the tasks after it. **Run finally Tasks And Read Execution Status** adds a report that runs on success and on failure. A graded lab follows the second part. **Timeouts, Retries And onError** limits time and handles failures, and the section capstone grades it.

## Learning objectives

After this module you can:

- Guard a pipeline task with a `when` expression on a parameter or a result, and use CEL after you switch on its feature flag.
- Read `status.skippedTasks` and explain which tasks still run after a skipped task.
- Add `finally` tasks and pass them `$(tasks.status)`, `$(tasks.<task>.status)` and `$(tasks.<task>.reason)`.
- Explain why a `finally` task that uses a result of a failed or skipped task is skipped.
- Set `timeouts` on a `PipelineRun` and `timeout` on a pipeline task, and read the reason `TaskRunTimeout`.
- Retry a task with `retries`, read `status.retriesStatus`, and ignore a failure with `onError: continue`.

## Before you start

You need to know how a `Pipeline` passes parameters, workspaces and results to its pipeline tasks, how a `PipelineRun` starts it, and how to list the TaskRuns of a run with the label `tekton.dev/pipelineRun`.

Your playground is a single-node `kind` cluster with these parts:

| Part of the playground | What it is |
| --- | --- |
| Namespace `tekton-pipelines` | Tekton Pipelines v1.17.1: the controller, the webhook, the events controller, and the ConfigMap `feature-flags` |
| Namespace `tekton-pipelines-resolvers` | The remote resolvers |
| Namespace `starfleet` | Empty. Your Tasks, Pipelines and runs go here |
| `tkn` on your PATH | The Tekton command-line tool, version 0.46.2 |

Every command in the parts runs against the playground cluster, and `kubectl` already points at it.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
