# Tracing A Parameter From Run To Step

A wrong value rarely shows where it was made. A parameter passes through up to four objects: the `PipelineRun`, the Pipeline, the TaskRun and the pod. This part traces one value through all four, so that you can find the layer where it changed.

## The path of one value

<!-- astrona:playground:renew -->

Save this as `pipeline-trace.yaml`:

```yaml
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: trace
  namespace: starfleet
spec:
  params:
    - name: crew
      type: array
    - name: ship
      type: object
      properties:
        name: {type: string}
        deck: {type: string}
  tasks:
    - name: show
      params:
        - name: members
          value: $(params.crew[*])
        - name: label
          value: "$(params.ship.name)/$(params.ship.deck)"
      taskSpec:
        params:
          - name: members
            type: array
          - name: label
            type: string
        steps:
          - name: print
            image: busybox:1.37.0
            args: ["$(params.members[*])"]
            env:
              - name: LABEL
                value: $(params.label)
            script: |
              #!/bin/sh
              echo "label: $LABEL"
              for m in "$@"; do echo "member: $m"; done
```

Save this as `pipelinerun-trace.yaml`. A YAML file is the clearest way to give an array and an object:

```yaml
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  name: trace-1
  namespace: starfleet
spec:
  pipelineRef:
    name: trace
  params:
    - name: crew
      value:
        - ada
        - grace
    - name: ship
      value:
        name: enterprise
        deck: "7"
```

Apply both and read the log:

```sh
kubectl apply -f pipeline-trace.yaml -f pipelinerun-trace.yaml
kubectl wait --for=condition=Succeeded pipelinerun/trace-1 -n starfleet --timeout=120s
tkn pipelinerun logs trace-1 -n starfleet
```

The log shows the label `enterprise/7` and two members. Now look at each layer:

```sh
kubectl get pipelinerun trace-1 -n starfleet -o jsonpath='{.spec.params}{"\n"}'
kubectl get taskrun trace-1-show -n starfleet -o jsonpath='{.spec.params}{"\n"}'
kubectl get pod trace-1-show-pod -n starfleet -o jsonpath='{.spec.containers[0].args}{"\n"}'
```

The first command prints the values as the run received them. The second prints the TaskRun parameters after the Pipeline mapped them: `members` is the whole array and `label` is the one text built from two object keys. The third prints the container arguments, where the array has become separate arguments. Each command answers one question: did the value arrive, did the Pipeline pass it correctly, did the step get what it expected.

## Where each form works

- A string parameter works anywhere text is allowed: scripts, args, env, other parameters, and workspace subPath.
- An array parameter works as a whole item with `[*]` in `args`, `command` and in array parameters. Indexing with `[0]` works for one element. It does not work inside a script.
- An object parameter works as `$(params.name.key)` for one key. Referencing the whole object with `[*]` is not allowed for a string field.

Use this table when a value does not arrive, because the failure is often a form used in the wrong place.

## Find the layer

| Symptom | First place to look |
| --- | --- |
| The run fails before TaskRuns | The condition of the `PipelineRun`; the reason names the parameter problem |
| The TaskRun has the wrong value | The `params` mapping of the pipeline task |
| The pod has the right value but the step prints wrong | The step: env or script text |

You can now trace a value layer by layer and name the layer that broke it.

## Common pitfalls

> [!WARNING]
> - **Reading the log first.** The log shows the end of the chain only.
> - **Using an array inside a script.** Pass it as `args` and loop over `"$@"`.
> - **Building a text from an array.** Only strings and object keys can be joined into text.
> - **Mixing up the pipeline task parameter and the Task parameter.** Each side declares its own names.
