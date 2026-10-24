# Solution: Guard A Deploy And Report With finally

Work the task yourself first. Running `astrona submit -c sections/section-020/module-01/labs/lab-01` after a step tells you which checks pass, without telling you what is left.

The grader checks four things: the Pipeline guards `deploy` and has `notify` under `finally`; `ship-main` deployed and was reported as `Succeeded`; `ship-feature` skipped `deploy` and was reported as `Completed`; and a run with a failing build still gets a report.

## Step 1: See the problem

Read the run the lab starts with:

```sh
kubectl get taskruns -n starfleet -l tekton.dev/pipelineRun=ship-feature-0 -o custom-columns='TASK:.metadata.labels.tekton\.dev/pipelineTask,REASON:.status.conditions[0].reason'
kubectl get taskrun ship-feature-0-deploy -n starfleet -o jsonpath='{.status.results[?(@.name=="deployed")].value}{"\n"}'
```

Both `build` and `deploy` ran, and `deploy` reports `deployed ship:feature-radar`. Nothing in the Pipeline looks at the branch, and there is no `finally` list.

## Step 2: Guard the deploy and add the report

The guard goes on the pipeline task `deploy`. The report goes into a new `finally` list, so it runs after `build` and `deploy` have finished, even when one of them failed. Its parameters use only the Pipeline parameter and execution status: `$(tasks.status)` for all tasks, `$(tasks.deploy.status)` for `deploy`. A result of `build` would make `notify` skip itself whenever `build` fails.

Save this as `pipeline-ship.yaml`:

```yaml
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: ship
  namespace: starfleet
spec:
  params:
    - name: branch
      type: string
    - name: fail
      type: string
      default: "false"
  tasks:
    - name: build
      taskRef:
        name: build-app
      params:
        - name: branch
          value: $(params.branch)
        - name: fail
          value: $(params.fail)
    - name: deploy
      when:
        - input: $(params.branch)
          operator: in
          values:
            - main
      taskRef:
        name: deploy-app
      params:
        - name: image
          value: $(tasks.build.results.image)
  finally:
    - name: notify
      taskRef:
        name: notify
      params:
        - name: branch
          value: $(params.branch)
        - name: pipeline-status
          value: $(tasks.status)
        - name: deploy-status
          value: $(tasks.deploy.status)
```

Apply it:

```sh
kubectl apply -f pipeline-ship.yaml
```

## Step 3: Run it for main and for the feature branch

Save this as `pipelinerun-ship-main.yaml`:

```yaml
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  name: ship-main
  namespace: starfleet
spec:
  pipelineRef:
    name: ship
  params:
    - name: branch
      value: main
```

Save this as `pipelinerun-ship-feature.yaml`:

```yaml
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  name: ship-feature
  namespace: starfleet
spec:
  pipelineRef:
    name: ship
  params:
    - name: branch
      value: feature/radar
```

Apply both and wait:

```sh
kubectl apply -f pipelinerun-ship-main.yaml -f pipelinerun-ship-feature.yaml
kubectl wait --for=condition=Succeeded pipelinerun/ship-main pipelinerun/ship-feature -n starfleet --timeout=300s
```

## Step 4: Check the outcome

```sh
kubectl get pipelineruns ship-main ship-feature -n starfleet -o custom-columns='NAME:.metadata.name,REASON:.status.conditions[0].reason,SKIPPED:.status.skippedTasks[*].name'
kubectl get pipelinerun ship-feature -n starfleet -o jsonpath='{.status.skippedTasks[0].reason}{"\n"}'
kubectl get taskrun ship-main-notify ship-feature-notify -n starfleet -o custom-columns='NAME:.metadata.name,LIST:.metadata.labels.tekton\.dev/memberOf,MESSAGE:.status.results[0].value'
```

`ship-main` ends with `Succeeded` and skips nothing. `ship-feature` ends with `Completed` and skips `deploy` with the reason `When Expressions evaluated to false`. The two `notify` TaskRuns belong to the `finally` list and report `branch=main pipeline=Succeeded deploy=Succeeded` and `branch=feature/radar pipeline=Completed deploy=None`.

You can try the failure case yourself; the grader runs the same check:

```sh
tkn pipeline start ship -n starfleet -p branch=main -p fail=true --prefix-name ship-broken --showlog
```

`build` fails, `deploy` is skipped, and `notify` still runs and reports `branch=main pipeline=Failed deploy=None`. Delete that run afterwards if you like; the grader does not need it.

## Step 5: Submit

```sh
astrona submit -c sections/section-020/module-01/labs/lab-01
```

## Why the obvious shortcuts are wrong

| Shortcut | What happens |
| --- | --- |
| Put `notify` under `tasks` with `runAfter: [deploy]` | It cannot use `$(tasks.status)` there, and after a failed build it is skipped with `PipelineRun was stopping` |
| Pass `$(tasks.build.results.image)` to `notify` | After a failed build the result is missing, and `notify` is skipped with `Results were missing` |
| Use `operator: notin` with `values: [main]` | The guard is upside down: `main` is skipped and feature branches deploy |
| Check the branch inside the `deploy-app` script | The Task must not change, and the run would still show `deploy` as run |
| Run `ship-feature` with `pipelineSpec` | The grader requires `pipelineRef` name `ship` |

## Common mistakes

- Reading `Completed` on `ship-feature` as a failure. It means success with a skipped task.
- Expecting `deploy=Failed` after a failed build. `deploy` never ran, so its status is `None`.
- Forgetting that a `PipelineRun` cannot be changed: if a run used the old Pipeline, delete it and create it again.

## Practice on your own

- Add a second `finally` task that runs only when `build` failed, with `when: [{input: "$(tasks.build.status)", operator: in, values: ["Failed"]}]`.
- Add `$(tasks.build.reason)` to the report and compare the values for a good and a failed build.
- Allow two branches to deploy by adding `release` to `values`.
