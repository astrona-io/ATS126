# Question

Solve this question on: `terminal`

**Time:** about 45 minutes · **Topic:** The CI pipeline

## Scenario

The `starfleet` team keeps its `bridge` application in the Gitea repository `starfleet/bridge`. Its CI Pipeline `bridge-ci` was started but only clones the code and runs ShellCheck. The Tasks for the rest are ready in `starfleet`. The team wants the full CI pipeline today: tests on two shells, a secret scan, an image in the registry, a deploy only from `main`, and a notification for every run, especially the failed ones.

## Your task

1. Complete the Pipeline `bridge-ci` in `starfleet`. Keep its parameters, its workspace `source` and the pipeline tasks `clone` and `lint`, and add:
   - `test`: the Task `unit-test`, after `clone`, fanned out with a `matrix` over the parameter `image` with the values `busybox:1.37.0` and `alpine:3.22.7`;
   - `scan`: the Task `secret-scan`, after `clone`;
   - `build`: the Task `build-image`, after `lint`, `test` and `scan`, with `image` = the Pipeline parameter `image` and `tag` = the result `short-commit` of `clone`;
   - `deploy`: the Task `deploy`, with the results `IMAGE_URL` and `IMAGE_DIGEST` of `build` and the result `commit` of `clone`, guarded so that it runs only when the parameter `branch` is `main`;
   - `notify`: the Task `notify` as a `finally` task, with `pipelinerun` = the name of the run, `branch` = the parameter `branch`, `status` = the aggregate status of all tasks, and `deploy-status` = the execution status of `deploy`.
2. Run it twice and leave both runs in place: `bridge-ci-main` with `branch` = `main`, and `bridge-ci-feature` with `branch` = `feature/banner`. Both use `pipelineRef` `bridge-ci`, the ServiceAccount `ci-bot` through `taskRunTemplate`, and a `volumeClaimTemplate` for the workspace `source`.

## Constraints

- Do not change the Tasks, the ServiceAccount or its Role.
- `lint`, `test` and `scan` must run in parallel after `clone`; do not chain them.
- `notify` must not use any result of another task, so that it also runs when a check fails.
- Do not push images or write ConfigMaps by hand; the Pipeline does both.

## Done when

- `bridge-ci-main` ended `Succeeded` with the reason `Succeeded`; `lint`, both `test` TaskRuns (`busybox:1.37.0` and `alpine:3.22.7`) and `scan` started after `clone` finished; `build` started after all of them finished; `deploy` ran after `build`; `notify` ran as a `finally` task.
- The registry has the tag `<first 7 characters of the head commit of main>` for `starfleet/bridge`, and the ConfigMap `bridge-release` records that image, its `sha256:` digest and the full commit.
- `bridge-ci-feature` ended with the reason `Completed`: `build` succeeded and `deploy` was skipped with `When Expressions evaluated to false`.
- The ConfigMap `ci-notification-bridge-ci-main` has `status` = `Succeeded` and `deploy` = `Succeeded`; `ci-notification-bridge-ci-feature` has `status` = `Completed` and `deploy` = `None`.
- A new run on the branch `broken` fails in `lint`, has no `build` or `deploy` TaskRun, and its notification says `status` = `Failed` and `deploy` = `None`.
