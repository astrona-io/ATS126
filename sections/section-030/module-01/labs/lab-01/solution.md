# Solution: Build An End-To-End CI Pipeline

Work the task yourself first. Running `astrona submit -c sections/section-030/module-01/labs/lab-01` after a step tells you which checks pass, without telling you what is left.

The grader checks four things: `bridge-ci-main` succeeded and followed the CI graph; the image of the head of `main` is in the registry and recorded in `bridge-release`; `bridge-ci-feature` built without deploying and both runs were notified correctly; and a run on `broken` fails in `lint` and is still notified.

## Step 1: Look at what is there

```sh
kubectl get tasks,pipelines,serviceaccounts -n starfleet
kubectl get task unit-test -n starfleet -o jsonpath='{.spec.params[*].name}{"\n"}'
kubectl get task build-image -n starfleet -o jsonpath='{.spec.params[*].name} / {.spec.results[*].name}{"\n"}'
kubectl get task notify -n starfleet -o jsonpath='{.spec.params[*].name}{"\n"}'
```

`unit-test` takes `image`, with no default. `build-image` takes `image` and `tag` and returns `IMAGE_URL` and `IMAGE_DIGEST`. `notify` takes `pipelinerun`, `branch`, `status`, `deploy-status` and an optional `detail`. The Pipeline `bridge-ci` has `clone` and `lint` only.

## Step 2: Complete the Pipeline

The three checks run after `clone` and in parallel, so each has `runAfter: [clone]` and nothing else. `build` waits for all three with `runAfter`. `deploy` needs results of `build` and `clone`, which already orders it, and its `when` expression lets it run only for `main`. `notify` goes into `finally` and takes only the run name, the branch and execution status, so a failed check cannot skip it.

Save this as `pipeline-bridge-ci.yaml`:

```yaml
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: bridge-ci
  namespace: starfleet
spec:
  params:
    - name: repo-url
      type: string
      default: http://gitea-http.gitea.svc.cluster.local:3000/starfleet/bridge.git
    - name: branch
      type: string
      default: main
    - name: image
      type: string
      default: registry.registry.svc.cluster.local:5000/starfleet/bridge
  workspaces:
    - name: source
  tasks:
    - name: clone
      taskRef:
        name: git-clone
      params:
        - name: url
          value: $(params.repo-url)
        - name: revision
          value: $(params.branch)
      workspaces:
        - name: output
          workspace: source
    - name: lint
      runAfter:
        - clone
      taskRef:
        name: shellcheck
      workspaces:
        - name: source
          workspace: source
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
      workspaces:
        - name: source
          workspace: source
    - name: scan
      runAfter:
        - clone
      taskRef:
        name: secret-scan
      workspaces:
        - name: source
          workspace: source
    - name: build
      runAfter:
        - lint
        - test
        - scan
      taskRef:
        name: build-image
      params:
        - name: image
          value: $(params.image)
        - name: tag
          value: $(tasks.clone.results.short-commit)
      workspaces:
        - name: source
          workspace: source
    - name: deploy
      when:
        - input: $(params.branch)
          operator: in
          values:
            - main
      taskRef:
        name: deploy
      params:
        - name: image-url
          value: $(tasks.build.results.IMAGE_URL)
        - name: image-digest
          value: $(tasks.build.results.IMAGE_DIGEST)
        - name: commit
          value: $(tasks.clone.results.commit)
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

Apply it:

```sh
kubectl apply -f pipeline-bridge-ci.yaml
```

## Step 3: Run it on main and on the feature branch

Both runs use `ci-bot`, because `deploy` and `notify` write ConfigMaps, and a fresh volume for `source`.

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

Apply both and wait. The first run in a fresh cluster takes about two minutes:

```sh
kubectl apply -f pipelinerun-bridge-ci-main.yaml -f pipelinerun-bridge-ci-feature.yaml
kubectl wait --for=condition=Succeeded pipelinerun/bridge-ci-main pipelinerun/bridge-ci-feature -n starfleet --timeout=600s
```

## Step 4: Check the outcome

```sh
kubectl get pipelineruns bridge-ci-main bridge-ci-feature -n starfleet -o custom-columns='NAME:.metadata.name,REASON:.status.conditions[0].reason,SKIPPED:.status.skippedTasks[*].name'
kubectl get taskruns -n starfleet -l tekton.dev/pipelineRun=bridge-ci-main --sort-by=.status.startTime -o custom-columns='TASK:.metadata.labels.tekton\.dev/pipelineTask,START:.status.startTime,END:.status.completionTime'
kubectl get --raw /api/v1/namespaces/registry/services/registry:http/proxy/v2/starfleet/bridge/tags/list; echo
kubectl get configmap bridge-release ci-notification-bridge-ci-main ci-notification-bridge-ci-feature -n starfleet -o custom-columns='NAME:.metadata.name,DATA:.data'
```

`bridge-ci-main` ends with `Succeeded`, `bridge-ci-feature` with `Completed` and `deploy` skipped. In the main run, `lint`, `test` (two TaskRuns, `-0` and `-1`) and `scan` start right after `clone`, `build` after the last of them, and `deploy` after `build`. The registry has two tags, one per branch commit. `bridge-release` names the image of `main` with its digest, and the two notifications say `Succeeded`/`Succeeded` and `Completed`/`None`.

The grader also tries the branch `broken`. You can do the same with a run that gets a generated name.

Save this as `pipelinerun-bridge-ci-broken.yaml`:

```yaml
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  generateName: bridge-ci-broken-
  namespace: starfleet
spec:
  pipelineRef:
    name: bridge-ci
  params:
    - name: branch
      value: broken
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

Create it (`kubectl apply` does not accept `generateName`) and follow it:

```sh
kubectl create -f pipelinerun-bridge-ci-broken.yaml
tkn pipelinerun logs --last -f -n starfleet
```

ShellCheck rejects `scripts/cleanup.sh`, `lint` fails, `build` and `deploy` are skipped with `PipelineRun was stopping`, and the ConfigMap `ci-notification-<run>` says `status: Failed`, `deploy: None`.

## Step 5: Submit

```sh
astrona submit -c sections/section-030/module-01/labs/lab-01
```

## Why the obvious shortcuts are wrong

| Shortcut | What happens |
| --- | --- |
| Two pipeline tasks `test-busybox` and `test-alpine` instead of a matrix | The grader looks for the TaskRuns of the pipeline task `test` with both images |
| `build` with `runAfter: [lint]` only | `build` can start before the tests and the scan end; the grader compares the times |
| `notify` with `detail: $(tasks.build.results.IMAGE_URL)` | On `broken`, `build` never runs, so `notify` is skipped with `Results were missing` and nobody hears about the failure |
| `operator: notin` with `values: [feature/banner]` | Every other branch, `broken` included, would deploy if its checks passed |
| Runs without `taskRunTemplate.serviceAccountName: ci-bot` | `deploy` and `notify` run as `default` and are forbidden to write ConfigMaps |

## Common mistakes

- Expecting one TaskRun named `bridge-ci-main-test`. A matrix adds an index: `-test-0` and `-test-1`.
- Reading `Completed` on the feature run as a failure. It means success with a skipped task.
- Running a second run on `main` and expecting a second tag. The tag is the commit, and `main` did not change.

## Practice on your own

- Add `alpine:3.22.7` with a second shell to the matrix through `matrix.include` and see how many test TaskRuns you get.
- Add a pipeline result `image` with the value `$(tasks.build.results.IMAGE_URL)@$(tasks.build.results.IMAGE_DIGEST)` and read it from both runs.
- Commit `token = abc` to a new branch in Gitea and run the Pipeline on it. Which task fails now?
