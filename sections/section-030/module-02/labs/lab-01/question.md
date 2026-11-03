# Question

Solve this question on: `terminal`

**Time:** about 25 minutes · **Topic:** Remote resolution

## Scenario

A platform team keeps its reviewed Task `announce` and its Pipeline `release-flow` in the namespace `ci-catalog`. The `starfleet` team uses them without copying them. The Pipeline `flow` in the namespace `starfleet` was written to fetch `announce` with the `cluster` resolver, but nobody has run it yet, and the team also wants to run the whole `release-flow` for production.

## Your task

1. Find out why a run of the Pipeline `flow` cannot get its Task, and fix the Pipeline `flow`.
2. Create a PipelineRun named `flow-run` that uses the Pipeline `flow` with the parameter `message` set to `ready`. Wait until it succeeds.
3. Create a PipelineRun named `release-run` in the namespace `starfleet` that fetches the Pipeline `release-flow` from the namespace `ci-catalog` with the `cluster` resolver, sets the parameter `target` to `prod`, and wait until it succeeds.

## Constraints

- Do not change anything in the namespace `ci-catalog`.
- Do not copy `announce` or `release-flow` into `starfleet`.
- `flow` must keep using the `cluster` resolver.
- `release-run` must use `pipelineRef` with a resolver; do not embed the Pipeline.

## Done when

- The Pipeline `flow` asks for the Task `announce` of kind `task` in the namespace `ci-catalog`.
- `flow-run` succeeded and its pipeline result `line` is `announce: ready`.
- `release-run` succeeded and its pipeline result `summary` is `deploy prod`.
- A new run of `flow` with another message also succeeds.
