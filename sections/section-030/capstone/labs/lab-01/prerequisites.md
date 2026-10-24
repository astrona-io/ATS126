# Prerequisites

Before starting this capstone you should be able to:

- Read the condition, `skippedTasks` and child TaskRuns of a `PipelineRun`.
- Reference a Task through the `cluster` resolver, and fan a pipeline task out with a `matrix`.
- Write `when` expressions and `finally` tasks that run on every outcome.

## What the environment gives you

The capstone environment builds itself before the task begins:

- A single-node `kind` Kubernetes cluster, with `kubectl` already pointed at it.
- **Tekton Pipelines v1.17.1** and the `tkn` command-line tool, version **0.46.2**.
- Gitea with the public repository `starfleet/bridge` (branches `main`, `feature/banner`, `broken`) and a plain HTTP registry at `registry.registry.svc.cluster.local:5000` (lab only).
- In `starfleet`: the Tasks `git-clone`, `shellcheck`, `unit-test`, `secret-scan`, `deploy` and `notify`, the ServiceAccount `ci-bot`, the Pipeline `bridge-ci`, and the failed runs `bridge-ci-main` and `bridge-ci-feature`.
- In `ci-catalog`: the shared Task `build-image`.

## Working rules

- Everything is graded on the **final cluster state**. Leave the Pipeline, both runs and the ConfigMaps they wrote in place.
- Each fix shows the next fault. One run takes one to two minutes.
- Give your container engine at least 6 GB of memory.
