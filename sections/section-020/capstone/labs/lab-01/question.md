# Question

Solve this question on: `terminal`

**Time:** about 35 minutes · **Topic:** Control flow

## Scenario

Every night the `starfleet` team runs the Pipeline `nightly`. `warm-cache` fills a cache from a mirror that only answers on the second request, `integration` runs about 20 seconds of tests, and `docs-check` checks links in the documentation. One external link is broken; the team knows it and has decided that it must not stop the nightly run. The `finally` task `report` tells the team how `integration` and `docs-check` ended. The run `nightly-run` has failed every night, and on the nights when the tests failed, no report arrived at all.

## Your task

1. Find out why `nightly-run` in the namespace `starfleet` fails, from the reasons of its TaskRuns and its skipped tasks. Each fix shows the next fault.
2. Fix every fault in the Pipeline `nightly`. There are four, one per pipeline task.
3. Leave a PipelineRun named `nightly-run` that succeeds and whose `report` says `integration=Succeeded docs=Failed`.

## Constraints

- Do not change the four Tasks.
- `warm-cache` gets `retries` of 1 or 2; do not make it pass by any other means.
- `integration` keeps a `timeout`, between `1m` and `5m`.
- `docs-check` must keep failing but must not fail the run: use `onError: continue`, not `retries`.
- `report` stays a `finally` task using the Task `report`. Its parameter `integration` is the execution status of `integration`, and `docs` is the execution status of `docs-check`. It must not use any result.
- `nightly-run` uses `pipelineRef` name `nightly` and no parameters.

## Done when

- The Pipeline `nightly` has `retries` 1 or 2 on `warm-cache`, a `timeout` from `1m` to `5m` on `integration`, `onError: continue` and no `retries` on `docs-check`, and `report` under `finally` with no result references.
- `nightly-run` succeeded; its TaskRun of `warm-cache` succeeded after at least one earlier attempt in `status.retriesStatus`; `integration` succeeded; `docs-check` ended with the reason `FailureIgnored`; and `report` said `integration=Succeeded docs=Failed`.
- A new run with `break` = `true` fails in `integration`, and `report` still runs and says `integration=Failed docs=Failed`.
