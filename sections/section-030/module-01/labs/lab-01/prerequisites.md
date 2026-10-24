# Prerequisites

Before starting this lab you should be able to:

- Connect pipeline tasks with `runAfter` and result references, and share a workspace bound to a `volumeClaimTemplate`.
- Fan a pipeline task out with `matrix.params`.
- Guard a task with a `when` expression and add a `finally` task that reads `$(tasks.status)` and `$(tasks.<task>.status)`.

## What the environment gives you

The lab environment builds itself before the task begins:

- A single-node `kind` Kubernetes cluster, with `kubectl` already pointed at it.
- **Tekton Pipelines v1.17.1** and the `tkn` command-line tool, version **0.46.2**.
- Gitea in the namespace `gitea`, with the public repository `starfleet/bridge` (branches `main`, `feature/banner`, `broken`) at `http://gitea-http.gitea.svc.cluster.local:3000/starfleet/bridge.git`.
- A plain HTTP registry at `registry.registry.svc.cluster.local:5000` (lab only).
- In `starfleet`: the Tasks `git-clone`, `shellcheck`, `unit-test`, `secret-scan`, `build-image`, `deploy` and `notify`, the ServiceAccount `ci-bot`, and the Pipeline `bridge-ci`, which only clones and lints.

## Working rules

- Everything is graded on the **final cluster state**. Leave the Pipeline, both runs and the ConfigMaps they wrote in place.
- One run takes one to two minutes. The grader starts one more run, on the branch `broken`.
- Give your container engine at least 6 GB of memory.
