# Summary

A `Pipeline` turns a set of Tasks into one repeatable job. It says which Tasks run, which values and volumes they share, and in which order they run. A `PipelineRun` is one execution of that job, and the TaskRuns it creates are the record of what really happened.

## What you learned

A `Pipeline` declares `params`, `workspaces`, `tasks` and `results`. Each pipeline task has its own name in the graph, a `taskRef` or an embedded `taskSpec`, and `params` and `workspaces` that map the Pipeline's values to the names the Task uses. A `PipelineRun` refers to the Pipeline with `pipelineRef`, gives the parameter values, and binds every workspace to a real volume. A `volumeClaimTemplate` creates a new PersistentVolumeClaim for each run, owned by the `PipelineRun`, so files written by one TaskRun's pod are there for the next. `tkn pipeline start` builds such a `PipelineRun` from `-p` and `-w` flags.

Results carry small values between tasks. A step writes to `$(results.<name>.path)`, and another pipeline task reads `$(tasks.<pipeline task>.results.<name>)`. A Pipeline can declare its own results from task results, and the controller writes them to `status.results` of the `PipelineRun` in `tekton.dev/v1`. A result that a Task does not declare fails the run with `InvalidTaskResultReference` before any TaskRun exists.

The controller builds a directed acyclic graph from two kinds of edges: `runAfter` for an order without data, and result references for an order with data. A shared workspace is not an edge, so a reader and a writer of the same file need one of the two. Tasks without edges between them run in parallel. The proof of the order is in the TaskRuns: their labels `tekton.dev/pipelineRun` and `tekton.dev/pipelineTask`, and their `status.startTime` and `status.completionTime`. The key facts to remember are these:

- A `PipelineRun` is a graph of TaskRuns, named `<pipelinerun>-<pipeline task>`.
- An edge comes only from `runAfter` or from a result reference.
- A failed task stops the run: running tasks finish, tasks not yet started are skipped with `PipelineRun was stopping`.
- Reasons such as `InvalidWorkspaceBindings`, `PipelineValidationFailed` and `InvalidTaskResultReference` come before any TaskRun; read the condition message.

<!-- astrona:playground:destroy -->
