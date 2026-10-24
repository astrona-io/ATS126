# Question

Solve this question on: `terminal`

**Time:** about 25 minutes · **Topic:** Control flow

## Scenario

The `starfleet` team ships with the Pipeline `ship`: the pipeline task `build` builds an image name for a branch, and `deploy` deploys it. Yesterday the run `ship-feature-0` deployed the branch `feature/radar` to production, and when a build failed last week, nobody was told. The Task `notify` already exists, but the Pipeline never uses it.

## Your task

1. Change the Pipeline `ship` so that `deploy` runs only when the parameter `branch` is `main`. Use a `when` expression.
2. Add a `finally` task named `notify` that uses the Task `notify` and passes `branch` = the Pipeline parameter `branch`, `pipeline-status` = the aggregate status of all tasks, and `deploy-status` = the execution status of `deploy`.
3. Run the Pipeline twice and leave both runs in place: `ship-main` with `branch` = `main`, and `ship-feature` with `branch` = `feature/radar`.

## Constraints

- Do not change the Tasks. Keep the pipeline tasks `build` and `deploy` and the Pipeline parameters `branch` and `fail`.
- The guard on `deploy` is `input: $(params.branch)`, `operator: in`, `values: [main]`.
- `notify` must run on every run, also when `build` fails. It must not use any result of `build` or `deploy`.
- Both runs use `pipelineRef` name `ship`.

## Done when

- `deploy` has the `when` expression above, and `notify` is a `finally` task (not under `tasks`) that uses the Task `notify`.
- `ship-main` ended `Succeeded` with the reason `Succeeded`, `deploy` ran, and `notify` reported `branch=main pipeline=Succeeded deploy=Succeeded`.
- `ship-feature` ended `Succeeded` with the reason `Completed`, `deploy` is in `skippedTasks` with the reason `When Expressions evaluated to false`, and `notify` reported `branch=feature/radar pipeline=Completed deploy=None`.
- A new run with `branch` = `main` and `fail` = `true` fails, does not deploy, and `notify` reports `branch=main pipeline=Failed deploy=None`.
