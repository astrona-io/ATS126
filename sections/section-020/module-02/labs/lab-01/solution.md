# Solution: Run A Pipeline With A Service Account, Limits And Timeouts

Work the task yourself first. Running `astrona submit -c sections/section-020/module-02/labs/lab-01` after a step tells you which checks pass, without telling you what is left.

The grader checks three things: the spec of `render-run` (pipeline reference, service account and pod security context), the resources and timeouts (the limit on `build` only, and the three timeouts), and the pods that actually ran.

## Step 1: Look at the Pipeline

```sh
kubectl get pipeline render -n starfleet -o jsonpath='{range .spec.tasks[*]}{.name}{"\n"}{end}'
kubectl get serviceaccount builder -n starfleet
```

The pipeline tasks are `fetch` and `build`. The names matter: `taskRunSpecs` uses them. The Pipeline has no service account and no resources, and it must stay that way.

## Step 2: Write the PipelineRun

Settings for every pod go in `taskRunTemplate`. Settings for one task go in `taskRunSpecs` with the name of the pipeline task. The three timeouts go in `timeouts`.

Save this as `pipelinerun-render-run.yaml`:

```yaml
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  name: render-run
  namespace: starfleet
spec:
  pipelineRef:
    name: render
  timeouts:
    pipeline: 10m
    tasks: 8m
    finally: 2m
  taskRunTemplate:
    serviceAccountName: builder
    podTemplate:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 1000
  taskRunSpecs:
    - pipelineTaskName: build
      computeResources:
        requests:
          cpu: 100m
          memory: 64Mi
        limits:
          memory: 128Mi
```

The timeouts must fit together: `pipeline` has to be at least `tasks` plus `finally`, and 10 minutes is exactly 8 plus 2.

## Step 3: Apply it and wait

```sh
kubectl apply -f pipelinerun-render-run.yaml
kubectl wait --for=condition=Succeeded pipelinerun/render-run -n starfleet --timeout=300s
```

## Step 4: Check what the pods got

Do not trust the spec of the run alone. Read the pods:

```sh
kubectl get pods -n starfleet -l tekton.dev/pipelineRun=render-run -o custom-columns='POD:.metadata.name,SA:.spec.serviceAccountName,USER:.spec.securityContext.runAsUser'
kubectl get taskrun render-run-build -n starfleet -o jsonpath='{.spec.computeResources}{"\n"}'
kubectl logs render-run-fetch-pod -n starfleet -c step-fetch
```

Both pods show `builder` and `1000`. The TaskRun of `build` holds the limit, and the log of `fetch` prints `fetching as user 1000`.

## Step 5: Submit

```sh
astrona submit -c sections/section-020/module-02/labs/lab-01
```

## Why the obvious shortcuts are wrong

| Shortcut | What happens |
| --- | --- |
| Put `serviceAccountName` and resources in the Pipeline | The grader requires them on the run, and the Pipeline must stay unchanged |
| Put the memory limit in `taskRunTemplate` | It does not exist there; the limit belongs to one task in `taskRunSpecs` |
| Add the limit to `fetch` as well | The task says only `build` is limited |
| Change `config-defaults` | The settings would change for every run in the cluster |
| Use the Task name in `pipelineTaskName` | The name is the one under `tasks:` in the Pipeline |

## Common mistakes

- Writing `10m` for `tasks` and `finally`. The webhook rejects a pipeline timeout smaller than their sum.
- Forgetting `fsGroup`. The run still works here, but a workspace volume would not be writable for the user.
- Applying a new `render-run` over the old one. A started run cannot change; delete it and apply again.

## Practice on your own

- Set the memory limit of `build` to `4Mi` and read the reason of the TaskRun.
- Name a service account that does not exist and read the message.
- Add the label `tier: batch` to `build` with `taskRunSpecs[].metadata.labels` and find it on the TaskRun.
