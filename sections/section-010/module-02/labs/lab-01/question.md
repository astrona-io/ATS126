# Question

Solve this question on: `terminal`

**Time:** about 25 minutes · **Topic:** Pipelines

## Scenario

The `starfleet` team sends a notice before every release. The Task `write-notice` builds one line from a title, a list of crew names and the release name and deck, and it can also save the line in an optional workspace named `outbox`. The Pipeline `notice` wraps the Task and publishes the line and the state of the outbox as pipeline results. Today the PipelineRun `notice-run` failed, and the notice was never written.

## Your task

1. Find out why the PipelineRun `notice-run` in the namespace `starfleet` failed. Read its `Succeeded` condition first.
2. Fix every fault you find in the Pipeline `notice`. There is more than one, and the second one shows only when a run binds the workspace `outbox`.
3. Leave a PipelineRun named `notice-run`, with the same parameters as before, that succeeds and reports the pipeline result `line` as `Notice: bridge / r9 deck 3 (3 crew)`.

## Constraints

- Do not change the Task `write-notice`.
- The workspace `outbox` of the Pipeline must stay optional.
- `notice-run` must refer to the Pipeline with `pipelineRef`; do not embed it with `pipelineSpec`.

## Done when

- The PipelineRun `notice-run` uses the Pipeline `notice`, its `Succeeded` condition is `True`, and the pipeline result `line` is `Notice: bridge / r9 deck 3 (3 crew)`.
- The Pipeline declares `crew` as an array, keeps `outbox` optional, and the pipeline task `write` passes `outbox` to the Task.
- A new PipelineRun of `notice` with the title `Alert`, the crew `a` and `b`, the release `r1` on deck `5`, and the workspace `outbox` bound to an `emptyDir`, succeeds with `line` = `Alert: a / r1 deck 5 (2 crew)` and `outbox` = `bound`.
