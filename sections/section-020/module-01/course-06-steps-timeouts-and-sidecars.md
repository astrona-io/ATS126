# Step Timeouts, Step onError And Sidecars

Timeouts and failure handling also exist inside a Task. A step can have its own timeout and its own `onError`, and a Task can run a sidecar container next to its steps. This part shows what each one does to the TaskRun, and where it differs from the pipeline-level settings.

## A timeout on one step

A step has a `timeout` field. If the step runs longer, Tekton stops it and the TaskRun fails with a reason that names the step timeout. The TaskRun's own `timeout` still applies as a ceiling for all steps together. Set the step timeout lower than the TaskRun timeout when one step must not hang the whole Task.

<!-- astrona:playground:renew -->

Save this as `task-slow-step.yaml`:

```yaml
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: slow-step
  namespace: starfleet
spec:
  steps:
    - name: quick
      image: busybox:1.37.0
      script: |
        #!/bin/sh
        echo "quick step"
    - name: slow
      image: busybox:1.37.0
      timeout: 5s
      script: |
        #!/bin/sh
        sleep 30
```

Apply it and run it:

```sh
kubectl apply -f task-slow-step.yaml
tkn task start slow-step -n starfleet --prefix-name slow --showlog
```

The `quick` step prints its line. The `slow` step is stopped after five seconds and the TaskRun ends `Failed`. Read the step state to see which step failed and why:

```sh
kubectl get taskrun -n starfleet -l tekton.dev/task=slow-step -o jsonpath='{range .items[*].status.steps[*]}{.name}{" "}{.terminated.reason}{"\n"}{end}'
```

## onError on a step

A step with `onError: continue` may fail without failing the Task. Tekton records the exit code in the file `$(steps.<step name>.exitCode.path)`, so a later step can read it and decide. A step without `onError` stops the Task when it fails, as before.

```yaml
steps:
  - name: lint
    image: busybox:1.37.0
    onError: continue
    script: |
      #!/bin/sh
      exit 3
  - name: report
    image: busybox:1.37.0
    script: |
      #!/bin/sh
      echo "lint exit code: $(cat $(steps.lint.exitCode.path))"
```

The `report` step prints the exit code `3` of `lint`, and the TaskRun succeeds. Compare this with `onError` on a pipeline task, which keeps the pipeline going when a whole TaskRun fails. The step form keeps the Task going when one step fails.

## Sidecars

A sidecar is a container that starts next to the steps and lives for the length of the TaskRun, such as a database for an integration test. It is listed under `sidecars` in the Task. When the last step ends, Tekton stops the sidecar, so a Task does not hang on a container that never exits. A sidecar has no result path and does not decide the outcome by itself: a sidecar that exits early does not fail the TaskRun, but the steps that needed it may.

Containers of one pod share the network, so a step reaches the sidecar on `localhost` and the port it listens on. A step that starts before the sidecar is ready can fail on its first connection, so tests should retry the connection or wait for the port.

## Which timeout applies

| Setting | Scope |
| --- | --- |
| `timeout` on a step | One step |
| `timeout` on a TaskRun | All steps of one Task |
| `timeout` on a pipeline task | One TaskRun in the Pipeline |
| `timeouts.tasks` and `timeouts.pipeline` on a PipelineRun | All tasks, and the run with finally |

The smallest limit that is reached first decides. You can now place a limit where the hang can happen, let a non-critical step fail without failing the Task, and run a helper container next to the steps.

## Common pitfalls

> [!WARNING]
> - **Setting a step timeout above the TaskRun timeout.** The TaskRun limit is reached first.
> - **Using `onError: continue` and never reading the exit code.** The failure then goes unnoticed.
> - **Connecting to a sidecar before it listens.** The first attempt fails; retry it.
> - **Expecting the sidecar to keep the TaskRun alive.** The TaskRun ends when the last step ends.
