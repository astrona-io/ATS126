# Settings For A Whole Run

A cluster default is the same for everyone. A single run often needs its own service account, its own user id or its own node. The `PipelineRun` field `taskRunTemplate` carries these settings, and the controller copies them into every TaskRun it creates for the run. This part sets the service account and the pod template, and checks both on the pods.

## The field taskRunTemplate

In the v1 API, `spec.taskRunTemplate` of a `PipelineRun` has two fields:

- `serviceAccountName` is the service account that every pod of the run uses.
- `podTemplate` is a pod specification fragment that Tekton merges into every pod. It can hold `nodeSelector`, `tolerations`, `securityContext`, `imagePullSecrets`, `runtimeClassName`, `schedulerName`, `priorityClassName`, `hostNetwork` and `env`.

The pod template does not replace the pod Tekton builds. It adds to it. The containers, volumes and commands of the steps stay Tekton's own.

## Run a Pipeline as a named user

The Task below prints the user id of its process. A Pipeline calls it twice.

<!-- astrona:playground:renew -->

Save this as `pipeline-who-runs.yaml`:

```yaml
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: who-runs
  namespace: starfleet
spec:
  tasks:
    - name: first
      taskSpec:
        steps:
          - name: id
            image: busybox:1.37.0
            script: |
              #!/bin/sh
              echo "user: $(id -u)"
    - name: second
      runAfter:
        - first
      taskSpec:
        steps:
          - name: id
            image: busybox:1.37.0
            script: |
              #!/bin/sh
              echo "user: $(id -u)"
```

Create a service account and apply the Pipeline:

```sh
kubectl create serviceaccount auditor -n starfleet
kubectl apply -f pipeline-who-runs.yaml
```

Run it once with no settings. Replace nothing; the output shows the user of the image:

```sh
tkn pipeline start who-runs -n starfleet --prefix-name plain --showlog
```

Both tasks print `user: 0`, because the image runs as root by default. Now save this as `pipelinerun-who-runs-audited.yaml`:

```yaml
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  name: who-runs-audited
  namespace: starfleet
spec:
  pipelineRef:
    name: who-runs
  taskRunTemplate:
    serviceAccountName: auditor
    podTemplate:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 1000
```

Apply it and read the log of both tasks and the pods:

```sh
kubectl apply -f pipelinerun-who-runs-audited.yaml
kubectl wait --for=condition=Succeeded pipelinerun/who-runs-audited -n starfleet --timeout=180s
kubectl logs who-runs-audited-first-pod -n starfleet -c step-id
kubectl get pods -n starfleet -l tekton.dev/pipelineRun=who-runs-audited -o custom-columns='POD:.metadata.name,SA:.spec.serviceAccountName,USER:.spec.securityContext.runAsUser'
```

The log prints `user: 1000`. Both pods show the service account `auditor` and the user `1000`. The Pipeline did not change; only the run did.

## Where the settings land

The settings travel in two steps. The controller copies `serviceAccountName` and `podTemplate` into the spec of each TaskRun. The pod is then built from the TaskRun. You can read the intermediate step:

```sh
kubectl get taskrun who-runs-audited-first -n starfleet -o jsonpath='{.spec.serviceAccountName}{"\n"}{.spec.podTemplate}{"\n"}'
```

The output holds the account and the security context. This is the place to look when a pod does not behave as the run says: if the TaskRun spec is right, the fault is in the pod; if it is wrong, the fault is in the run.

## Order of precedence

When the same field is set in several places, the most specific wins: a `taskRunSpecs` entry for the pipeline task, then `taskRunTemplate`, then `default-pod-template` and `default-service-account` in `config-defaults`. Two pod templates are merged field by field. For `securityContext` and `nodeSelector` the more specific object replaces the broader one as a whole.

## Common pitfalls

> [!WARNING]
> - **Putting `serviceAccountName` in the Pipeline.** The field does not exist there. It belongs to the run.
> - **Setting `runAsNonRoot` for an image that needs root.** The pod starts but the container fails with `CreateContainerConfigError`.
> - **Using `runAsUser` without `fsGroup`.** The user may not be able to write to the workspace volume.
> - **Using the old field `spec.serviceAccountName` of the v1beta1 API.** In the v1 API, use `taskRunTemplate`.
> - **Expecting the template to change a pod that already exists.** It applies when the pod is created.
