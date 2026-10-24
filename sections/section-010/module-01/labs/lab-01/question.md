# Question

Solve this question on: `terminal`

**Time:** about 25 minutes · **Topic:** Pipelines

## Scenario

Before every launch, the `starfleet` team runs the Pipeline `launch-check`. Its pipeline task `write` writes the crew manifest into a shared workspace and publishes a manifest identifier, `count` counts the crew in that manifest, and `report` combines both into the pipeline result `summary`. Today the PipelineRun `launch-check-run` for release `r42` failed, and the team does not know where to start.

## Your task

1. Find out why the PipelineRun `launch-check-run` in the namespace `starfleet` failed. Read its `Succeeded` condition first, then its TaskRuns if there are any.
2. Fix every fault you find in the Pipeline `launch-check`. There is more than one.
3. Leave a PipelineRun named `launch-check-run`, with the same parameters and workspace as before, that succeeds and reports the pipeline result `summary` as `r42-manifest: 3 crew ready`.

## Constraints

- Do not change the Tasks `write-manifest`, `count-crew` and `report`.
- Keep the three pipeline tasks `write`, `count` and `report` in the Pipeline. `count` must still read the manifest from the workspace.
- `launch-check-run` must refer to the Pipeline with `pipelineRef`; do not embed it with `pipelineSpec`.

## Done when

- The PipelineRun `launch-check-run` in `starfleet` uses the Pipeline `launch-check`, passes `release` = `r42`, its `Succeeded` condition is `True`, and its pipeline result `summary` is `r42-manifest: 3 crew ready`.
- In that run, the TaskRun of `count` started only after the TaskRun of `write` had finished, the pipeline task `count` declares `runAfter: [write]`, and `report` started after both.
- A new PipelineRun of `launch-check` with `crew` = `probe shuttle scout bridge` and `release` = `r7` succeeds with `summary` = `r7-manifest: 4 crew ready`.
