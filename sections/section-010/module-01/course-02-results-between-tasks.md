# Pass Results Between Tasks And Out Of The Pipeline

Files in a workspace are good for source code and build output. Many values that tasks exchange are small, though: a commit hash, an image digest, a version number, a count. Writing such a value to a file and reading it back in the next task works, but it hides the dependency in a script. Tekton has a better way. A task can publish a result, and another task can take that result as a parameter. This part passes a result through a Pipeline and then publishes a result of the whole Pipeline.

## A result becomes a parameter

A Task declares results under `spec.results`, and a step writes the value to the file `$(results.<name>.path)`. Inside a `Pipeline`, another pipeline task reads that value with the variable `$(tasks.<pipeline task>.results.<result>)`. Note the first name: it is the name of the pipeline task in this Pipeline, not the name of the Task.

The two Tasks below show it. `pick-crew` chooses the first name from a list and publishes it as the result `captain`. `announce` takes a parameter `name` and publishes the result `message`.

<!-- astrona:playground:renew -->

Save this as `task-pick-crew.yaml`:

```yaml
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: pick-crew
  namespace: starfleet
spec:
  params:
    - name: crew
      type: string
  results:
    - name: captain
      description: The first name of the crew list
  steps:
    - name: pick
      image: busybox:1.37.0
      script: |
        #!/bin/sh
        set -eu
        set -- $(params.crew)
        printf '%s' "$1" | tee "$(results.captain.path)"
```

Save this as `task-announce.yaml`:

```yaml
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: announce
  namespace: starfleet
spec:
  params:
    - name: name
      type: string
  results:
    - name: message
  steps:
    - name: announce
      image: busybox:1.37.0
      script: |
        #!/bin/sh
        set -eu
        printf '%s has the bridge' "$(params.name)" | tee "$(results.message.path)"
```

Apply both:

```sh
kubectl apply -f task-pick-crew.yaml -f task-announce.yaml
```

## Wire the result in the Pipeline

The Pipeline `crew-call` passes the result of the pipeline task `pick` into the parameter `name` of the pipeline task `call`. It also declares a pipeline result under `spec.results`: a named value of the whole Pipeline, built from task results with the same variable syntax.

Save this as `pipeline-crew-call.yaml`:

```yaml
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: crew-call
  namespace: starfleet
spec:
  params:
    - name: crew
      type: string
  results:
    - name: announcement
      description: What the call task announced
      value: $(tasks.call.results.message)
  tasks:
    - name: pick
      taskRef:
        name: pick-crew
      params:
        - name: crew
          value: $(params.crew)
    - name: call
      taskRef:
        name: announce
      params:
        - name: name
          value: $(tasks.pick.results.captain)
```

Apply it and start it with `tkn`:

```sh
kubectl apply -f pipeline-crew-call.yaml
tkn pipeline start crew-call -n starfleet -p crew="shuttle probe scout" --showlog
```

There is no `runAfter` in this Pipeline, yet `call` waits for `pick`. The reference `$(tasks.pick.results.captain)` is a resource dependency: `call` needs a value that only exists after `pick` has finished, so the controller does not create the TaskRun for `call` before then. When it does, it replaces the variable with the value, so the TaskRun of `call` gets the plain parameter `name: shuttle`.

## Read the pipeline result

When the run ends, the controller copies each pipeline result into `status.results` of the `PipelineRun`. Read it from the last run:

```sh
tkn pipelinerun describe --last -n starfleet
kubectl get pipelineruns -n starfleet -l tekton.dev/pipeline=crew-call -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.status.results[?(@.name=="announcement")].value}{"\n"}{end}'
```

The `Results` block of `tkn pipelinerun describe` and the `kubectl` command both show `announcement` with the value `shuttle has the bridge`. In the API version `tekton.dev/v1` the field is `status.results`; older material written for `v1beta1` calls it `status.pipelineResults`.

A pipeline result is not always there. The controller leaves it out when the pipeline task it refers to failed or was skipped, or when that task did not write the result. A skipped task does not fail the `PipelineRun` because of a missing pipeline result; the value is simply absent. Read results only after you have checked the condition.

## A misspelled result name

Result references are checked by the controller, not only by the webhook. The webhook accepts `$(tasks.pick.results.capitan)` because the pipeline task `pick` exists. Before it creates the first TaskRun, the controller loads the Task `pick-crew`, sees that it has no result `capitan`, and fails the run. Try it with an embedded Pipeline, a `pipelineSpec` written straight into the `PipelineRun`:

Save this as `pipelinerun-typo.yaml`:

```yaml
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  name: typo-1
  namespace: starfleet
spec:
  pipelineSpec:
    tasks:
      - name: pick
        taskRef:
          name: pick-crew
        params:
          - name: crew
            value: "scout probe"
      - name: call
        taskRef:
          name: announce
        params:
          - name: name
            value: $(tasks.pick.results.capitan)
```

Apply it and read the condition:

```sh
kubectl apply -f pipelinerun-typo.yaml
kubectl get pipelinerun typo-1 -n starfleet -o jsonpath='{.status.conditions[0].reason}{"\n"}{.status.conditions[0].message}{"\n"}'
```

The reason is `InvalidTaskResultReference`, and the message names the pipeline task `call` and the reference that does not resolve. `kubectl get taskruns -n starfleet -l tekton.dev/pipelineRun=typo-1` finds nothing: the run failed before any TaskRun existed. A typo in a pipeline result, under `spec.results`, fails the same way with the reason `InvalidPipelineResultReference`.

Results give tasks a typed, visible way to pass small values, and they give the Pipeline a way to report them. They also order tasks without any extra field. The open question is how to order tasks that share only files, and how to read a run whose graph has several branches.

## Common pitfalls

> [!WARNING]
> - **Using the Task name in the reference.** `$(tasks.<name>...)` takes the pipeline task name (`pick`), not the Task name (`pick-crew`).
> - **Looking for `pipelineResults` in a `v1` object.** In `tekton.dev/v1` the field is `status.results`.
> - **Ending a result with a newline.** `echo` adds one and the newline becomes part of the value. Use `printf '%s'`.
> - **Passing large data as a result.** All results of one TaskRun share about 4 KB. Put files in a workspace and pass only their path or hash.
> - **Reading a pipeline result without checking the condition.** If the source task failed or was skipped, the result is simply missing.
