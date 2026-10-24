# Pipelines, PipelineRuns And Workspaces

Two Tasks that must always run together raise three questions. Who starts the second one, and when? How does the second one see the files the first one wrote, when each TaskRun is its own pod with its own file system? And where do you read the outcome of the whole job? A `Pipeline` answers all three. This part writes a two-task Pipeline, runs it, and follows a file from one pod to the next.

## Two Tasks that share a workspace

A workspace is a named volume that a `Task` declares under `spec.workspaces`. The Task does not say which volume it is. It only gives the volume a name and uses its path, `$(workspaces.<name>.path)`, in its steps. Whoever runs the Task decides what to mount there.

Here are two Tasks. `write-greeting` writes a line into the workspace `shared`, and `read-greeting` prints that line back.

<!-- astrona:playground:renew -->

Save this as `task-write-greeting.yaml`:

```yaml
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: write-greeting
  namespace: starfleet
spec:
  params:
    - name: crew
      type: string
  workspaces:
    - name: shared
  steps:
    - name: write
      image: busybox:1.37.0
      script: |
        #!/bin/sh
        set -eu
        echo "Hello, $(params.crew)!" > "$(workspaces.shared.path)/greeting.txt"
        echo "Wrote the greeting for $(params.crew)"
```

Save this as `task-read-greeting.yaml`:

```yaml
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: read-greeting
  namespace: starfleet
spec:
  workspaces:
    - name: shared
  steps:
    - name: read
      image: busybox:1.37.0
      script: |
        #!/bin/sh
        set -eu
        cat "$(workspaces.shared.path)/greeting.txt"
```

Apply both:

```sh
kubectl apply -f task-write-greeting.yaml -f task-read-greeting.yaml
```

Nothing runs yet. These are definitions, stored in the API server.

## A Pipeline connects the Tasks

A `Pipeline` has the same three kinds of inputs as a Task, one level up. It declares its own `params` and `workspaces`, and each entry under `spec.tasks`, called a pipeline task, hands them down to one Task. A pipeline task has a `name` of its own (the name inside the graph), a `taskRef` to the Task, and `params` and `workspaces` that map the Pipeline's values to the Task's names.

Save this as `pipeline-greeting.yaml`:

```yaml
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: greeting
  namespace: starfleet
spec:
  params:
    - name: crew
      type: string
      default: bridge
  workspaces:
    - name: files
  tasks:
    - name: write
      taskRef:
        name: write-greeting
      params:
        - name: crew
          value: $(params.crew)
      workspaces:
        - name: shared
          workspace: files
    - name: read
      runAfter:
        - write
      taskRef:
        name: read-greeting
      workspaces:
        - name: shared
          workspace: files
```

Apply it:

```sh
kubectl apply -f pipeline-greeting.yaml
```

Look at the workspace mapping. The Pipeline calls its volume `files`, and both Tasks call theirs `shared`. The line `name: shared` with `workspace: files` says "mount the Pipeline's `files` where this Task expects `shared`". The names do not have to match, and often they do not, because one Task is used by many Pipelines. The `runAfter: [write]` line makes `read` wait until `write` has finished; without it, both would start at the same moment.

## A PipelineRun binds the volume

The `Pipeline` still does not say which volume `files` is. The `PipelineRun` does. A `volumeClaimTemplate` is the usual choice: it is a PersistentVolumeClaim (PVC) template, and the controller creates one new claim from it for every run. In `kind`, the local-path provisioner then creates the volume on the node.

Save this as `pipelinerun-greeting-1.yaml`:

```yaml
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  name: greeting-1
  namespace: starfleet
spec:
  pipelineRef:
    name: greeting
  params:
    - name: crew
      value: scout
  workspaces:
    - name: files
      volumeClaimTemplate:
        spec:
          accessModes:
            - ReadWriteOnce
          resources:
            requests:
              storage: 16Mi
```

Apply it:

```sh
kubectl apply -f pipelinerun-greeting-1.yaml
```

Then check the result:

```sh
kubectl wait --for=condition=Succeeded pipelinerun/greeting-1 -n starfleet --timeout=180s
kubectl get taskruns -n starfleet -l tekton.dev/pipelineRun=greeting-1
kubectl logs greeting-1-read-pod -n starfleet -c step-read
```

The first command returns when the `Succeeded` condition of the `PipelineRun` is `True`. The second lists two TaskRuns, `greeting-1-write` and `greeting-1-read`. The controller named each one `<pipelinerun>-<pipeline task>` and labelled it with `tekton.dev/pipelineRun` and `tekton.dev/pipelineTask`. The log of the `read` step prints `Hello, scout!`, so the file written in one pod was there in the next pod.

The volume itself is a normal PVC, owned by the `PipelineRun`:

```sh
kubectl get pvc -n starfleet
kubectl get pipelinerun greeting-1 -n starfleet -o jsonpath='{range .status.childReferences[*]}{.kind}{" "}{.name}{" "}{.pipelineTaskName}{"\n"}{end}'
```

The claim has a generated name and is `Bound`. When you delete `greeting-1`, Kubernetes deletes the claim with it. The second command reads `status.childReferences`, the list in which the `PipelineRun` names every run it created: here two entries of kind `TaskRun`, each with its pipeline task name. In Tekton v1.17.1 the default feature flag `coschedule: "workspaces"` also starts a small affinity assistant pod for each run with a PVC workspace, so that all TaskRuns that share the claim land on the same node. You may see it in `kubectl get pods -n starfleet`.

## Start a Pipeline with tkn

Writing a `PipelineRun` file every time is slow while you experiment. `tkn pipeline start` builds the `PipelineRun` for you from flags: `-p` for a parameter, `-w` for a workspace, and `--showlog` to follow the logs. A `volumeClaimTemplate` comes from a small file.

Save this as `workspace-template.yaml`:

```yaml
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 16Mi
```

Then start the Pipeline and follow it:

```sh
tkn pipeline start greeting -n starfleet -p crew=probe -w name=files,volumeClaimTemplateFile=workspace-template.yaml --showlog
tkn pipelinerun describe --last -n starfleet
```

`tkn` creates a `PipelineRun` with a generated name (`greeting-run-` and a suffix), prints the step logs of both tasks, and `tkn pipelinerun describe --last` shows its parameters, workspaces, TaskRuns and status. Use `tkn` to start and inspect, and keep YAML files for anything you want to keep or review.

You now know the three objects of a Pipeline run: the `Pipeline` with its parameters, workspaces and pipeline tasks; the `PipelineRun` that gives the values and the volume; and the TaskRuns the controller creates, one per pipeline task. The open question is how tasks exchange values that are not files, such as a version or a commit hash, and how the Pipeline hands such a value back to you.

## Common pitfalls

> [!WARNING]
> - **Confusing the two workspace names.** In a pipeline task, `name` is the Task's workspace and `workspace` is the Pipeline's. Swap them and either the webhook rejects the Pipeline or the PipelineRun fails before any TaskRun starts.
> - **Using `emptyDir` to share files between tasks.** An `emptyDir` lives in one pod, so the next TaskRun gets a new, empty one. Use a `volumeClaimTemplate` or an existing PVC.
> - **Reusing a PipelineRun name.** A `PipelineRun` runs once. To run again, create a new one or let `tkn` or `generateName` pick a name.
> - **Expecting the Pipeline to run on apply.** Applying a `Pipeline` only stores it. Only a `PipelineRun` creates TaskRuns.
