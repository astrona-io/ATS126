# Solution: Pass Typed Parameters And An Optional Workspace

Work the task yourself first. Running `astrona submit -c sections/section-010/module-02/labs/lab-01` after a step tells you which checks pass, without telling you what is left.

The grader checks three things: `notice-run` uses the Pipeline `notice`, succeeded and reports `Notice: bridge / r9 deck 3 (3 crew)`; the Pipeline keeps `outbox` optional and passes it to the pipeline task `write`; and a new run with a bound `outbox` reports `Alert: a / r1 deck 5 (2 crew)` and `bound`.

## Step 1: Read the failure

Start with the PipelineRun:

```sh
kubectl get pipelinerun notice-run -n starfleet
kubectl get pipelinerun notice-run -n starfleet -o jsonpath='{.status.conditions[0].reason}{"\n"}{.status.conditions[0].message}{"\n"}'
kubectl get taskruns -n starfleet -l tekton.dev/pipelineRun=notice-run
```

The reason is `ParameterTypeMismatch` and the message names the parameter `crew`. There are no TaskRuns: the controller compared the values of the run with the declaration of the Pipeline before it created any. Compare both:

```sh
kubectl get pipeline notice -n starfleet -o jsonpath='{.spec.params[?(@.name=="crew")].type}{"\n"}'
kubectl get pipelinerun notice-run -n starfleet -o jsonpath='{.spec.params[?(@.name=="crew")].value}{"\n"}'
```

The Pipeline declares `crew` as a string, and the run passes a list.

## Step 2: Fix the type and the workspace together

Compare the Pipeline with the Task. The Task declares `crew` as an array, so the pipeline task must pass the whole array with `$(params.crew[*])`. Look also at the Task workspace `outbox`: the pipeline task `write` has no `workspaces` entry, so the Task never receives it, even if a run binds it.

Save this as `pipeline-notice.yaml`:

```yaml
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: notice
  namespace: starfleet
spec:
  params:
    - name: title
      type: string
      default: Notice
    - name: crew
      type: array
    - name: release
      type: object
      properties:
        name:
          type: string
        deck:
          type: string
  workspaces:
    - name: outbox
      optional: true
  results:
    - name: line
      value: $(tasks.write.results.line)
    - name: outbox
      value: $(tasks.write.results.outbox)
  tasks:
    - name: write
      taskRef:
        name: write-notice
      params:
        - name: title
          value: $(params.title)
        - name: crew
          value:
            - "$(params.crew[*])"
        - name: release
          value: $(params.release[*])
      workspaces:
        - name: outbox
          workspace: outbox
```

Apply it:

```sh
kubectl apply -f pipeline-notice.yaml
```

## Step 3: Run again

A `PipelineRun` runs once and its spec cannot change, so delete it and create it again.

Save this as `pipelinerun-notice-run.yaml`:

```yaml
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  name: notice-run
  namespace: starfleet
spec:
  pipelineRef:
    name: notice
  params:
    - name: crew
      value:
        - bridge
        - scout
        - probe
    - name: release
      value:
        name: r9
        deck: "3"
```

Delete the old run and create the new one:

```sh
kubectl delete pipelinerun notice-run -n starfleet
kubectl apply -f pipelinerun-notice-run.yaml
kubectl wait --for=condition=Succeeded pipelinerun/notice-run -n starfleet --timeout=300s
```

Then check the results:

```sh
kubectl get pipelinerun notice-run -n starfleet -o jsonpath='{range .status.results[*]}{.name}{"="}{.value}{"\n"}{end}'
```

The result `line` is `Notice: bridge / r9 deck 3 (3 crew)`. The result `outbox` is `not bound`, because this run does not bind the workspace. That is correct for this run.

## Step 4: Prove the workspace with a second run

The second fault shows only when a run binds `outbox`. Save this as `pipelinerun-notice-bound.yaml`:

```yaml
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  name: notice-bound
  namespace: starfleet
spec:
  pipelineRef:
    name: notice
  params:
    - name: title
      value: Alert
    - name: crew
      value:
        - a
        - b
    - name: release
      value:
        name: r1
        deck: "5"
  workspaces:
    - name: outbox
      emptyDir: {}
```

Apply it and read the results:

```sh
kubectl apply -f pipelinerun-notice-bound.yaml
kubectl wait --for=condition=Succeeded pipelinerun/notice-bound -n starfleet --timeout=300s
kubectl get pipelinerun notice-bound -n starfleet -o jsonpath='{range .status.results[*]}{.name}{"="}{.value}{"\n"}{end}'
```

The result `outbox` is `bound`. Without the `workspaces` entry in the pipeline task, it would stay `not bound` even though the run binds the workspace.

## Step 5: Submit

```sh
astrona submit -c sections/section-010/module-02/labs/lab-01
```

## Why the obvious shortcuts are wrong

| Shortcut | What happens |
| --- | --- |
| Change `notice-run` so it passes a string | The Task needs a list, and the grader's run passes a list |
| Change the Task to take a string | The Task must not change |
| Make `outbox` required in the Pipeline | The constraint says it stays optional, and `notice-run` does not bind it |
| Type the line into a result | The grader's run uses other values |
| Embed the Pipeline with `pipelineSpec` | `notice` stays broken; the grader requires `pipelineRef` |

## Common mistakes

- Fixing only the type and declaring success because `notice-run` passes. The mapping fault shows only in a run that binds the workspace.
- Writing `$(params.crew)` inside the list. A list of one string is not the array; use `$(params.crew[*])`.
- Editing `notice-run` with `kubectl edit`. A started `PipelineRun` cannot get a new spec.

## Practice on your own

- Remove the key `deck` from the object value of a run and read the reason.
- Add a `when` expression to `write` that runs it only when `$(workspaces.outbox.bound)` is `true`. What does `notice-run` show now?
- Bind `outbox` to a ConfigMap and read the error of the step.
