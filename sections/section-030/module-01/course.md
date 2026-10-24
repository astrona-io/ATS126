# Fan Out And Build A CI Pipeline

The `bridge` application of the `starfleet` team is small: one shell script, its tests and a Dockerfile in a Git repository. Still, the team wants what every project wants from continuous integration (CI): every push is checked, tested on more than one platform, scanned, built into an image and, on `main`, deployed, and somebody hears about every result. This module builds exactly that with Tekton, inside your own cluster.

Three new tools make it possible. A `matrix` turns one pipeline task into many TaskRuns, one per combination of parameter values. A resolver lets a pipeline task use a Task that is not stored in the namespace of the run, for example in a shared namespace or a Git repository. A custom task hands a pipeline task to a controller outside Tekton Pipelines. The tekton-pipelines-controller still builds the graph; these tools only change what a node of the graph is and where its Task comes from.

Keep one sentence in mind: **a CI pipeline is a graph of small Tasks, each doing one job.** The clone, the checks, the build and the deploy are separate Tasks with clear inputs and results. The `Pipeline` decides the order, the parallel branches, the guards and the `finally` work.

The module has three parts. **Fan Out A Task With A Matrix** runs one Task on several images and collects the results. **Custom Tasks And Remote Resolution** fetches Tasks from another namespace and from Git, and shows what a custom task does without its controller. **Design An End-To-End CI Pipeline** puts the CI Tasks of the playground into one Pipeline and runs it on two branches. A graded lab follows the third part.

## Learning objectives

After this module you can:

- Fan a pipeline task out with `matrix.params` and `matrix.include`, and read the TaskRuns it creates.
- Consume the results of a matrixed task as an array, and use `$(tasks.<task>.matrix.length)`.
- Explain what a custom task and a `CustomRun` are, and what happens when no controller handles them.
- Fetch a Task with the `cluster` resolver and the `git` resolver, and name the other built-in resolvers.
- Design a CI Pipeline with parallel checks, a guarded deploy and a `finally` notification, and build and push an image with kaniko.

## Before you start

You need to know how a `Pipeline` passes parameters, workspaces and results, how `runAfter` and result references order tasks, how a `when` expression skips a task, and how a `finally` task reads `$(tasks.status)` and `$(tasks.<task>.status)`.

Your playground is a single-node `kind` cluster with these parts:

| Part of the playground | What it is |
| --- | --- |
| Namespace `tekton-pipelines` and `tekton-pipelines-resolvers` | Tekton Pipelines v1.17.1 with its controller, webhook and resolvers |
| Namespace `gitea` | Gitea at `http://gitea-http.gitea.svc.cluster.local:3000`, with the public repositories `starfleet/bridge` and `starfleet/tekton-catalog`, and a `tester` pod |
| Namespace `registry` | A container registry at `registry.registry.svc.cluster.local:5000`, plain HTTP, lab only |
| Namespace `starfleet` | The CI Tasks `git-clone`, `shellcheck`, `unit-test`, `secret-scan`, `build-image`, `deploy`, `notify`, and the ServiceAccount `ci-bot` |
| `tkn` on your PATH | The Tekton command-line tool, version 0.46.2 |

Every command in the parts runs against the playground cluster, and `kubectl` already points at it. This playground needs more memory than the others: give your container engine at least 6 GB.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
