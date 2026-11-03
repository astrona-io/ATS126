# Workspace Volume Sources

A workspace is only a name until a `PipelineRun` binds it to a volume. Until now the volume was always a claim created for the run. Tasks also need other things: a configuration file that lives in a ConfigMap, a token that lives in a Secret, a scratch directory that no one needs afterwards, or a cache that must outlive the run. Tekton can bind a workspace to each of these. The choice decides what the Task can write, how long the data lives, and whether two tasks see the same files. This part binds one workspace to each source and shows what a step can and cannot do with it.

## The binding types

In `spec.workspaces` of a `PipelineRun` or `TaskRun`, each binding has a `name` and exactly one volume source:

| Source | What it gives | Writable | Lives until |
| --- | --- | --- | --- |
| `volumeClaimTemplate` | A new PersistentVolumeClaim (PVC) for this run | Yes | The run is deleted |
| `persistentVolumeClaim` with `claimName` | An existing PVC | Yes | You delete the PVC |
| `emptyDir: {}` | An empty directory in the pod | Yes | The pod ends |
| `configMap` with `name` | The keys of a ConfigMap as files | No | You delete the ConfigMap |
| `secret` with `secretName` | The keys of a Secret as files | No | You delete the Secret |

A `projected` source (several sources in one directory) and a `csi` source (a volume from a Container Storage Interface driver) exist too. The Task side does not change: it declares `workspaces` with a `name`, and may add `readOnly: true`, a `mountPath` and a `description`. A ConfigMap or a Secret is mounted read-only whatever the Task says.

An `emptyDir` belongs to one pod. Two TaskRuns never share it, because each TaskRun has its own pod. It suits scratch space for the steps of a single Task, which do share the pod.

## Read a ConfigMap and a Secret

The Task `inspect-inputs` lists both workspaces. It prints the content of the ConfigMap file and only the size of the Secret file, so the secret value never reaches a log.

<!-- astrona:playground:renew -->

Save this as `task-inspect-inputs.yaml`:

```yaml
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: inspect-inputs
  namespace: starfleet
spec:
  workspaces:
    - name: config
      description: The launch settings
    - name: keys
      description: The radio key
  steps:
    - name: show
      image: busybox:1.37.0
      script: |
        #!/bin/sh
        set -eu
        echo "Files in config:"
        ls "$(workspaces.config.path)"
        echo "limits.txt says: $(cat "$(workspaces.config.path)/limits.txt")"
        echo "token has $(wc -c < "$(workspaces.keys.path)/token" | tr -d ' ') bytes"
```

Create the ConfigMap and the Secret, and apply the Task:

```sh
kubectl create configmap launch-config -n starfleet --from-literal=limits.txt='max crew 12'
kubectl create secret generic radio-key -n starfleet --from-literal=token='not-a-real-secret'
kubectl apply -f task-inspect-inputs.yaml
```

Save this as `pipeline-inspect.yaml`. It passes both workspaces on:

```yaml
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: inspect
  namespace: starfleet
spec:
  workspaces:
    - name: config
    - name: keys
  tasks:
    - name: show
      taskRef:
        name: inspect-inputs
      workspaces:
        - name: config
          workspace: config
        - name: keys
          workspace: keys
```

Save this as `pipelinerun-inspect-1.yaml`:

```yaml
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  name: inspect-1
  namespace: starfleet
spec:
  pipelineRef:
    name: inspect
  workspaces:
    - name: config
      configMap:
        name: launch-config
    - name: keys
      secret:
        secretName: radio-key
```

Apply both and read the log:

```sh
kubectl apply -f pipeline-inspect.yaml -f pipelinerun-inspect-1.yaml
kubectl wait --for=condition=Succeeded pipelinerun/inspect-1 -n starfleet --timeout=180s
kubectl logs inspect-1-show-pod -n starfleet -c step-show
```

The log lists `limits.txt`, prints `max crew 12` and reports the size of the token: the file holds the 17 characters of the value, with no newline, because `--from-literal` does not add one. Each key of the ConfigMap or Secret became one file named after the key, in the directory `$(workspaces.<name>.path)`.

## Writing is a different story

A step that writes into a ConfigMap or Secret workspace fails, because the volume is read-only. A step that writes into a `volumeClaimTemplate`, a claim or an `emptyDir` succeeds. The difference matters when you design a Task. A Task that must save files needs a writable source. A Task that only reads settings should use a ConfigMap or Secret and mark the workspace `readOnly: true`, so the contract is visible in the Task.

A claim you create yourself stays after the run, so a second run finds the first run's files. Save this as `pvc-shared-cache.yaml`:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: shared-cache
  namespace: starfleet
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 16Mi
```

Apply it and look at it:

```sh
kubectl apply -f pvc-shared-cache.yaml
kubectl get pvc shared-cache -n starfleet
```

The claim stays in the state `Pending` until a pod uses it, because the `kind` local-path provisioner waits for the first consumer. A binding with `persistentVolumeClaim` and `claimName: shared-cache` in two PipelineRuns then gives both runs the same directory. Use that for caches such as package downloads. Take care with parallel runs: a `ReadWriteOnce` claim can be mounted by pods on one node only, and two runs that write the same files at the same time overwrite each other.

You now know the five usual volume sources, which of them are writable, and how long their data lives. The remaining questions are what happens when a Task needs a workspace only sometimes, how several tasks can use one volume without overwriting each other, and how Tekton keeps pods that share a volume on the same node.

## Common pitfalls

> [!WARNING]
> - **Writing to a ConfigMap or Secret workspace.** Both are read-only. Use a claim or an `emptyDir` for output.
> - **Using `emptyDir` to pass files between tasks.** Each TaskRun has its own pod and its own empty directory.
> - **Printing a Secret workspace to the log.** The log is readable by anyone who can read the pod logs. Print sizes or checksums, not values.
> - **Binding two sources to one workspace.** A binding has exactly one volume source.
> - **Leaving old claims behind.** A claim you created yourself is not deleted with the run. Delete it when you no longer need it.
