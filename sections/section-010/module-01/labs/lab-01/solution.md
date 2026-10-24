# Solution: Fix The Task Graph Of A Pipeline

Work the task yourself first. Running `astrona submit -c sections/section-010/module-01/labs/lab-01` after a step tells you which checks pass, without telling you what is left.

The grader checks three things: `launch-check-run` uses the Pipeline, succeeded and reports `r42-manifest: 3 crew ready`; in that run `count` started after `write` finished, `count` declares `runAfter: [write]`, and `report` started after both; and a new run with four crew members reports `r7-manifest: 4 crew ready`.

## Step 1: Read the first failure

Start with the PipelineRun:

```sh
kubectl get pipelinerun launch-check-run -n starfleet
kubectl get pipelinerun launch-check-run -n starfleet -o jsonpath='{.status.conditions[0].reason}{"\n"}{.status.conditions[0].message}{"\n"}'
kubectl get taskruns -n starfleet -l tekton.dev/pipelineRun=launch-check-run
```

The `SUCCEEDED` column shows `False`, and the reason is `InvalidTaskResultReference`. The message says that `manifest_id` is not a named result returned by the pipeline task `write`. There are no TaskRuns: the tekton-pipelines-controller checked every result reference against the Tasks before it created the first TaskRun. Compare the names:

```sh
kubectl get task write-manifest -n starfleet -o jsonpath='{.spec.results[*].name}{"\n"}'
kubectl get pipeline launch-check -n starfleet -o jsonpath='{.spec.tasks[?(@.name=="report")].params[*].value}{"\n"}'
```

The Task publishes `manifest-id` with a hyphen; the Pipeline asks for `manifest_id` with an underscore.

## Step 2: Fix the result name and run again

Save the Pipeline with the right result name. The rest stays as it was for now.

Save this as `pipeline-launch-check.yaml`:

```yaml
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: launch-check
  namespace: starfleet
spec:
  params:
    - name: crew
      type: string
      default: "bridge scout shuttle"
    - name: release
      type: string
  workspaces:
    - name: shared
  results:
    - name: summary
      value: $(tasks.report.results.summary)
  tasks:
    - name: write
      taskRef:
        name: write-manifest
      params:
        - name: crew
          value: $(params.crew)
        - name: release
          value: $(params.release)
      workspaces:
        - name: shared
          workspace: shared
    - name: count
      taskRef:
        name: count-crew
      workspaces:
        - name: shared
          workspace: shared
    - name: report
      taskRef:
        name: report
      params:
        - name: manifest-id
          value: $(tasks.write.results.manifest-id)
        - name: count
          value: $(tasks.count.results.count)
```

Apply it:

```sh
kubectl apply -f pipeline-launch-check.yaml
```

A `PipelineRun` runs once and its spec cannot change, so write its values to a file, delete it and create it again.

Save this as `pipelinerun-launch-check-run.yaml`:

```yaml
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  name: launch-check-run
  namespace: starfleet
spec:
  pipelineRef:
    name: launch-check
  params:
    - name: crew
      value: "bridge scout shuttle"
    - name: release
      value: r42
  workspaces:
    - name: shared
      volumeClaimTemplate:
        spec:
          accessModes:
            - ReadWriteOnce
          resources:
            requests:
              storage: 16Mi
```

Then delete the old run and create the new one:

```sh
kubectl delete pipelinerun launch-check-run -n starfleet
kubectl apply -f pipelinerun-launch-check-run.yaml
```

## Step 3: Read the second failure

Wait about half a minute, then read the run and its TaskRuns in start order:

```sh
kubectl get pipelinerun launch-check-run -n starfleet -o jsonpath='{.status.conditions[0].reason}{"\n"}{range .status.skippedTasks[*]}{.name}{": "}{.reason}{"\n"}{end}'
kubectl get taskruns -n starfleet -l tekton.dev/pipelineRun=launch-check-run --sort-by=.status.startTime -o custom-columns='TASK:.metadata.labels.tekton\.dev/pipelineTask,START:.status.startTime,END:.status.completionTime,REASON:.status.conditions[0].reason'
kubectl logs launch-check-run-count-pod -n starfleet -c step-count
```

The run failed again, this time with the reason `Failed`. `write` and `count` started at the same second; `count` failed with `StepFailed`, and its log says `manifest.txt is not in the workspace yet`. `report` is listed under skipped tasks with the reason `PipelineRun was stopping`. Nothing in the Pipeline ordered `count` after `write`: they share a workspace, but a shared workspace is not an edge in the graph.

## Step 4: Add the edge

`count` does not use a result of `write`, so the edge must be `runAfter`. In `pipeline-launch-check.yaml`, change the pipeline task `count` to this:

```yaml
    - name: count
      runAfter:
        - write
      taskRef:
        name: count-crew
      workspaces:
        - name: shared
          workspace: shared
```

Apply it, and create the run once more:

```sh
kubectl apply -f pipeline-launch-check.yaml
kubectl delete pipelinerun launch-check-run -n starfleet
kubectl apply -f pipelinerun-launch-check-run.yaml
kubectl wait --for=condition=Succeeded pipelinerun/launch-check-run -n starfleet --timeout=300s
```

Then check the result and the order:

```sh
kubectl get pipelinerun launch-check-run -n starfleet -o jsonpath='{.status.results[?(@.name=="summary")].value}{"\n"}'
kubectl get taskruns -n starfleet -l tekton.dev/pipelineRun=launch-check-run --sort-by=.status.startTime -o custom-columns='TASK:.metadata.labels.tekton\.dev/pipelineTask,START:.status.startTime,END:.status.completionTime'
```

The result is `r42-manifest: 3 crew ready`. `count` now starts at or after the end time of `write`, and `report` starts after `count` ends.

## Step 5: Submit

```sh
astrona submit -c sections/section-010/module-01/labs/lab-01
```

## Why the obvious shortcuts are wrong

| Shortcut | What happens |
| --- | --- |
| Add `sleep` to `count` instead of `runAfter` | The Task must not change, the order is still a guess, and the grader requires `runAfter: [write]` |
| Rename the result in the Task to `manifest_id` | The Tasks must not change; other Pipelines may use the old name |
| Embed the Pipeline in the run with `pipelineSpec` | The Pipeline `launch-check` stays broken for the next run; the grader requires `pipelineRef` |
| Type `3` or the whole summary into the Pipeline | The grader's run with four crew members reports the wrong value |
| Edit `launch-check-run` with `kubectl edit` | A `PipelineRun` that has started cannot get a new spec; create a new run |

## Common mistakes

- Looking for TaskRuns of the first failure. `InvalidTaskResultReference` stops the run before any TaskRun exists.
- Thinking the first fix was wrong because the run fails again. Each fix shows the next fault.
- Checking only that the run succeeded. Without `runAfter`, `count` may succeed by luck on a slow `write`; the start and end times show the real order.

## Practice on your own

- Make `report` take the count through a result and remove `count` from its parameters. Which edge does `report` lose?
- Run the fixed Pipeline with `tkn pipeline start launch-check -n starfleet -p release=r1 -w name=shared,emptyDir=""` and explain why `count` fails even with `runAfter`.
- Add a second pipeline task that also reads `manifest.txt` and runs in parallel with `count`.
