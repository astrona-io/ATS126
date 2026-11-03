# Solution: Share A Task And A Pipeline With The Cluster Resolver

Work the task yourself first. Running `astrona submit -c sections/section-030/module-02/labs/lab-01` after a step tells you which checks pass, without telling you what is left.

The grader checks four things: the Pipeline `flow` asks for the right object, `flow-run` ran and reported `announce: ready`, `release-run` resolved `release-flow` and reported `deploy prod`, and a new run of `flow` with another message works.

## Step 1: Find the fault

Start a run and read the failure:

```sh
kubectl create -f - <<'YAML'
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  generateName: probe-
  namespace: starfleet
spec:
  pipelineRef:
    name: flow
  params:
    - name: message
      value: test
YAML
kubectl get pipelineruns -n starfleet
```

Replace `<PROBE>` below with the generated name from the list:

```sh
kubectl get pipelinerun <PROBE> -n starfleet -o jsonpath='{.status.conditions[0].reason}: {.status.conditions[0].message}{"\n"}'
kubectl get resolutionrequests -n starfleet
```

The reason is `CouldntGetTask`, and the message says the Task `announce` was not found in the namespace `ci-catlog`. There are no TaskRuns. Compare the namespace in the message with the real one:

```sh
kubectl get tasks -A | grep announce
```

The Task is in `ci-catalog`. The Pipeline has a typo.

## Step 2: Fix the Pipeline

Save this as `pipeline-flow.yaml`:

```yaml
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: flow
  namespace: starfleet
spec:
  params:
    - name: message
      type: string
  results:
    - name: line
      value: $(tasks.call.results.line)
  tasks:
    - name: call
      params:
        - name: message
          value: $(params.message)
      taskRef:
        resolver: cluster
        params:
          - name: kind
            value: task
          - name: name
            value: announce
          - name: namespace
            value: ci-catalog
```

Apply it:

```sh
kubectl apply -f pipeline-flow.yaml
```

## Step 3: Run flow

Save this as `pipelinerun-flow-run.yaml`:

```yaml
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  name: flow-run
  namespace: starfleet
spec:
  pipelineRef:
    name: flow
  params:
    - name: message
      value: ready
```

Apply it, wait and read the result:

```sh
kubectl apply -f pipelinerun-flow-run.yaml
kubectl wait --for=condition=Succeeded pipelinerun/flow-run -n starfleet --timeout=300s
kubectl get pipelinerun flow-run -n starfleet -o jsonpath='{.status.results[0].value}{"\n"}'
```

The result is `announce: ready`.

## Step 4: Run the shared Pipeline

Save this as `pipelinerun-release-run.yaml`. The resolver parameters belong to `pipelineRef` this time, and the value of `kind` is `pipeline`:

```yaml
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  name: release-run
  namespace: starfleet
spec:
  params:
    - name: target
      value: prod
  pipelineRef:
    resolver: cluster
    params:
      - name: kind
        value: pipeline
      - name: name
        value: release-flow
      - name: namespace
        value: ci-catalog
```

Apply it and read the result:

```sh
kubectl apply -f pipelinerun-release-run.yaml
kubectl wait --for=condition=Succeeded pipelinerun/release-run -n starfleet --timeout=300s
kubectl get pipelinerun release-run -n starfleet -o jsonpath='{.status.results[0].value}{"\n"}'
kubectl get pods -n starfleet -l tekton.dev/pipelineRun=release-run
```

The result is `deploy prod`, and the pod is in `starfleet`. The catalog supplied only the definition.

## Step 5: Submit

```sh
astrona submit -c sections/section-030/module-02/labs/lab-01
```

## Why the obvious shortcuts are wrong

| Shortcut | What happens |
| --- | --- |
| Copy `announce` into `starfleet` and use `taskRef.name` | The constraint forbids copying, and the Pipeline must keep the resolver |
| Embed the steps of `announce` in `flow` | The grader checks the resolver parameters |
| Edit the Task in `ci-catalog` | The catalog must stay as it is |
| Write the result file `line` by hand | The grader runs `flow` again with another message |

## Common mistakes

- Writing `kind: Task` with a capital letter. The value is `task`.
- Putting the resolver on the run for step 3. `flow-run` uses a local `pipelineRef` by name; only `release-run` uses the resolver.
- Applying a corrected Pipeline and waiting for the failed run to retry. A finished run does not retry; create a new one.

## Practice on your own

- Set `allowed-namespaces` in the ConfigMap `cluster-resolver-config` to a namespace other than `ci-catalog` and watch both runs fail. Restore the ConfigMap afterwards.
- Read the `ResolutionRequest` of `release-run` with `-o yaml`.
- Add a task with `taskRef` by name to a copy of `release-flow` and see where the name is looked up.
