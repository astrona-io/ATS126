# Parameter Types And Defaults

A Pipeline is useful when the same definition runs with different input. The input arrives as parameters, and a parameter is more than a string. A list of crew members is an array. The settings of a release, such as a name and a deck, are an object. If you flatten both into one string, every Task has to split the string again, and every typo hides inside the text. This part declares parameters of the three types, passes them through a Pipeline, and reads what Tekton says when a value has the wrong shape.

## Three types and where they work

A parameter has a `name`, a `type` and an optional `default` and `description`. The type is `string` unless you write another one. An `array` parameter holds a list of strings. An `object` parameter holds named string values; you list its keys under `properties`, and each key has a `type` of `string`.

The variable you write depends on the type. `$(params.title)` reads a string. `$(params.crew[0])` reads one element of an array and works anywhere a string works. `$(params.crew[*])` expands the whole array, and Tekton allows it only where a list belongs: in `command`, in `args`, or as the value of an array parameter. `$(params.ship.name)` reads one key of an object. `$(params.ship[*])` hands the whole object to another object parameter.

The Task below uses all three types. Its first step receives the array through `args`. Its second step reads single elements and keys inside a script.

<!-- astrona:playground:renew -->

Save this as `task-show-crew.yaml`:

```yaml
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: show-crew
  namespace: starfleet
spec:
  params:
    - name: title
      type: string
      default: Crew
    - name: crew
      type: array
    - name: ship
      type: object
      properties:
        name:
          type: string
        deck:
          type: string
  steps:
    - name: list
      image: busybox:1.37.0
      command:
        - echo
      args:
        - "$(params.title):"
        - "$(params.crew[*])"
    - name: first
      image: busybox:1.37.0
      script: |
        #!/bin/sh
        echo "First crew member: $(params.crew[0])"
        echo "Ship $(params.ship.name) on deck $(params.ship.deck)"
```

Save this as `pipeline-roll-call.yaml`. The Pipeline gives defaults to both of its parameters and passes them on:

```yaml
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: roll-call
  namespace: starfleet
spec:
  params:
    - name: crew
      type: array
      default:
        - bridge
        - scout
    - name: ship
      type: object
      properties:
        name:
          type: string
        deck:
          type: string
      default:
        name: shuttle
        deck: "2"
  tasks:
    - name: call
      taskRef:
        name: show-crew
      params:
        - name: crew
          value:
            - "$(params.crew[*])"
        - name: ship
          value: $(params.ship[*])
```

Apply both and run the Pipeline with its defaults:

```sh
kubectl apply -f task-show-crew.yaml -f pipeline-roll-call.yaml
tkn pipeline start roll-call -n starfleet --use-param-defaults --prefix-name roll-default --showlog
```

The flag `--use-param-defaults` tells `tkn` to use the default of every parameter that has one and not to ask for a value. The step `list` prints the title and the two default crew names on one line. The step `first` prints the first crew member and the ship `shuttle` on deck `2`. The title `Crew` came from the default in the Task, because the Pipeline never passes `title`.

## Give your own values in a PipelineRun

A `PipelineRun` writes an array as a YAML list and an object as a YAML mapping. Every key of the object that has no default must be present.

Save this as `pipelinerun-roll-call-1.yaml`:

```yaml
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  name: roll-call-1
  namespace: starfleet
spec:
  pipelineRef:
    name: roll-call
  params:
    - name: crew
      value:
        - probe
        - drifter
        - outpost-guard
    - name: ship
      value:
        name: scout
        deck: "4"
```

Apply it and read the logs of the two steps:

```sh
kubectl apply -f pipelinerun-roll-call-1.yaml
kubectl wait --for=condition=Succeeded pipelinerun/roll-call-1 -n starfleet --timeout=180s
kubectl logs roll-call-1-call-pod -n starfleet -c step-list
kubectl logs roll-call-1-call-pod -n starfleet -c step-first
```

The first log lists three names, and the second shows `probe` and the ship `scout` on deck `4`. The array arrived as three separate arguments, not as one string, because `args` takes a list and the controller expanded the array into it.

## What a wrong shape looks like

The controller checks the type of every value against the declaration before it creates a TaskRun, and it reports the problem as the reason of the `Succeeded` condition. Three reasons are worth knowing by name. `ParameterMissing` means a parameter without a default got no value. `ParameterTypeMismatch` means the value has another shape than the declaration, for example a string for an array. `ObjectParameterMissKeys` means an object value lacks a key from `properties` that has no default.

Try the second one. This run gives a plain string where `crew` expects an array.

Save this as `pipelinerun-roll-call-bad.yaml`:

```yaml
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  name: roll-call-bad
  namespace: starfleet
spec:
  pipelineRef:
    name: roll-call
  params:
    - name: crew
      value: probe
```

Apply it and read the condition:

```sh
kubectl apply -f pipelinerun-roll-call-bad.yaml
kubectl get pipelinerun roll-call-bad -n starfleet -o jsonpath='{.status.conditions[0].reason}{"\n"}{.status.conditions[0].message}{"\n"}'
kubectl get taskruns -n starfleet -l tekton.dev/pipelineRun=roll-call-bad
```

The reason is `ParameterTypeMismatch` and the message names the parameter `crew`. The last command finds no TaskRun: the run failed before any existed. The webhook could not catch this at apply time, because it validates the `PipelineRun` alone and only the controller knows the declaration of the Pipeline.

Parameters can also carry an `enum`, a list of allowed values that Tekton checks for you. Enum parameters are a beta feature and need the feature flag `enable-api-fields` set to `beta`; this course does not use them in its labs.

You can now declare and pass the three parameter types, and you can read the reasons when a value has the wrong shape. The next question is what other values Tekton substitutes besides your own parameters, and how a Task can learn the name of the run it belongs to.

## Common pitfalls

> [!WARNING]
> - **Using `$(params.crew[*])` inside a `script`.** A whole array is allowed only in `command`, `args` and array parameters. In a script, use an index, or pass the array in `args` and loop over `"$@"`.
> - **Passing a string where the declaration says array.** The apply works, and the run then fails with `ParameterTypeMismatch`.
> - **Forgetting a key of an object.** A key of `properties` without a default must have a value, or the run fails with `ObjectParameterMissKeys`.
> - **Writing a number as an object value.** All values of an object are strings. Quote `"2"` and `"4"`.
> - **Declaring an object without `properties`.** The controller needs the keys to check the value and to resolve `$(params.ship.name)`.
