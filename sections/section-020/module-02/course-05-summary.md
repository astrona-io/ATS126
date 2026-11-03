# Summary

A Pipeline says what runs. The cluster and the `PipelineRun` say how it runs, and when something goes wrong, the reasons in the status say why. This module covered the three layers of settings and the reasons that tell you which layer failed.

## What you learned

The ConfigMap `config-defaults` in `tekton-pipelines` holds the cluster defaults: `default-timeout-minutes` (60, and `0` for no timeout), `default-service-account`, `default-pod-template` and others. The controller copies a default into the TaskRun when it creates it, so a change applies to new runs only.

A `PipelineRun` overrides the defaults for itself with `spec.taskRunTemplate`: `serviceAccountName` and a `podTemplate` that Tekton merges into every pod. `spec.taskRunSpecs` overrides single pipeline tasks by `pipelineTaskName`, with a `podTemplate`, `computeResources`, `stepSpecs`, `sidecarSpecs` and `metadata`. The most specific layer wins. Tekton keeps only the largest step request as the pod request, because steps run one after the other.

Reasons guide the next step: `CouldntGetTask` means the graph could not be built, `Failed` with a step message means look at the step log, `TaskRunImagePullFailed` means look at the image and the pull secret, and `ExceededResourceQuota` or `ExceededNodeResources` mean the task waits for capacity. The key facts to remember are these:

- A default is copied into the TaskRun when it is created; old runs keep their values.
- The Pipeline never names a service account; the run does.
- `pipelineTaskName` is the name of the pipeline task, not of the Task.
- A run with no TaskRuns failed before the graph existed.
- Waiting for quota is not a failure, but a timeout can end the wait.

<!-- astrona:playground:destroy -->
