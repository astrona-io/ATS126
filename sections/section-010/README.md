# Section 010: Pipelines And The Task Graph

A real continuous integration and delivery (CI/CD) process is never one Task. It fetches code, checks it, tests it, builds it and publishes it, and some of those steps must wait for others while some can run at the same time. Tekton describes such a process with a `Pipeline`: a set of Tasks, the values they pass to each other, the volumes they share, and the order in which they run. Once you can read and write that structure, every later topic builds on it: conditions, `finally` tasks, matrix fan-out and a full CI pipeline.

This section shows that structure at work. You first write a `Pipeline` from two Tasks and run it with a `PipelineRun` that binds a shared workspace. Then you pass results from one task to the next and publish a result of the whole Pipeline. Last, you build a graph where some tasks run in parallel and others wait, and you learn to read a `PipelineRun`: its condition, its child TaskRuns with their start and end times, and the reasons Tekton gives when the graph is wrong.

**Topic covered:** Pipelines

## What you will learn

- The fields of a `Pipeline`: `params`, `workspaces`, `tasks`, `results`, and how a pipeline task passes parameters and workspaces to its Task.
- The fields of a `PipelineRun`: `pipelineRef`, `params`, `workspaces` with a `volumeClaimTemplate`, and `taskRunTemplate`.
- Passing a result with `$(tasks.<task>.results.<result>)`, and pipeline results in `status.results`.
- How Tekton builds a directed acyclic graph (DAG) from `runAfter` and result references, and why a shared file does not order two tasks.
- Reading a `PipelineRun`: the `Succeeded` condition and its reasons, `childReferences`, `skippedTasks`, and the times of each TaskRun.

## The learning path

The section has one module. It has a landing page, three short parts, a graded lab right after the part it tests, and a summary. The module also has its own playground, a cluster where you can explore freely, and the landing page starts it for you.

### 1. Build A Task Graph With Pipelines

The module starts at its landing page, which also launches the playground. The playground runs Tekton Pipelines v1.17.1, the `tkn` command-line tool and an empty namespace `starfleet` for your Tasks and Pipelines.

1. Pipelines, PipelineRuns And Workspaces
2. Pass Results Between Tasks And Out Of The Pipeline
3. Order Tasks Into A Graph And Read The Run, followed by the lab **Fix The Task Graph Of A Pipeline**
4. Summary

## Section capstone: Repair A Release Notes Pipeline

The capstone is one graded scenario that combines the whole module. The `release-notes` Pipeline of the `starfleet` team never produced its notice: its PipelineRun binds the wrong workspace, the Pipeline never passes a parameter that a Task needs, and two checks that should run side by side wait for each other. Find each fault from the PipelineRun status, fix it, and prove the fix with a PipelineRun whose two checks overlap in time. Work it after the module lab.

Start the capstone:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS126.git -c sections/section-010/capstone/labs/lab-01
```

When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-010/capstone/labs/lab-01
```

When the capstone is done, remove it:

```sh
astrona destroy ats-126-capstone-010
```
