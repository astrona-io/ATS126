# Summary

A Pipeline does not have to run every task every time, and it does not have to stop at the first failure without a word. A few fields on its pipeline tasks and on the `PipelineRun` decide what runs, what happens at the end, how long work may take and what a failure means. The tekton-pipelines-controller applies them, and the status of the `PipelineRun` records every decision.

## What you learned

A `when` expression guards one pipeline task. It compares an `input` (a parameter, a result or a constant) with a list of `values` using `in` or `notin`, and the task runs only when all its expressions are true. With the alpha flag `enable-cel-in-whenexpression` switched on in `feature-flags`, a `cel` string can express patterns and comparisons, with Tekton variables in single quotes. A skipped task goes into `status.skippedTasks` with the reason `When Expressions evaluated to false`. Tasks that only `runAfter` it still run, while tasks that need its results are skipped with `Results were missing`. A run with skipped tasks and no failure ends with the reason `Completed`.

`finally` tasks run together after every task under `tasks` has finished, on success and on failure. They can read execution status: `$(tasks.<task>.status)` (`Succeeded`, `Failed`, `None`), `$(tasks.<task>.reason)` and `$(tasks.status)` (`Succeeded`, `Failed`, `Completed`, `None`). They do not change the outcome: a failed task still fails the run. A `finally` task that consumes a result of a task that failed or was skipped is itself skipped, so a report that must always arrive takes only parameters and execution status.

`retries` gives a pipeline task extra attempts inside the same TaskRun; earlier attempts move to `status.retriesStatus`, new pods end in `-retry1`, and `$(context.task.retry-count)` tells a step of an embedded `taskSpec` which attempt it is (a Task used through `taskRef` always sees `0`). `onError: continue` lets a task fail with the reason `FailureIgnored` while the run goes on and can still succeed, and it cannot be combined with `retries`. `timeout` on a pipeline task ends a TaskRun with `TaskRunTimeout`, and `timeouts.pipeline`, `timeouts.tasks` and `timeouts.finally` on a `PipelineRun` limit the whole run, its tasks and its `finally` tasks. The key facts to remember are these:

- Skipped tasks and their reasons are in `status.skippedTasks`; a run with skipped tasks and no failure ends `Completed`.
- A `when` skip does not stop `runAfter` dependents; a missing result does.
- `finally` always runs, but a missing result can still skip a `finally` task.
- An ignored failure is still `Failed` in execution status.
- `timeouts.pipeline` must be at least `timeouts.tasks` plus `timeouts.finally`.

<!-- astrona:playground:destroy -->
