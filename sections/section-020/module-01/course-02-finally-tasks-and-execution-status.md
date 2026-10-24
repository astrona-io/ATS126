# Run finally Tasks And Read Execution Status

Some work must happen at the end of every run: send a notification, delete a test namespace, upload a log. If you put that work at the end of the graph with `runAfter`, it never runs after a failure, because a failed task stops the run and every task that has not started is skipped. Tekton has a separate list for this work, `finally`. This part adds a `finally` task, runs it after a success and after a failure, and passes it the status of the other tasks so it can say what happened.

## A finally task runs after everything else

`spec.finally` is a second list of pipeline tasks, next to `spec.tasks`. Its tasks have the same fields (`name`, `taskRef` or `taskSpec`, `params`, `workspaces`, `when`), but no `runAfter`. The tekton-pipelines-controller starts them all at the same time, once every task under `tasks` has finished: succeeded, failed or been skipped. The `PipelineRun` records that moment in `status.finallyStartTime`.

A `finally` task can read two kinds of execution status that no other task can use:

| Variable | Values | Meaning |
| --- | --- | --- |
| `$(tasks.<task>.status)` | `Succeeded`, `Failed`, `None` | The outcome of one task; `None` means it was skipped or never ran |
| `$(tasks.<task>.reason)` | for example `Succeeded`, `Failed`, `TaskRunTimeout` | The reason of that task's TaskRun |
| `$(tasks.status)` | `Succeeded`, `Failed`, `Completed`, `None` | The outcome of all tasks under `tasks`; `Completed` means some were skipped |

The Pipeline `wrap-up` below has one task, `work`, that fails when the parameter `fail` is `"true"`. Its `finally` task `report` publishes the aggregate status and the status and reason of `work` as the result `message`.

<!-- astrona:playground:renew -->

Save this as `pipeline-wrap-up.yaml`:

```yaml
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: wrap-up
  namespace: starfleet
spec:
  params:
    - name: fail
      type: string
      default: "false"
  results:
    - name: report
      value: $(finally.report.results.message)
  tasks:
    - name: work
      params:
        - name: fail
          value: $(params.fail)
      taskSpec:
        params:
          - name: fail
        results:
          - name: answer
        steps:
          - name: work
            image: busybox:1.37.0
            script: |
              #!/bin/sh
              if [ "$(params.fail)" = "true" ]; then
                echo "Failing on purpose" >&2
                exit 1
              fi
              printf '42' > "$(results.answer.path)"
  finally:
    - name: report
      params:
        - name: overall
          value: $(tasks.status)
        - name: work-status
          value: $(tasks.work.status)
        - name: work-reason
          value: $(tasks.work.reason)
      taskSpec:
        params:
          - name: overall
          - name: work-status
          - name: work-reason
        results:
          - name: message
        steps:
          - name: report
            image: busybox:1.37.0
            script: |
              #!/bin/sh
              printf 'overall=%s work=%s (%s)' "$(params.overall)" "$(params.work-status)" "$(params.work-reason)" | tee "$(results.message.path)"
```

A pipeline result can take its value from a `finally` task too, with `$(finally.<task>.results.<result>)`.

Apply it, then run it once with success and once with a failure:

```sh
kubectl apply -f pipeline-wrap-up.yaml
tkn pipeline start wrap-up -n starfleet -p fail=false --prefix-name wrap-ok --showlog
tkn pipeline start wrap-up -n starfleet -p fail=true --prefix-name wrap-fail --showlog
```

The first run prints `overall=Succeeded work=Succeeded (Succeeded)`. The second run fails in `work`, and `report` still runs and prints `overall=Failed work=Failed`, followed by the reason of the failed TaskRun in brackets: `StepFailed`, because a step ended with a non-zero exit code.

## How the PipelineRun ends

A `finally` task does not hide a failure. Read the two runs side by side:

```sh
kubectl get pipelineruns -n starfleet -l tekton.dev/pipeline=wrap-up -o custom-columns='NAME:.metadata.name,REASON:.status.conditions[0].reason,FINALLY:.status.finallyStartTime,REPORT:.status.results[0].value'
kubectl get taskruns -n starfleet -l tekton.dev/pipeline=wrap-up,tekton.dev/memberOf=finally
```

The failed run ends with `Succeeded` `False` and the reason `Failed`, even though `report` succeeded. Both runs have a `finallyStartTime`, and the second command lists one `report` TaskRun per run. The controller labels each TaskRun with `tekton.dev/memberOf`, `tasks` or `finally`, so you can always tell the two lists apart.

The rule for the final condition is short. If any task under `tasks` failed, the run failed. If all of them succeeded but a `finally` task failed, the run failed too. Only when nothing failed does the run end with `Succeeded` (everything ran) or `Completed` (something was skipped).

## A finally task that is skipped

A `finally` task can use results of the other tasks, for example `$(tasks.work.results.answer)`. That looks harmless, but it breaks the main promise of `finally`. When `work` fails before it writes `answer`, the result does not exist, so the controller cannot fill in the parameter. It skips the `finally` task with the reason `Results were missing`, and the report you wanted most, the one about the failure, never arrives.

You can see it with a run that embeds a changed Pipeline:

Save this as `pipelinerun-wrap-up-result.yaml`:

```yaml
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  name: wrap-up-result
  namespace: starfleet
spec:
  pipelineSpec:
    tasks:
      - name: work
        taskSpec:
          results:
            - name: answer
          steps:
            - name: work
              image: busybox:1.37.0
              script: |
                #!/bin/sh
                exit 1
    finally:
      - name: report
        params:
          - name: answer
            value: $(tasks.work.results.answer)
        taskSpec:
          params:
            - name: answer
          steps:
            - name: report
              image: busybox:1.37.0
              script: |
                #!/bin/sh
                echo "The answer was $(params.answer)"
```

Apply it and read the skipped tasks:

```sh
kubectl apply -f pipelinerun-wrap-up-result.yaml
kubectl get pipelinerun wrap-up-result -n starfleet -o jsonpath='{.status.conditions[0].reason}{"\n"}{range .status.skippedTasks[*]}{.name}{": "}{.reason}{"\n"}{end}'
```

Wait until the run has ended, and run the second command again if the list is still empty. `report` is skipped with `Results were missing`. A `finally` task that must always run should take only parameters, constants and execution status, never a result of a task that can fail or be skipped. If it needs a result only in the good case, guard it with `when` on `$(tasks.<task>.status)`, or give it a second, result-free `finally` task for the bad case.

You can now add work that runs at the end of every run and tell it exactly what happened before. Together with `when` expressions, that is enough to deploy only from the right branch and to report every outcome. The open question is time and flakiness: what to do with a task that hangs, a task that fails once in a while, and a failure that is known and harmless.

## Common pitfalls

> [!WARNING]
> - **Putting the notification at the end of `tasks`.** After a failure it is skipped with `PipelineRun was stopping`. Put it under `finally`.
> - **Passing a result to a `finally` task that must always run.** If the source task fails or is skipped, the `finally` task is skipped with `Results were missing`.
> - **Using `$(tasks.status)` outside `finally`.** The webhook rejects it; execution status exists only for `finally` tasks.
> - **Expecting `finally` to turn a failure into a success.** The run still ends `Failed`.
> - **Adding `runAfter` to a `finally` task.** It is not allowed; all `finally` tasks start together.

## Your mission: Guard A Deploy And Report With finally

You can now guard a task with a `when` expression, add a `finally` task, and pass it the aggregate status and the status of one task. The graded lab gives you a delivery Pipeline that deploys from every branch and reports nothing, and asks you to guard the deploy, add the report, and prove both with runs on two branches.

The lab runs in its own cluster, so first pause your playground. Nothing in it is lost:

```sh
astrona stop ats-126-playground-020-01
```

Then start the lab:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS126.git -c sections/section-020/module-01/labs/lab-01
```

The task is on the next page. Solve it on your own first. When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-020/module-01/labs/lab-01
```

When the lab is done, remove it and start your playground again:

```sh
astrona destroy ats-126-lab-020-01
astrona start ats-126-playground-020-01
```
