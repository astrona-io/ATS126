# Per-Task Overrides And Resources

One setting for the whole run is too coarse when one task is different. A build step needs more memory than a lint step, and a task that talks to a registry needs a pull secret that the others do not. The field `taskRunSpecs` of a `PipelineRun` holds an override for each pipeline task, and `computeResources` sets the CPU and memory of its steps. This part writes an override and explains how Tekton turns step resources into pod resources.

## The field taskRunSpecs

`spec.taskRunSpecs` is a list. Each entry names a pipeline task with `pipelineTaskName` and may set:

- `podTemplate`, which replaces the same part of `taskRunTemplate.podTemplate` for this task.
- `computeResources`, the CPU and memory requests and limits for all steps of the task.
- `stepSpecs`, `computeResources` for one named step.
- `sidecarSpecs`, `computeResources` for one named sidecar.
- `metadata`, labels and annotations for the TaskRun.

The name is the name of the pipeline task, not the name of the Task it refers to.

## Give one task a memory limit

<!-- astrona:playground:renew -->

Save this as `pipeline-two-weights.yaml`:

```yaml
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: two-weights
  namespace: starfleet
spec:
  tasks:
    - name: light
      taskSpec:
        steps:
          - name: work
            image: busybox:1.37.0
            script: |
              #!/bin/sh
              echo "light task"
    - name: heavy
      runAfter:
        - light
      taskSpec:
        steps:
          - name: work
            image: busybox:1.37.0
            script: |
              #!/bin/sh
              echo "heavy task"
```

Save this as `pipelinerun-two-weights-1.yaml`:

```yaml
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  name: two-weights-1
  namespace: starfleet
spec:
  pipelineRef:
    name: two-weights
  taskRunSpecs:
    - pipelineTaskName: heavy
      computeResources:
        requests:
          cpu: 100m
          memory: 64Mi
        limits:
          memory: 128Mi
      metadata:
        labels:
          weight: heavy
```

Apply both and wait:

```sh
kubectl apply -f pipeline-two-weights.yaml -f pipelinerun-two-weights-1.yaml
kubectl wait --for=condition=Succeeded pipelinerun/two-weights-1 -n starfleet --timeout=180s
```

Read the two TaskRuns:

```sh
kubectl get taskrun two-weights-1-light -n starfleet -o jsonpath='{.spec.computeResources}{"\n"}'
kubectl get taskrun two-weights-1-heavy -n starfleet -o jsonpath='{.spec.computeResources}{"\n"}{.metadata.labels.weight}{"\n"}'
```

The first command prints nothing, because `light` has no override. The second prints the requests and limits and the label `heavy`. The override reached only the task you named.

## From step resources to pod resources

A pod normally runs its containers at the same time and adds their requests. The steps of a Task run one after the other, so Tekton does not add them. When a Task has several steps, the controller keeps the largest request of any step as the request of the pod and sets the requests of the other steps to zero. Limits stay as you wrote them, step by step. A request of zero for a step does not mean it can use unlimited resources; the limit still applies.

You can see the effect in the pod of `heavy`. The container of its single step has the request and the limit you set. If the Task had three steps, only the largest request would remain on the pod.

A `computeResources` value on a `TaskRun` replaces the `computeResources` of the Task steps for that run. If you name a step with `stepSpecs`, that step uses its own value and the others use the task value.

## LimitRange and the defaults of a namespace

A `LimitRange` in the namespace gives containers a default request and limit when they set none, and rejects containers outside its minimum and maximum. Tekton pods follow the same rules. A step without resources gets the defaults, and a step whose limit is above the maximum makes the pod creation fail. The fix is on the run or in the namespace, not in Tekton.

## Common pitfalls

> [!WARNING]
> - **Using the Task name in `pipelineTaskName`.** Use the name of the pipeline task in the Pipeline.
> - **Misspelling `pipelineTaskName`.** Read the resulting TaskRun spec to see whether the entry reached the task.
> - **Adding the requests of all steps by hand.** Tekton keeps only the largest, so the pod needs less than the sum.
> - **Setting a limit smaller than the request.** The API server rejects the pod.
> - **Forgetting that a limit below real use kills the step.** A step that goes over its memory limit ends with `OOMKilled`.
