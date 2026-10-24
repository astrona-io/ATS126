# Question

Solve this question on: `terminal`

**Time:** about 45 minutes · **Topic:** The CI pipeline

## Scenario

The CI Pipeline `bridge-ci` of the `starfleet` team clones `starfleet/bridge` from Gitea, runs ShellCheck, the unit tests on two images (`busybox:1.37.0` and `alpine:3.22.7`) and a secret scan in parallel, builds and pushes the image, deploys it, and reports every run from a `finally` task. The platform team keeps the one reviewed copy of the build Task, `build-image`, in the namespace `ci-catalog`. Since the last change, nothing works: both runs failed, and the team remembers that the deploy used to happen on the wrong branches and that failed builds were never reported.

## Your task

1. Find out why `bridge-ci-main` and `bridge-ci-feature` in `starfleet` failed. Each fix shows the next fault.
2. Fix every fault in the Pipeline `bridge-ci`. There are four.
3. Leave two runs that work: `bridge-ci-main` (`branch` = `main`) and `bridge-ci-feature` (`branch` = `feature/banner`), each with the ServiceAccount `ci-bot` and a `volumeClaimTemplate` for `source`, as before.

## Constraints

- Do not change the Tasks, and do not copy `build-image` into `starfleet`: `build` must keep using the cluster resolver.
- Keep the pipeline tasks, the graph (`lint`, `test`, `scan` in parallel after `clone`, `build` after all three) and the matrix over the two images.
- `deploy` must run only for `main`. `notify` must report every run, including runs where a check fails.

## Done when

- `build` uses the cluster resolver for `build-image` in `ci-catalog`, and there is no Task `build-image` in `starfleet`. The matrix of `test` passes `image` with both images, `deploy` has `input: $(params.branch)`, `operator: in`, `values: [main]`, and `notify` uses no task results.
- `bridge-ci-main` ended with the reason `Succeeded` and followed the graph; `deploy` ran after `build`, and `notify` ran in `finally`.
- The registry has the image `starfleet/bridge` tagged with the short head commit of `main`, and `bridge-release` records it with its digest and commit.
- `bridge-ci-feature` ended with the reason `Completed` with `deploy` skipped by its `when` expression; the notifications say `Succeeded`/`Succeeded` for main and `Completed`/`None` for the feature branch.
- A new run on the branch `broken` fails in `lint`, builds and deploys nothing, and its notification says `status` = `Failed` and `deploy` = `None`.
