# Cluster Defaults With config-defaults

Every run has a time limit, a service account and a pod shape, even if you set none of them. The values come from the ConfigMap `config-defaults` in the namespace `tekton-pipelines`. A cluster owner changes it once and every run that does not say otherwise follows. This part reads the ConfigMap, shows the effect of the timeout default, and changes the default service account.

## What the ConfigMap holds

Read the keys:

```sh
kubectl get configmap config-defaults -n tekton-pipelines -o jsonpath='{.data}'
```

The ConfigMap of the release manifest holds one key, `_example`, which only documents the other keys in comments. The built-in values apply when a key is missing. The ones that matter in this module are:

| Key | Built-in value | Effect |
| --- | --- | --- |
| `default-timeout-minutes` | `60` | Timeout of a `PipelineRun` or `TaskRun` that sets none. The value `0` means no timeout |
| `default-service-account` | `default` | Service account of a run that names none |
| `default-pod-template` | empty | Pod template applied to every TaskRun pod. A run template wins over it |
| `default-task-run-workspace-binding` | empty | Binding for a Task workspace that a run leaves unbound |
| `default-max-matrix-combinations-count` | `256` | Largest number of combinations a matrix may create |

The controller watches the ConfigMap. A change applies to new runs without a restart.

## See the timeout default

Run a pipeline with no timeouts and read what the controller wrote:

<!-- astrona:playground:renew -->

Save this as `pipeline-hello.yaml`:

```yaml
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: hello
  namespace: starfleet
spec:
  tasks:
    - name: say
      taskSpec:
        steps:
          - name: say
            image: busybox:1.37.0
            script: |
              #!/bin/sh
              echo "hello from $(context.taskRun.name)"
```

Apply it and start it:

```sh
kubectl apply -f pipeline-hello.yaml
tkn pipeline start hello -n starfleet --prefix-name defaults --showlog
```

The run prints its greeting. Now read the timeouts that Tekton stored in the spec of the run. Replace `<RUN>` with the name that `tkn` printed:

```sh
kubectl get pipelinerun <RUN> -n starfleet -o jsonpath='{.spec.timeouts}{"\n"}'
```

The webhook filled `timeouts.pipeline` with `1h0m0s`, which is the default of 60 minutes, and the controller used it. You did not write it.

## Change the default service account

Create a service account and make it the default for the cluster:

```sh
kubectl create serviceaccount ci-runner -n starfleet
kubectl patch configmap config-defaults -n tekton-pipelines --type merge -p '{"data":{"default-service-account":"ci-runner"}}'
```

Start the Pipeline again, wait for it and read the account on the pod:

```sh
tkn pipeline start hello -n starfleet --prefix-name defaults --showlog
kubectl get pods -n starfleet -o custom-columns='POD:.metadata.name,SA:.spec.serviceAccountName'
```

The older pods show `default`. The newest pod shows `ci-runner`. Tekton read the default when the TaskRun was created and stored it in the TaskRun spec, so the older runs keep their account.

Undo the change, so the rest of the module starts clean:

```sh
kubectl patch configmap config-defaults -n tekton-pipelines --type merge -p '{"data":{"default-service-account":"default"}}'
```

## What a default cannot do

A default is one value for the whole cluster. It cannot differ per namespace or per Pipeline. When one team needs another account or timeout, that team sets the field on its `PipelineRun`. The next part shows how.

## Common pitfalls

> [!WARNING]
> - **Setting `default-timeout-minutes` to `0` for a whole cluster.** A stuck task then holds its pod forever. Prefer a long limit.
> - **Expecting old runs to follow a changed default.** The value is copied into each TaskRun spec when it is created.
> - **Editing `config-defaults` without access rights.** The ConfigMap lives in `tekton-pipelines`, which only cluster owners can change.
> - **Mixing up `config-defaults` with `feature-flags`.** The first holds values, the second switches behavior.
> - **Naming a service account that does not exist.** The pod cannot be created and the TaskRun fails.
