# What A Custom Task Controller Must Do

The earlier part showed that a `CustomRun` stays empty when nothing watches it. This part lists what a controller has to do so that a custom task behaves like a Task. You do not need to write one for the exercises, but you need to know the contract in order to judge a custom task from a project, and to explain why one does not work.

## The object a controller receives

For every pipeline task with a `taskRef` that has an `apiVersion` and a `kind`, Tekton Pipelines creates a `CustomRun` in the namespace of the `PipelineRun`. The `CustomRun` has these fields that matter to a controller:

- `spec.customRef` holds the `apiVersion` and the `kind` that the pipeline task named. A controller acts only on the kinds it owns and ignores the rest.
- `spec.params` holds the parameters of the pipeline task.
- `spec.workspaces` holds the workspace bindings.
- `spec.timeout` and `spec.retries` hold the values of the pipeline task. They are the controller's duty to honor. Tekton Pipelines does not stop the work for it.
- `spec.serviceAccountName` names the service account of the run.

Read these from a run in the playground, using the `CustomRun` that the earlier part created:

```sh
kubectl get customrun wait-1-approval -n starfleet -o yaml
```

If you removed it, apply `pipelinerun-wait.yaml` again first.

## What a controller writes back

A controller reports through the `status` of the `CustomRun`:

- A condition of type `Succeeded`. The status `Unknown` means running, `True` means success and `False` means failure. Without this condition the pipeline task never ends.
- `status.startTime` and `status.completionTime`. The completion time is set when the work ends.
- `status.results`, a list of name and value pairs. The pipeline reads them like Task results with `$(tasks.<task>.results.<name>)`.
- `status.retriesStatus` when the controller retries.

The controller must also react when `spec.status` is set to `CustomRunCancelled`. Tekton sets this when a run is cancelled or times out, and the controller must stop its work and report a final condition.

## Choosing between a custom task and a Task

A custom task fits work that does not need a pod in the cluster: waiting for an approval, calling an external service and polling its result, or running a loop that decides its own length. It adds a controller to operate, a second API to learn, and a failure mode that Tekton cannot show: a `CustomRun` with no condition. A Task is simpler in every other case, because Tekton Pipelines runs it, times it out and cancels it. Prefer a Task unless the work cannot be a pod.

## Reading a stuck custom task

When a run with a custom task does not end, check in this order:

1. List the `CustomRun` objects of the run and read their conditions.
2. If there is no condition, find out whether a controller for the `apiVersion` and `kind` is installed and running.
3. If the controller runs, read its logs for the name of the `CustomRun`.
4. If the `CustomRun` has a condition but the graph does not move, read `status.results` for the names the pipeline expects.

```sh
kubectl get customruns -n starfleet
kubectl get customrun <NAME> -n starfleet -o jsonpath='{.status.conditions}{"\n"}'
```

You can now explain what a controller receives and must return, and decide when a custom task is the right choice. Together with the matrix, the resolvers and the credentials, this completes the set of building blocks for a CI pipeline.

## Common pitfalls

> [!WARNING]
> - **Expecting Tekton to enforce `timeout` and `retries` on a custom task.** The controller of the custom task must do it.
> - **Writing results with other names than the pipeline reads.** The pipeline then fails to resolve `$(tasks.<task>.results.<name>)`.
> - **Forgetting to handle cancellation.** The pipeline task ends only after the timeout of the run.
> - **Choosing a custom task for work that fits in a pod.** A Task is simpler to run and to read.
