# Cancel, Stop And Pause A Run

Control flow does not end when a PipelineRun starts. A release is pulled, a wrong parameter is noticed after the first task, or a shared cluster must stay quiet during a maintenance window. In each case you change a running `PipelineRun`, or you create it and hold it back. Tekton does this through one field, `spec.status`, and its four values decide what happens to the tasks that are running and to the `finally` tasks. This part uses each value and reads the reasons it produces.

## The field spec.status

Most of a `PipelineRun` spec cannot change after it is created. The field `spec.status` is the exception. You can set it to one of four values:

| Value | What the controller does | Reason on the PipelineRun |
| --- | --- | --- |
| `Cancelled` | Cancels every running TaskRun at once. No new task starts and the `finally` tasks do not run | `Cancelled` |
| `CancelledRunFinally` | Cancels every running TaskRun, then runs the `finally` tasks | `CancelledRunFinally` |
| `StoppedRunFinally` | Lets the running TaskRuns finish, starts no new task, then runs the `finally` tasks | `StoppedRunFinally` |
| `PipelineRunPending` | Holds a new run back. Nothing starts until the field is removed | `PipelineRunPending` |

The first three end a run. The last one delays it. All four are set with a patch, so the name of the run stays the same and its history stays in one object.

## Cancel and stop a slow run

The Pipeline `slow-steps` below has three tasks one after the other, and a `finally` task that reports the aggregate status. Each task sleeps for a while, so you have time to act.

<!-- astrona:playground:renew -->

Save this as `pipeline-slow-steps.yaml`:

```yaml
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: slow-steps
  namespace: starfleet
spec:
  tasks:
    - name: one
      taskSpec:
        steps:
          - name: sleep
            image: busybox:1.37.0
            script: |
              #!/bin/sh
              echo "one is working"
              sleep 40
    - name: two
      runAfter:
        - one
      taskSpec:
        steps:
          - name: sleep
            image: busybox:1.37.0
            script: |
              #!/bin/sh
              echo "two is working"
              sleep 40
    - name: three
      runAfter:
        - two
      taskSpec:
        steps:
          - name: sleep
            image: busybox:1.37.0
            script: |
              #!/bin/sh
              echo "three is working"
              sleep 40
  finally:
    - name: report
      taskSpec:
        steps:
          - name: report
            image: busybox:1.37.0
            script: |
              #!/bin/sh
              echo "Aggregate status: $(tasks.status)"
```

Apply it and start three runs. The `--prefix-name` option gives each run a readable name that starts with the prefix:

```sh
kubectl apply -f pipeline-slow-steps.yaml
tkn pipeline start slow-steps -n starfleet --prefix-name hard-cancel
tkn pipeline start slow-steps -n starfleet --prefix-name soft-cancel
tkn pipeline start slow-steps -n starfleet --prefix-name stopped
kubectl get pipelineruns -n starfleet
```

The names carry a random suffix. Copy them from the list and put them in the commands below in place of `<HARD>`, `<SOFT>` and `<STOPPED>`. Wait until each run has started its task `one`, then patch the three runs, each with another value:

```sh
kubectl patch pipelinerun <HARD> -n starfleet --type merge -p '{"spec":{"status":"Cancelled"}}'
kubectl patch pipelinerun <SOFT> -n starfleet --type merge -p '{"spec":{"status":"CancelledRunFinally"}}'
kubectl patch pipelinerun <STOPPED> -n starfleet --type merge -p '{"spec":{"status":"StoppedRunFinally"}}'
```

Read the conditions and the TaskRuns a few seconds later:

```sh
kubectl get pipelineruns -n starfleet
kubectl get taskruns -n starfleet -o custom-columns='NAME:.metadata.name,REASON:.status.conditions[0].reason'
```

You will see three different pictures:

- The run you set to `Cancelled` ends at once. Its TaskRun `one` has the reason `TaskRunCancelled`, `two` and `three` never exist, and there is no TaskRun for `report`.
- The run you set to `CancelledRunFinally` also cancels `one`, and then a TaskRun for `report` appears and prints `Aggregate status: Failed`. The run ends as failed with the reason `CancelledRunFinally`.
- The run you set to `StoppedRunFinally` does not touch `one`. It finishes its sleep and succeeds. Then the run starts no `two`, runs `report`, and ends with the reason `StoppedRunFinally`.

The command `tkn pipelinerun cancel <name> -n starfleet` is the short form of the first patch. It sets `Cancelled`.

## Create a run on hold

A run with `spec.status: PipelineRunPending` is created but not started. Save this as `pipelinerun-held.yaml`:

```yaml
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  name: held-run
  namespace: starfleet
spec:
  status: PipelineRunPending
  pipelineRef:
    name: slow-steps
```

Apply it and read it:

```sh
kubectl apply -f pipelinerun-held.yaml
kubectl get pipelinerun held-run -n starfleet
kubectl get taskruns -n starfleet -l tekton.dev/pipelineRun=held-run
```

The run shows the reason `PipelineRunPending` and has no TaskRuns. Release it by removing the field:

```sh
kubectl patch pipelinerun held-run -n starfleet --type merge -p '{"spec":{"status":null}}'
```

The run now starts as usual. A pending run is useful when something else must be ready before the run begins, for example a maintenance window or a quota that another team controls. Note that `PipelineRunPending` only works at the start: setting it on a run that already runs is rejected.

## Choose the right value

Use `Cancelled` when the work is wrong or dangerous and nothing else should run. Use `CancelledRunFinally` when the work must stop now but a cleanup or a report must still happen. Use `StoppedRunFinally` when the running task is safe to finish, such as a deploy that must not be cut in half. All three leave a record: the run, its TaskRuns and their logs stay until you delete them.

## Common pitfalls

> [!WARNING]
> - **Expecting `finally` after `Cancelled`.** Only `CancelledRunFinally` and `StoppedRunFinally` run the `finally` tasks.
> - **Deleting a run to stop it.** Deleting removes the history and the logs. Cancel it first.
> - **Cancelling in the middle of a deploy.** A cancelled TaskRun stops its container where it is. Use `StoppedRunFinally` for steps that must finish.
> - **Setting `PipelineRunPending` on a started run.** The value is for new runs only.
> - **Editing other fields of a started PipelineRun.** Only `spec.status` can change.
