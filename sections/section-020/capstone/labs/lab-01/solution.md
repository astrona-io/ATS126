# Solution: Make A Nightly Pipeline Reliable

Work the task yourself first. Running `astrona submit -c sections/section-020/capstone/labs/lab-01` after a step tells you which checks pass, without telling you what is left.

The grader checks three things: the Pipeline has the right `retries`, `timeout`, `onError` and a `finally` report without results; `nightly-run` succeeded with a retried `warm-cache`, an ignored `docs-check` and the report `integration=Succeeded docs=Failed`; and a run with failing tests still gets the report `integration=Failed docs=Failed`.

## Step 1: Read the first failure

Read the run, its TaskRuns and its skipped tasks:

```sh
kubectl get pipelinerun nightly-run -n starfleet -o jsonpath='{.status.conditions[0].reason}{"\n"}{range .status.skippedTasks[*]}{.name}{": "}{.reason}{"\n"}{end}'
kubectl get taskruns -n starfleet -l tekton.dev/pipelineRun=nightly-run -o custom-columns='TASK:.metadata.labels.tekton\.dev/pipelineTask,REASON:.status.conditions[0].reason'
kubectl logs nightly-run-warm-cache-pod -n starfleet -c step-download
```

The run `Failed`. `warm-cache` ended with `StepFailed`, and its log says `Running in pod nightly-run-warm-cache-pod` and `The cache mirror did not answer`. The Task fails in every pod whose name does not end in `-retry1` or higher, so only a retry gets past it. `integration` and `docs-check` are skipped with `PipelineRun was stopping`. The `finally` task `report` is skipped too, with `Results were missing`: it needs the result `summary` of `integration`, which never ran. That is two faults already: `warm-cache` needs a second attempt, and `report` must not depend on a result.

## Step 2: Fix the Pipeline step by step

Start with the two faults you can see, run again, and read the next failure. The full, final Pipeline is below; build it up in this order:

1. Add `retries: 1` to `warm-cache`. A new run gets past it, and `integration` ends with `TaskRunTimeout` after 10 seconds, while its tests need about 20.
2. Change the `timeout` of `integration` to `2m`. The next run fails because `docs-check` ends with `StepFailed`.
3. Add `onError: continue` to `docs-check`. Its TaskRun then ends with `FailureIgnored`, and the run succeeds.
4. Change the parameter `integration` of `report` from `$(tasks.integration.results.summary)` to `$(tasks.integration.status)`.

Save this as `pipeline-nightly.yaml`:

```yaml
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: nightly
  namespace: starfleet
spec:
  params:
    - name: break
      type: string
      default: "false"
  tasks:
    - name: warm-cache
      retries: 1
      taskRef:
        name: warm-cache
    - name: integration
      runAfter:
        - warm-cache
      timeout: 2m
      taskRef:
        name: integration
      params:
        - name: break
          value: $(params.break)
    - name: docs-check
      runAfter:
        - warm-cache
      onError: continue
      taskRef:
        name: docs-check
  finally:
    - name: report
      taskRef:
        name: report
      params:
        - name: integration
          value: $(tasks.integration.status)
        - name: docs
          value: $(tasks.docs-check.status)
```

Apply it after each change:

```sh
kubectl apply -f pipeline-nightly.yaml
```

## Step 3: Run it again

Save this as `pipelinerun-nightly-run.yaml`:

```yaml
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  name: nightly-run
  namespace: starfleet
spec:
  pipelineRef:
    name: nightly
```

A `PipelineRun` runs once, so delete the old one and create it again after each change:

```sh
kubectl delete pipelinerun nightly-run -n starfleet
kubectl apply -f pipelinerun-nightly-run.yaml
kubectl wait --for=condition=Succeeded pipelinerun/nightly-run -n starfleet --timeout=300s
```

## Step 4: Check the outcome

```sh
kubectl get taskruns -n starfleet -l tekton.dev/pipelineRun=nightly-run -o custom-columns='TASK:.metadata.labels.tekton\.dev/pipelineTask,REASON:.status.conditions[0].reason,EARLIER:.status.retriesStatus[*].podName,TIMEOUT:.spec.timeout'
kubectl get taskrun nightly-run-report -n starfleet -o jsonpath='{.status.results[?(@.name=="message")].value}{"\n"}'
```

`warm-cache` succeeded, with the earlier attempt `nightly-run-warm-cache-pod` in `status.retriesStatus`. `integration` succeeded and shows the timeout `2m0s`. `docs-check` shows `FailureIgnored`. The report says `integration=Succeeded docs=Failed`: an ignored failure is still `Failed` in execution status, even though the run succeeded.

To see the failure case the grader tests, start a run with failing tests:

```sh
tkn pipeline start nightly -n starfleet -p break=true --prefix-name nightly-broken --showlog
```

The run fails in `integration`, and `report` still runs and says `integration=Failed docs=Failed`.

## Step 5: Submit

```sh
astrona submit -c sections/section-020/capstone/labs/lab-01
```

## Why the obvious shortcuts are wrong

| Shortcut | What happens |
| --- | --- |
| `retries: 3` on `docs-check` | It fails every time, so it only wastes three attempts and still fails the run; with `onError: continue` the webhook would also reject the combination |
| Remove `timeout` from `integration` | A hanging test would hold the run for the default 60 minutes; the task requires a timeout from `1m` to `5m` |
| Move `report` into `tasks` with `runAfter` | It cannot use execution status there, and it is skipped after a failure |
| Give `report` the result `summary` in a `when`-guarded second task only | The report about the failure still depends on what ran; the task asks for one report that always runs |
| `onError: continue` on `integration` | The nightly run would succeed with failing tests |

## Common mistakes

- Looking for a second TaskRun of `warm-cache`. The retry reuses the TaskRun and adds a pod named `-retry1`.
- Reading `docs=Failed` as a mistake. `FailureIgnored` is still a failure for `$(tasks.docs-check.status)`.
- Fixing the timeout in the run with `taskRunSpecs` only. That fixes one run; the Pipeline must carry the timeout.

## Practice on your own

- Add `timeouts: {pipeline: 2m, tasks: 90s, finally: 30s}` to the run and predict which limit `integration` hits first if its tests took 100 seconds.
- Run `integration` with `retries: 2` and `break=true`. How many pods does it get, and what are their names?
- Add `$(tasks.status)` to the report and explain why it says `Failed` on a successful run.
