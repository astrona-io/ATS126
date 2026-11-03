# Summary

Parameters, variables and workspaces decide how reusable a Pipeline is and when a run fails. Tekton checks most of them in the tekton-pipelines-controller before it creates a single TaskRun, so a wrong shape shows up as the reason of the `Succeeded` condition and not as a failing step.

## What you learned

A parameter is a string, an array or an object. An array expands as a whole only in `command`, `args` and array parameters, and elements are read with an index. An object lists its keys under `properties`, reads a key as `$(params.ship.name)` and passes as a whole with `[*]`. A value with the wrong shape fails the run with `ParameterTypeMismatch`, a missing value with `ParameterMissing`, and a missing object key with `ObjectParameterMissKeys`.

The controller replaces variables with text before the pod exists. A Pipeline reads `$(context.pipelineRun.name)`, `$(context.pipelineRun.namespace)`, `$(context.pipeline.name)` and, in `finally` tasks, the execution status. A Task reads its own parameters, workspaces, results and `$(context.taskRun.name)`. Because the value becomes part of the script, untrusted values go into environment variables.

A workspace binding has exactly one source. A `volumeClaimTemplate` creates a claim for the run, a `persistentVolumeClaim` reuses one, an `emptyDir` lives as long as one pod, and a ConfigMap or Secret is read-only. An optional workspace can stay unbound, and `$(workspaces.<name>.bound)` tells the step. A `subPath` mounts one folder of a volume, and the `coschedule` flag keeps pods that share a claim on one node. The key facts to remember are these:

- `ParameterTypeMismatch`, `ParameterMissing` and `ObjectParameterMissKeys` come before any TaskRun exists.
- `$(context.pipelineRun.*)` works in a Pipeline, not in a Task.
- ConfigMap and Secret workspaces are read-only.
- A required workspace without a binding fails with `InvalidWorkspaceBindings`.
- The default `coschedule` value in v1.17.1 is `workspaces`.

<!-- astrona:playground:destroy -->
