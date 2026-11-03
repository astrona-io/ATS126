# Embedded Specs And Propagated Parameters

So far a pipeline task named a Task with `taskRef`, and a `PipelineRun` named a Pipeline with `pipelineRef`. Tekton also accepts the spec itself in place of the reference. This is how a one-off run is written in a single file. It also changes how parameters and workspaces reach the steps, because an embedded spec can use the values of the object around it without declaring them again.

## Embedded specs

| Reference form | Embedded form |
| --- | --- |
| `taskRef: {name: x}` in a pipeline task | `taskSpec:` with the Task's `spec` |
| `pipelineRef: {name: x}` in a `PipelineRun` | `pipelineSpec:` with the Pipeline's `spec` |
| `taskRef: {name: x}` in a `TaskRun` | `taskSpec:` |

An embedded spec has no name and no object of its own. It cannot be reused and does not show in `kubectl get pipelines`. It is stored in the run, so the run keeps its definition even after the Pipeline would change, which is useful for a record and for a test.

## Propagated parameters

With an embedded spec, a parameter of the outer object can be used inside without declaring it again. Save this as `pipelinerun-embedded.yaml`:

<!-- astrona:playground:renew -->

```yaml
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  name: embedded-1
  namespace: starfleet
spec:
  params:
    - name: crew
      value: scout
  pipelineSpec:
    tasks:
      - name: greet
        taskSpec:
          steps:
            - name: hello
              image: busybox:1.37.0
              script: |
                #!/bin/sh
                echo "hello $(params.crew)"
```

The Pipeline declares no parameter `crew` and the Task declares none, yet `$(params.crew)` works, because the `PipelineRun` provides it and both specs are embedded. Run it:

```sh
kubectl apply -f pipelinerun-embedded.yaml
kubectl wait --for=condition=Succeeded pipelinerun/embedded-1 -n starfleet --timeout=120s
tkn pipelinerun logs embedded-1 -n starfleet
```

The log says `hello scout`. If the Pipeline were referenced by name instead, the parameter would have to be declared in the Pipeline, and the run would fail with `ParameterMissing` or an unknown-parameter error. Propagation works only down a chain of embedded specs. A referenced Task or Pipeline is a separate object and knows nothing about its caller.

## Propagated workspaces

The same holds for workspaces. A workspace bound in the `PipelineRun` can be used by an embedded Task through `$(workspaces.<name>.path)` without a `workspaces` declaration, provided the pipeline task passes it on. In practice, declare workspaces explicitly in anything that you reuse, because the explicit declaration documents what the object needs.

## Read the stored definition

The `PipelineRun` stores the expanded spec. Read it to see what was actually used:

```sh
kubectl get pipelinerun embedded-1 -n starfleet -o jsonpath='{.status.pipelineSpec.tasks[0].taskSpec.steps[0].script}{"\n"}'
```

The script in the status holds the substituted text, which makes this the way to check what a one-off run really did.

You can now write a self-contained run, explain why its parameters work without declarations, and know when to move the definition into its own object.

## Common pitfalls

> [!WARNING]
> - **Using a propagated parameter in a referenced Task.** The Task is a separate object and must declare it.
> - **Embedding specs in a Pipeline that several teams reuse.** Put the Task in its own object.
> - **Relying on propagation as documentation.** Declared parameters show what an object expects.
> - **Looking for an embedded Pipeline with `kubectl get pipeline`.** It exists only inside the run.
