# Fan Out A Task With A Matrix

The tests of the `bridge` application are shell scripts, and the team ships them on two base images with two different shells: the one in `busybox` and the one in `alpine`. Both must pass. You could copy the test pipeline task once per image, but every new image would mean another copy, and copies drift apart. A `matrix` solves this: one pipeline task, a list of values, and Tekton creates one TaskRun per value. This part fans a Task out over images and crew names, adds one special combination, and collects the results.

## One pipeline task, many TaskRuns

A `matrix` sits on a pipeline task, next to `params`. Under `matrix.params`, each parameter gets a list of values instead of one value. The tekton-pipelines-controller builds every combination of those lists and creates one TaskRun for each. The parameter names must match parameters of the Task, and a parameter can be in `params` or in `matrix`, not in both. Matrix is a beta feature; the default `enable-api-fields: "beta"` in v1.17.1 already allows it.

The Task `greet-crew` below takes a crew name, an image and a deck. Its step uses the image from the parameter, so each TaskRun can run in a different image.

<!-- astrona:playground:renew -->

Save this as `task-greet-crew.yaml`:

```yaml
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: greet-crew
  namespace: starfleet
spec:
  params:
    - name: crew
      type: string
    - name: image
      type: string
    - name: deck
      type: string
      default: main deck
  results:
    - name: greeting
  steps:
    - name: greet
      image: $(params.image)
      script: |
        #!/bin/sh
        printf '%s on the %s, from %s' "$(params.crew)" "$(params.deck)" "$(params.image)" | tee "$(results.greeting.path)"
```

The Pipeline `crew-matrix` fans `greet` out over two crew names and two images, and adds one more combination with `matrix.include`. A second task, `summarize`, takes all greetings at once.

Save this as `pipeline-crew-matrix.yaml`:

```yaml
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: crew-matrix
  namespace: starfleet
spec:
  tasks:
    - name: greet
      taskRef:
        name: greet-crew
      matrix:
        params:
          - name: crew
            value:
              - bridge
              - scout
          - name: image
            value:
              - busybox:1.37.0
              - alpine:3.22.7
        include:
          - name: probe-on-lower-deck
            params:
              - name: crew
                value: probe
              - name: image
                value: busybox:1.37.0
              - name: deck
                value: lower deck
    - name: summarize
      params:
        - name: greetings
          value: $(tasks.greet.results.greeting[*])
        - name: count
          value: $(tasks.greet.matrix.length)
      taskSpec:
        params:
          - name: greetings
            type: array
          - name: count
            type: string
        steps:
          - name: summarize
            image: busybox:1.37.0
            args:
              - $(params.greetings[*])
            script: |
              #!/bin/sh
              echo "$(params.count) greetings:"
              for greeting in "$@"; do
                echo "- $greeting"
              done
```

Apply both and start the Pipeline:

```sh
kubectl apply -f task-greet-crew.yaml -f pipeline-crew-matrix.yaml
tkn pipeline start crew-matrix -n starfleet --prefix-name crew-matrix --showlog
```

## Count the combinations

`matrix.params` makes 2 × 2 = 4 combinations. The `include` entry sets `crew` to `probe`, a value that none of the four combinations has, so it cannot be added to one of them without changing a value. Tekton adds it as a fifth combination of its own, with the extra parameter `deck`. If an `include` entry only added a new parameter, for example `deck` for every combination with `image: alpine:3.22.7`, Tekton would add it to those combinations instead of creating new ones.

List the TaskRuns of the run, with their parameters. Use the run name from `tkn pipelinerun list -n starfleet` in place of `<RUN>`:

```sh
kubectl get taskruns -n starfleet -l tekton.dev/pipelineRun=<RUN>,tekton.dev/pipelineTask=greet -o custom-columns='NAME:.metadata.name,PARAMS:.spec.params[*].value,REASON:.status.conditions[0].reason'
kubectl get pipelinerun <RUN> -n starfleet -o jsonpath='{range .status.childReferences[*]}{.pipelineTaskName}{" "}{.name}{" "}{.displayName}{"\n"}{end}'
```

There are five TaskRuns for `greet`, named `<RUN>-greet-0` to `<RUN>-greet-4`: a matrix adds the index of the combination to the usual `<pipelinerun>-<pipeline task>` name. They ran in parallel, each in its own pod, two of them in the `alpine` image. In `childReferences`, the combination from `include` carries its `name`, `probe-on-lower-deck`, as its display name, which is how a user interface can show it.

## Results of a matrix

A matrixed task cannot give one string result, because it ran five times. Tekton collects the string result `greeting` of all five TaskRuns into one array, and another task consumes it whole with `$(tasks.greet.results.greeting[*])`, into a parameter of type `array`. You cannot pick one element of it, and a whole array cannot appear inside a `script`; that is why `summarize` passes it as `args` and loops over `"$@"`. `$(tasks.greet.matrix.length)` gives the number of TaskRuns, here `5`. The log of `summarize` lists the five greetings, one per line.

A matrix has a few more rules. It works on `finally` tasks too. `retries` applies to each TaskRun of the matrix on its own. If one combination fails, the pipeline task has failed, and the run stops like after any other failure. If a matrix parameter gets an empty array, the pipeline task is skipped with the reason `Matrix Parameters have an empty array`. And there is an upper limit, 256 combinations by default, set by `default-max-matrix-combinations-count` in `config-defaults`; a Pipeline above it fails validation.

You can now run one Task over a list of images or values, add special combinations, and use the results of all of them. The open question is where Tasks come from: so far every Task lived in `starfleet`, but a team often shares Tasks across namespaces or keeps them in Git.

## Common pitfalls

> [!WARNING]
> - **Putting the same parameter in `params` and in `matrix`.** The webhook rejects it; a parameter goes in one of the two.
> - **Expecting one result from a matrixed task.** Its string results become an array; consume them with `[*]` into an `array` parameter.
> - **Using a whole array in a `script`.** It is not allowed; pass it through `args` and loop over `"$@"`.
> - **Misnaming a matrix parameter.** It must match a Task parameter; a Task parameter without a default that gets no value fails the run with `PipelineValidationFailed`.
> - **Forgetting that combinations multiply.** Three lists of four values make 64 TaskRuns.
