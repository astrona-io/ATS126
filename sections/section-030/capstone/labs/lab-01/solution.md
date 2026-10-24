# Solution: Repair A Broken CI Pipeline

Work the task yourself first. Running `astrona submit -c sections/section-030/capstone/labs/lab-01` after a step tells you which checks pass, without telling you what is left.

The grader checks five things: the Pipeline spec (resolver, matrix, guard, report); the main run and its graph; the image in the registry and `bridge-release`; the feature run and both notifications; and a run on `broken` that still gets a notification.

## Step 1: Read the first failure

```sh
kubectl get pipelineruns -n starfleet -o custom-columns='NAME:.metadata.name,REASON:.status.conditions[0].reason'
kubectl get pipelinerun bridge-ci-main -n starfleet -o jsonpath='{.status.conditions[0].message}{"\n"}'
kubectl get pipeline bridge-ci -n starfleet -o jsonpath='{.spec.tasks[?(@.name=="build")].taskRef}{"\n"}'
kubectl get tasks --all-namespaces
```

Both runs failed with `CouldntGetTask`, before any TaskRun. The message names the pipeline task `build`. Its `taskRef` uses the cluster resolver with the namespace `ci-catalogue`, but the Task `build-image` is in `ci-catalog`. Copying the Task into `starfleet` would also make the error go away, but the platform team keeps one reviewed copy, so fix the reference.

## Step 2: Fix the resolver and read the next failure

Export the Pipeline to a file, so you can fix it in one place:

```sh
kubectl get pipeline bridge-ci -n starfleet -o yaml > pipeline-bridge-ci.yaml
```

In `pipeline-bridge-ci.yaml`, change `value: ci-catalogue` to `value: ci-catalog`, apply it, and run `main` again. A `PipelineRun` cannot be changed, so delete it and create it again from the same values.

Save this as `pipelinerun-bridge-ci-main.yaml`:

```yaml
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  name: bridge-ci-main
  namespace: starfleet
spec:
  pipelineRef:
    name: bridge-ci
  params:
    - name: branch
      value: main
  taskRunTemplate:
    serviceAccountName: ci-bot
  workspaces:
    - name: source
      volumeClaimTemplate:
        spec:
          accessModes:
            - ReadWriteOnce
          resources:
            requests:
              storage: 64Mi
```

Then apply both and read the condition:

```sh
kubectl apply -f pipeline-bridge-ci.yaml
kubectl delete pipelinerun bridge-ci-main -n starfleet
kubectl apply -f pipelinerun-bridge-ci-main.yaml
kubectl get pipelinerun bridge-ci-main -n starfleet -o jsonpath='{.status.conditions[0].reason}{"\n"}{.status.conditions[0].message}{"\n"}'
```

The run now fails with `PipelineValidationFailed`: the Task `unit-test` is missing a value for its parameter `image`, which has no default. The matrix of `test` passes `images`. A matrix parameter must have the name of a Task parameter; an unknown name is simply ignored, and the real one stays empty. Change `- name: images` to `- name: image` in the matrix.

## Step 3: Look at the deploy and the report before the next run

Two more faults do not fail a run, so read the rest of the Pipeline now:

```sh
kubectl get pipeline bridge-ci -n starfleet -o jsonpath='{.spec.tasks[?(@.name=="deploy")].when}{"\n"}{.spec.finally[?(@.name=="notify")].params}{"\n"}'
```

`deploy` uses `operator: notin` with `values: [main]`: it would skip `main` and deploy every other branch. Change it to `operator: in`. `notify` passes `detail` = `$(tasks.build.results.IMAGE_URL)`. When a check fails, `build` never runs, that result is missing, and the `finally` task `notify` is skipped with `Results were missing`, so failed builds are never reported. Remove the two lines of the `detail` parameter; the Task gives it a default.

After the four changes, the parts of `pipeline-bridge-ci.yaml` that matter look like this:

```yaml
    - name: test
      runAfter:
        - clone
      taskRef:
        name: unit-test
      matrix:
        params:
          - name: image
            value:
              - busybox:1.37.0
              - alpine:3.22.7
    # ...
    - name: build
      runAfter:
        - lint
        - test
        - scan
      taskRef:
        resolver: cluster
        params:
          - name: kind
            value: task
          - name: name
            value: build-image
          - name: namespace
            value: ci-catalog
    # ...
    - name: deploy
      when:
        - input: $(params.branch)
          operator: in
          values:
            - main
    # ...
  finally:
    - name: notify
      taskRef:
        name: notify
      params:
        - name: pipelinerun
          value: $(context.pipelineRun.name)
        - name: branch
          value: $(params.branch)
        - name: status
          value: $(tasks.status)
        - name: deploy-status
          value: $(tasks.deploy.status)
```

## Step 4: Run main and the feature branch

Save this as `pipelinerun-bridge-ci-feature.yaml`:

```yaml
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  name: bridge-ci-feature
  namespace: starfleet
spec:
  pipelineRef:
    name: bridge-ci
  params:
    - name: branch
      value: feature/banner
  taskRunTemplate:
    serviceAccountName: ci-bot
  workspaces:
    - name: source
      volumeClaimTemplate:
        spec:
          accessModes:
            - ReadWriteOnce
          resources:
            requests:
              storage: 64Mi
```

Apply the Pipeline and replace both runs:

```sh
kubectl apply -f pipeline-bridge-ci.yaml
kubectl delete pipelinerun bridge-ci-main bridge-ci-feature -n starfleet
kubectl apply -f pipelinerun-bridge-ci-main.yaml -f pipelinerun-bridge-ci-feature.yaml
kubectl wait --for=condition=Succeeded pipelinerun/bridge-ci-main pipelinerun/bridge-ci-feature -n starfleet --timeout=600s
```

## Step 5: Check the outcome

```sh
kubectl get pipelineruns bridge-ci-main bridge-ci-feature -n starfleet -o custom-columns='NAME:.metadata.name,REASON:.status.conditions[0].reason,SKIPPED:.status.skippedTasks[*].name'
kubectl get --raw /api/v1/namespaces/registry/services/registry:http/proxy/v2/starfleet/bridge/tags/list; echo
kubectl get configmap bridge-release ci-notification-bridge-ci-main ci-notification-bridge-ci-feature -n starfleet -o custom-columns='NAME:.metadata.name,DATA:.data'
```

`bridge-ci-main` ends `Succeeded`, and `bridge-ci-feature` ends `Completed` with `deploy` skipped. The registry has one tag per branch commit, `bridge-release` names the `main` image, and the notifications say `Succeeded`/`Succeeded` and `Completed`/`None`. To see the failure report the grader checks, create a run like `bridge-ci-main` with `generateName: bridge-ci-broken-` and `branch` = `broken`: it fails in `lint`, and its notification says `Failed`/`None`.

## Step 6: Submit

```sh
astrona submit -c sections/section-030/capstone/labs/lab-01
```

## Why the obvious shortcuts are wrong

| Shortcut | What happens |
| --- | --- |
| Copy `build-image` into `starfleet` and use `taskRef.name` | The run works, but there are now two copies to keep in step; the grader requires the resolver and no copy |
| Give `unit-test` a default for `image` | The Task must not change, and both test TaskRuns would use the same image |
| Remove the `when` expression from `deploy` | Every branch with green checks deploys |
| Move `notify` into `tasks` after `build` | After a failed check it is skipped with `PipelineRun was stopping`, and execution status is not allowed there |
| Keep `detail` but point it at `$(tasks.clone.results.commit)` | It works until `clone` fails, then `notify` is skipped again; the grader requires no results |

## Common mistakes

- Expecting a webhook error for the wrong matrix name. The webhook does not know the Task; the controller finds the missing value when the run starts.
- Applying the old run files without deleting the runs. A `PipelineRun` with the same name is not run again.
- Reading `Completed` on the feature run as a failure. It means success with a skipped task.

## Practice on your own

- Set `blocked-namespaces: ci-catalog` in the ConfigMap `cluster-resolver-config` in `tekton-pipelines-resolvers` and read the error of a new run. Undo it afterwards.
- Move `shellcheck` into `ci-catalog` too and reference it with the cluster resolver.
- Add `$(tasks.lint.reason)` as `detail` to `notify` and compare the notifications of the `main` and `broken` runs.
