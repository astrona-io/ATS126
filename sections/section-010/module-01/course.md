# Build A Task Graph With Pipelines

Your team has a Task that writes a release manifest and another that checks it. Each one works when you start it by hand, one after the other. Now the two must run together, every time, in the right order, with the same files and the same input values. Starting TaskRuns by hand does not scale, and it gives you no single record of what ran. This module shows how Tekton solves that with a `Pipeline`.

A `Pipeline` is a Kubernetes object that lists pipeline tasks. Each pipeline task names a `Task` and gives it parameters and workspaces. A `PipelineRun` is one execution of a `Pipeline`. When you create it, tekton-pipelines-controller works out the order of the tasks, creates one `TaskRun` for each of them at the right moment, and writes the outcome back to the `PipelineRun`.

Keep one sentence in mind: **a `PipelineRun` is a graph of TaskRuns.** Everything you know about TaskRuns (pods, step logs, results, the `Succeeded` condition) still applies. What the `Pipeline` adds is the graph: which task waits for which, which values travel between them, and which volume they share.

The module has three parts. **Pipelines, PipelineRuns And Workspaces** writes a two-task Pipeline and runs it with a shared volume. **Pass Results Between Tasks And Out Of The Pipeline** moves values from one task to the next and out of the Pipeline. **Order Tasks Into A Graph And Read The Run** builds a graph with parallel tasks and shows how to read a `PipelineRun` when the graph is wrong. A graded lab follows the third part.

## Learning objectives

After this module you can:

- Write a `Pipeline` with parameters, a workspace and pipeline tasks that pass both to their Tasks.
- Start a `PipelineRun` with `kubectl` and with `tkn`, and bind a workspace to a `volumeClaimTemplate`.
- Pass a result from one task to another with `$(tasks.<task>.results.<result>)`, and declare pipeline results.
- Order tasks with `runAfter` and with result references, and explain why a shared file alone does not order them.
- Read the `Succeeded` condition, `childReferences`, `skippedTasks` and the TaskRun times of a `PipelineRun`.

## Before you start

You need Kubernetes basics (namespaces, pods, PersistentVolumeClaims, `kubectl get`, `kubectl apply`, `kubectl logs`) and Tekton basics: a `Task` is a list of steps with parameters and results, a `TaskRun` is one execution of it, and Tekton runs each `TaskRun` as one pod with one container per step.

Your playground is a single-node `kind` cluster with these parts:

| Part of the playground | What it is |
| --- | --- |
| Namespace `tekton-pipelines` | Tekton Pipelines v1.17.1: the controller, the webhook and the events controller |
| Namespace `tekton-pipelines-resolvers` | The remote resolvers, which fetch Tasks and Pipelines from other places |
| Namespace `starfleet` | Empty. Your Tasks, Pipelines and runs go here |
| StorageClass `standard` | The `kind` local-path provisioner, which creates the volumes for workspaces |
| `tkn` on your PATH | The Tekton command-line tool, version 0.46.2 |

Every command in the parts runs against the playground cluster, and `kubectl` already points at it.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
