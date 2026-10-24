# Timeouts, Retries And onError

Real tasks fail for reasons that have nothing to do with the code under test. A download times out once and works on the next try. A test hangs and holds the run, and the cluster, for an hour. A documentation check fails because of an external link that the team already knows about. Each of these needs a different answer, and Tekton has a field for each: `retries` for failures that go away, `timeout` and `timeouts` for work that takes too long, and `onError` for failures that must not stop the run. This part tries all three and shows where each one leaves its trace in the status.

## Retry a flaky task

`retries` on a pipeline task is the number of extra attempts after a failure. When the TaskRun fails, the controller does not create a new TaskRun. It keeps the same TaskRun, moves the status of the failed attempt into `status.retriesStatus`, sets the reason `ToBeRetried` for a moment, and starts a new pod named `<taskrun>-pod-retry1`, then `-retry2`, and so on. Inside a step, `$(context.task.retry-count)` gives the number of the current attempt: `0` for the first, `1` for the first retry.

The task `flaky` below uses that variable to fail on its first attempt only, so you can watch a retry without waiting for bad luck. The Pipeline also has a task `docs-check` that always fails, with `onError: continue`, which you will read about in a moment.

<!-- astrona:playground:renew -->

Save this as `pipeline-steady.yaml`:

```yaml
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: steady
  namespace: starfleet
spec:
  tasks:
    - name: flaky
      retries: 2
      taskSpec:
        steps:
          - name: download
            image: busybox:1.37.0
            script: |
              #!/bin/sh
              echo "Attempt number $(context.task.retry-count)"
              if [ "$(context.task.retry-count)" = "0" ]; then
                echo "The download failed" >&2
                exit 1
              fi
              echo "The download worked"
    - name: docs-check
      onError: continue
      taskSpec:
        steps:
          - name: links
            image: busybox:1.37.0
            script: |
              #!/bin/sh
              echo "One external link is broken" >&2
              exit 1
    - name: package
      runAfter:
        - flaky
        - docs-check
      taskSpec:
        steps:
          - name: package
            image: busybox:1.37.0
            script: |
              #!/bin/sh
              echo "Packaged"
```

Apply it and run it:

```sh
kubectl apply -f pipeline-steady.yaml
tkn pipeline start steady -n starfleet --prefix-name steady --showlog
```

Then look at the TaskRun of `flaky` and its pods. Use the run name from `tkn pipelinerun list -n starfleet` in place of `<RUN>`:

```sh
kubectl get taskrun <RUN>-flaky -n starfleet -o jsonpath='{.status.conditions[0].reason}{"\n"}{range .status.retriesStatus[*]}{.podName}{" "}{.conditions[0].reason}{"\n"}{end}'
kubectl get pods -n starfleet -l tekton.dev/taskRun=<RUN>-flaky
```

`status.retriesStatus` has one entry: the first attempt, with its own pod name and the reason `StepFailed`. The TaskRun itself ends `Succeeded`, and there are two pods, `<RUN>-flaky-pod` and `<RUN>-flaky-pod-retry1`. The second retry was never needed.

## Let a known failure pass with onError

`docs-check` failed, yet `package` ran and the run succeeded. That is `onError: continue` on a pipeline task. The TaskRun of `docs-check` still ends `Succeeded` `False`, but with the reason `FailureIgnored`, and the controller does not stop the run for it. Read the run's condition and the reason of `docs-check`:

```sh
kubectl get pipelinerun <RUN> -n starfleet -o jsonpath='{.status.conditions[0].reason}: {.status.conditions[0].message}{"\n"}'
kubectl get taskrun <RUN>-docs-check -n starfleet -o jsonpath='{.status.conditions[0].status} {.status.conditions[0].reason}{"\n"}'
```

The run ends `Succeeded`, and its message counts the ignored failure separately, in the form `Tasks Completed: 3 (Failed: 1 (Ignored: 1), Cancelled 0), Skipped: 0`. The default value of `onError` is `stopAndFail`, the normal behaviour. Two limits apply. `retries` and `onError: continue` cannot be set on the same task; the webhook rejects that. And an ignored failure is still a failure for execution status: in a `finally` task, `$(tasks.docs-check.status)` is `Failed`, and `$(tasks.status)` is `Failed` too, even though the `PipelineRun` succeeded.

## Limit the time

A task that hangs is worse than a task that fails, because it holds its pod and blocks the tasks after it. Tekton has two kinds of limits, both written as Go durations such as `30s`, `5m` or `1h30m`:

| Field | Where | Limits |
| --- | --- | --- |
| `timeout` | a pipeline task in the `Pipeline` | One TaskRun; it ends with the reason `TaskRunTimeout` |
| `timeouts.pipeline` | the `PipelineRun` | The whole run, `finally` included; it ends with `PipelineRunTimeout` |
| `timeouts.tasks` | the `PipelineRun` | All tasks under `tasks` together; then the `finally` tasks start |
| `timeouts.finally` | the `PipelineRun` | All `finally` tasks together |

The three `timeouts` must fit together: `pipeline` must be at least `tasks` plus `finally`. Without any `timeouts`, the default from `config-defaults` applies, 60 minutes. A timed-out TaskRun counts as a failure, so the run stops, and its `finally` tasks run as long as there is time left for them.

The run below embeds a Pipeline with a task that sleeps for a minute but may take only 10 seconds, and a `finally` task.

Save this as `pipelinerun-slow.yaml`:

```yaml
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  name: slow-1
  namespace: starfleet
spec:
  timeouts:
    pipeline: 3m
    tasks: 2m
    finally: 1m
  pipelineSpec:
    tasks:
      - name: slow
        timeout: 10s
        taskSpec:
          steps:
            - name: wait
              image: busybox:1.37.0
              script: |
                #!/bin/sh
                sleep 60
    finally:
      - name: cleanup
        params:
          - name: slow-reason
            value: $(tasks.slow.reason)
        taskSpec:
          params:
            - name: slow-reason
          steps:
            - name: cleanup
              image: busybox:1.37.0
              script: |
                #!/bin/sh
                echo "slow ended with $(params.slow-reason)"
```

Apply it, wait, and read the outcome:

```sh
kubectl apply -f pipelinerun-slow.yaml
kubectl wait --for=condition=Succeeded=false pipelinerun/slow-1 -n starfleet --timeout=180s
kubectl get taskruns -n starfleet -l tekton.dev/pipelineRun=slow-1 -o custom-columns='TASK:.metadata.labels.tekton\.dev/pipelineTask,REASON:.status.conditions[0].reason,TIMEOUT:.spec.timeout'
```

The TaskRun of `slow` ends with `TaskRunTimeout` after about 10 seconds, and its `spec.timeout` shows `10s` in the Go form the API server stores. `cleanup` ran and logged `slow ended with TaskRunTimeout`. The `PipelineRun` ended `Failed`. A run can also override the timeout of one pipeline task without changing the Pipeline, with `taskRunSpecs` and a `pipelineTaskName`; that value wins over the Pipeline's `timeout`.

You can now give a flaky task a second chance, let a known failure pass without hiding it, and stop work that takes too long, and you know where each decision shows in the status. With `when` and `finally` from earlier, that is the full set of control fields a Pipeline has.

## Common pitfalls

> [!WARNING]
> - **Looking for a second TaskRun after a retry.** A retry reuses the TaskRun; the earlier attempts are in `status.retriesStatus`, the pods end in `-retry1`, `-retry2`.
> - **Using `retries` for a failure that always happens.** Retries only cost time; use `onError: continue` for a known failure, or fix it.
> - **Setting `retries` and `onError: continue` together.** The webhook rejects that combination.
> - **Reading `FailureIgnored` as success.** The TaskRun is still `False`, and execution status reports it as `Failed`.
> - **Setting `timeouts.tasks` equal to `timeouts.pipeline`.** Then no time is left for `finally`; keep `pipeline >= tasks + finally`.
