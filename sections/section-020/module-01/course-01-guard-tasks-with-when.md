# Guard Tasks With when Expressions

The same Pipeline usually runs for many branches. Every branch should be built and tested, but only `main` should be deployed. You could write two Pipelines, or put an `if` into the deploy script, but then the deploy TaskRun still starts, and nobody can see from the run whether it deployed or not. A `when` expression is the Tekton answer: a guard on a pipeline task that the controller checks before it creates the TaskRun. This part guards a deploy, shows what Tekton records when it skips a task, and shows what happens to the tasks after it.

## A guard on the deploy task

A `when` expression has three fields. `input` is a value, usually a parameter or a result. `operator` is `in` or `notin`. `values` is a list of strings. The expression is true when `input` is (or is not) one of the `values`. A pipeline task can have several expressions under `when`, and it runs only when all of them are true.

The Pipeline `gate` below has four tasks with embedded `taskSpec`s. `build` publishes an image name. `deploy` is guarded: it runs only when the parameter `branch` is `main`. `smoke` runs after `deploy` with `runAfter`. `announce` uses the result `url` of `deploy`.

<!-- astrona:playground:renew -->

Save this as `pipeline-gate.yaml`:

```yaml
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: gate
  namespace: starfleet
spec:
  params:
    - name: branch
      type: string
  tasks:
    - name: build
      taskSpec:
        results:
          - name: image
        steps:
          - name: build
            image: busybox:1.37.0
            script: |
              #!/bin/sh
              printf 'gate:%s' "$(echo '$(params.branch)' | tr '/' '-')" > "$(results.image.path)"
    - name: deploy
      when:
        - input: $(params.branch)
          operator: in
          values:
            - main
      params:
        - name: image
          value: $(tasks.build.results.image)
      taskSpec:
        params:
          - name: image
        results:
          - name: url
        steps:
          - name: deploy
            image: busybox:1.37.0
            script: |
              #!/bin/sh
              echo "Deploying $(params.image)"
              printf 'http://gate.starfleet.example' > "$(results.url.path)"
    - name: smoke
      runAfter:
        - deploy
      taskSpec:
        steps:
          - name: smoke
            image: busybox:1.37.0
            script: |
              #!/bin/sh
              echo "Smoke test ran"
    - name: announce
      params:
        - name: url
          value: $(tasks.deploy.results.url)
      taskSpec:
        params:
          - name: url
        steps:
          - name: announce
            image: busybox:1.37.0
            script: |
              #!/bin/sh
              echo "Released at $(params.url)"
```

Apply it and run it for `main`:

```sh
kubectl apply -f pipeline-gate.yaml
tkn pipeline start gate -n starfleet -p branch=main --prefix-name gate-main --showlog
```

All four tasks run. The `when` expression of `deploy` is true, so the controller creates its TaskRun like any other, and `announce` gets the `url` result.

## What a skipped task leaves behind

Now run the same Pipeline for a feature branch:

```sh
tkn pipeline start gate -n starfleet -p branch=feature/radar --prefix-name gate-feature --showlog
```

Then read the status of that run. Copy its name from `tkn pipelinerun list -n starfleet` and use it in place of `<RUN>`:

```sh
kubectl get pipelinerun <RUN> -n starfleet -o jsonpath='{.status.conditions[0].reason}{"\n"}{range .status.skippedTasks[*]}{.name}{": "}{.reason}{"\n"}{end}'
kubectl get taskruns -n starfleet -l tekton.dev/pipelineRun=<RUN> -o custom-columns='TASK:.metadata.labels.tekton\.dev/pipelineTask,REASON:.status.conditions[0].reason'
```

The run ends with `Succeeded` `True` and the reason `Completed`, not `Succeeded`. Tekton uses `Completed` when every task that ran succeeded and at least one task was skipped. Two tasks are under `skippedTasks`:

- `deploy`, with the reason `When Expressions evaluated to false`. The list also repeats its `when` expressions with the values filled in, so you can see that `feature/radar` was compared with `main`.
- `announce`, with the reason `Results were missing`. It needs the result `url` of `deploy`, and that result does not exist.

`smoke`, on the other hand, has a TaskRun and succeeded. This is the rule to remember: a task skipped by its own `when` expressions does not stop the tasks that only `runAfter` it. Tasks that need its results are skipped, and so are the tasks that depend on those. If a whole branch of the graph must stop together, put the same `when` expression on each task of the branch.

## Guards on results

The `input` can also be a result of an earlier task, such as `$(tasks.check.results.changed)`. A `when` expression that uses a result is a resource dependency, just like a parameter that uses one: the guarded task waits for the task that produces the result. This lets a Pipeline decide at run time, for example "build the image only if the Dockerfile changed". `values` can hold variables too, and an array parameter written as `["$(params.allowed[*])"]` expands to all of its items.

## CEL expressions behind a feature flag

The `in` and `notin` operators only compare strings. For patterns, numbers or `||`, Tekton accepts a Common Expression Language (CEL) string instead, in the field `cel`. CEL in `when` is an alpha feature in v1.17.1. It is off by default and needs only one flag in the ConfigMap `feature-flags`:

```sh
kubectl patch configmap feature-flags -n tekton-pipelines --type merge -p '{"data":{"enable-cel-in-whenexpression":"true"}}'
```

With the flag on, a guard such as "run only for release branches" becomes one line. Variables must sit inside single quotes, because Tekton replaces them as text before CEL reads the expression.

Save this as `pipeline-release-gate.yaml`:

```yaml
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: release-gate
  namespace: starfleet
spec:
  params:
    - name: branch
      type: string
  tasks:
    - name: tag-release
      when:
        - cel: "'$(params.branch)'.matches('^release/.*')"
      taskSpec:
        steps:
          - name: tag
            image: busybox:1.37.0
            script: |
              #!/bin/sh
              echo "Tagging $(params.branch)"
```

Apply it and run it twice:

```sh
kubectl apply -f pipeline-release-gate.yaml
tkn pipeline start release-gate -n starfleet -p branch=release/1.2 --showlog
tkn pipeline start release-gate -n starfleet -p branch=main --showlog
```

The first run tags; the second ends `Completed` with `tag-release` skipped. Without the flag, the webhook rejects the Pipeline at `kubectl apply` and says that the feature flag `enable-cel-in-whenexpression` should be set to true. A CEL expression that does not compile is also rejected at apply time, and one that fails at run time ends the run with the reason `CELEvaluationFailed`.

You can now guard any task on a parameter or a result, read which tasks Tekton skipped and why, and predict which tasks after a skipped one still run. The open question is how to run work that must happen at the end of every run, including runs where a task failed and everything after it was skipped.

## Common pitfalls

> [!WARNING]
> - **Expecting a guard to stop the whole branch.** Only tasks that use the skipped task's results are skipped. Tasks with `runAfter` alone still run.
> - **Reading `Completed` as a failure.** `Completed` means success with at least one skipped task; the condition is `True`.
> - **Writing `notin` when you mean `in`.** The run still succeeds, so nothing tells you the guard is upside down except the skipped list.
> - **Using CEL without the flag, or without quotes.** Without `enable-cel-in-whenexpression` the webhook rejects the Pipeline; `$(params.x)` must be written as `'$(params.x)'`.
> - **Guarding inside the script.** An `if` in a step hides the decision; the TaskRun still runs and looks the same in both cases.
