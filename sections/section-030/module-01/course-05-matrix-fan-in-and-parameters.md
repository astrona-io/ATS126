# Matrix Fan-In And Matrix Parameters

A matrix is useful when its values come from outside the Pipeline and when its results are used afterwards. This part shows three things: how a `PipelineRun` supplies the values of a matrix, how a later task counts and reads what the matrix produced, and what happens to the graph when one combination fails.

## Values from the PipelineRun

The values of `matrix.params` do not have to be written into the Pipeline. A Pipeline parameter of type `array` can fill one. The Pipeline stays the same, and each `PipelineRun` decides which images or targets to test.

<!-- astrona:playground:renew -->

Save this as `pipeline-test-images.yaml`:

```yaml
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: test-images
  namespace: starfleet
spec:
  params:
    - name: images
      type: array
      default:
        - busybox:1.37.0
  tasks:
    - name: probe
      matrix:
        params:
          - name: image
            value: $(params.images[*])
      params:
        - name: image
          value: $(matrix.image)
      taskSpec:
        params:
          - name: image
            type: string
        results:
          - name: seen
        steps:
          - name: probe
            image: $(params.image)
            script: |
              #!/bin/sh
              printf '%s' "$(params.image)" | tee $(results.seen.path)
    - name: count
      runAfter:
        - probe
      params:
        - name: total
          value: $(tasks.probe.matrix.length)
        - name: seen
          value: $(tasks.probe.results.seen[*])
      taskSpec:
        params:
          - name: total
            type: string
          - name: seen
            type: array
        steps:
          - name: count
            image: busybox:1.37.0
            args: ["$(params.seen[*])"]
            env:
              - name: TOTAL
                value: $(params.total)
            script: |
              #!/bin/sh
              echo "TaskRuns in the matrix: $TOTAL"
              for s in "$@"; do echo "saw $s"; done
```

Apply it and run it with two images:

```sh
kubectl apply -f pipeline-test-images.yaml
tkn pipeline start test-images -n starfleet --prefix-name images -p images=busybox:1.37.0,alpine:3.22.7 --showlog
```

The matrix has one parameter with two values, so it makes two TaskRuns. The log of `count` reports two and lists both image names. Starting the same Pipeline without `-p images` uses the default and makes one TaskRun. The array is expanded with `[*]`, as with any array parameter, and a matrix parameter cannot receive a single string.

## Counts of results

Besides `$(tasks.<task>.matrix.length)`, which counts the TaskRuns, Tekton offers `$(tasks.<task>.matrix.<result>.length)`. It gives the total length of the results named `<result>` across all TaskRuns. For string results it equals the number of TaskRuns. The variables are available to the pipeline tasks that come after the matrix, and they cannot be used in the matrix task itself.

A result of a matrixed task is an array. A later task can pass that array to a parameter of type `array`, as `count` does, but it cannot pick one element. The element order follows the index of the combination, which is stable for one `PipelineRun`.

## When one combination fails

Each combination is a TaskRun. If one of them fails, the matrix task fails, the other TaskRuns still finish, and tasks that depend on the matrix are not started. Their result is then `Failed` for the task, and the run ends after its `finally` tasks. Use `retries` on the matrix task to retry only the failed TaskRun, and use `onError: continue` only when a failing combination is acceptable.

After a failed run, list the TaskRuns of the matrix task and compare their reasons:

```sh
kubectl get taskruns -n starfleet -l tekton.dev/pipelineTask=probe -o custom-columns='NAME:.metadata.name,REASON:.status.conditions[0].reason'
```

You can now feed a matrix from a `PipelineRun`, use its count and results, and predict how a failed combination affects the rest of the run.

## Common pitfalls

> [!WARNING]
> - **Passing a string to a matrix parameter.** The value must be an array, written with `[*]` for a Pipeline array parameter.
> - **Using `$(matrix.image)` outside the pipeline task's `params`.** The variable is available there only.
> - **Using one element of a matrix result.** The result is a whole array; indexing it is not supported.
> - **Expecting the other combinations to stop when one fails.** They run to the end.
> - **Reading `matrix.length` in the matrix task itself.** Only later tasks can use it.
