# Defaults, Service Accounts And Resources

The `starfleet` team has a Pipeline that works. Now the cluster owner has rules: every run uses a named service account, pods run as a non-root user, the build task gets a memory limit, nothing may run longer than ten minutes, and a namespace quota caps the number of pods. None of these rules belong inside the Pipeline, because the same Pipeline runs in other places with other rules. Tekton keeps them in three layers: cluster-wide defaults, the settings of one `PipelineRun`, and overrides for single pipeline tasks. This module teaches the layers and how to read what went wrong when a layer is missing.

A default is a value the tekton-pipelines-controller and the webhook apply when a run does not set it. It lives in the ConfigMap `config-defaults`. A run setting is a field of the `PipelineRun` spec, such as `taskRunTemplate`. A per-task override is an entry in `taskRunSpecs` that names one pipeline task. The most specific layer wins.

Keep one sentence in mind: **the Pipeline describes what runs, the PipelineRun describes how it runs.** A Pipeline that names a service account or a node is not reusable. A run that sets nothing gets the defaults of the cluster.

The module has four parts. **Cluster Defaults With config-defaults** reads and changes the defaults for timeouts and service accounts. **Settings For A Whole Run** uses `taskRunTemplate` for the service account and the pod template. **Per-Task Overrides And Resources** uses `taskRunSpecs` and `computeResources` for single tasks. **Read Why A Run Failed Or Waits** lists the reasons of runs and TaskRuns, including quota. A graded lab follows the third part.

## Learning objectives

After this module you can:

- Read `config-defaults` and explain `default-timeout-minutes`, `default-service-account` and the value `0` for no timeout.
- Set `taskRunTemplate.serviceAccountName` and `taskRunTemplate.podTemplate` on a `PipelineRun` and confirm them on the pod.
- Override one pipeline task with `taskRunSpecs` and `computeResources`.
- Explain how Tekton sums step resources into pod requests.
- Read the reasons `CouldntGetTask`, `TaskRunImagePullFailed`, `ExceededResourceQuota` and `Failed` and find the next command for each.

## Before you start

You need to know how a `Pipeline` and a `PipelineRun` fit together, how `timeouts` and `retries` work, and how to list the TaskRuns of a run with the label `tekton.dev/pipelineRun`.

Your playground is a single-node `kind` cluster with these parts:

| Part of the playground | What it is |
| --- | --- |
| Namespace `tekton-pipelines` | Tekton Pipelines v1.17.1: the controller, the webhook, the events controller and the ConfigMap `config-defaults` |
| Namespace `tekton-pipelines-resolvers` | The remote resolvers |
| Namespace `starfleet` | Empty. Your Tasks, Pipelines and runs go here |
| `tkn` on your PATH | The Tekton command-line tool, version 0.46.2 |

Every command in the parts runs against the playground cluster, and `kubectl` already points at it.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
