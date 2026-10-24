# Section 020: Control Flow With When, Finally, Timeouts And Retries

A Pipeline that always runs every task in the same way is rarely what a team needs. A deploy should only happen from the main branch. A report should arrive even when the build fails. A flaky download should get a second try, a slow test should not block the run forever, and a known, harmless failure should not stop the release. Tekton gives the `Pipeline` a small set of fields for these decisions, and the `PipelineRun` records every decision it made.

This section teaches those fields. You first guard tasks with `when` expressions and read why Tekton skipped a task. Then you add `finally` tasks, which run after everything else, on success and on failure, and read the execution status of the other tasks. Last, you set timeouts on the whole run, on its tasks and on single tasks, retry a failing task, and let a task fail without failing the run with `onError`.

**Topic covered:** Control flow

## What you will learn

- `when` expressions: `input`, `operator` (`in`, `notin`) and `values`, with parameters and results, and the alpha CEL form behind the `enable-cel-in-whenexpression` flag.
- How a skipped task affects the tasks after it, and the `skippedTasks` list with its reasons.
- `finally` tasks, `$(tasks.status)`, `$(tasks.<task>.status)` and `$(tasks.<task>.reason)`, and why a `finally` task that consumes a missing result is skipped.
- `timeouts.pipeline`, `timeouts.tasks` and `timeouts.finally` on a `PipelineRun`, and `timeout` on one pipeline task.
- `retries`, `status.retriesStatus` and `$(context.task.retry-count)`, and `onError: continue` with the reason `FailureIgnored`.

## The learning path

The section has one module. It has a landing page, three short parts, a graded lab right after the part it tests, and a summary. The module also has its own playground, a cluster where you can explore freely, and the landing page starts it for you.

### 1. Control How A Pipeline Runs

The module starts at its landing page, which also launches the playground. The playground runs Tekton Pipelines v1.17.1, the `tkn` command-line tool and an empty namespace `starfleet`.

1. Guard Tasks With when Expressions
2. Run finally Tasks And Read Execution Status, followed by the lab **Guard A Deploy And Report With finally**
3. Timeouts, Retries And onError
4. Summary

## Section capstone: Make A Nightly Pipeline Reliable

The capstone is one graded scenario that combines the whole module. The `nightly` Pipeline of the `starfleet` team fails every night: a flaky task gets no second try, a test hits a timeout that is too short, a known failure of the documentation check stops the run, and the report task never arrives when the tests fail. Find each fault from the reasons of the TaskRuns, fix it, and prove that the report arrives with the right status on success and on failure. Work it after the module lab.

Start the capstone:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS126.git -c sections/section-020/capstone/labs/lab-01
```

When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-020/capstone/labs/lab-01
```

When the capstone is done, remove it:

```sh
astrona destroy ats-126-capstone-020
```
