# Optional Workspaces, Sub-Paths And Scheduling

Not every Task needs every volume. A build Task can use a cache when the run provides one and work without it otherwise. Two tasks can write a file with the same name into one volume, as long as each uses its own folder. And when many tasks share a volume, their pods must run on a node that can mount it. This part covers the three features Tekton has for these cases: optional workspaces, `subPath` and the `coschedule` setting.

## A workspace that may be missing

A workspace is required unless its declaration says `optional: true`. A required workspace that a `PipelineRun` does not bind fails the run with the reason `InvalidWorkspaceBindings`. An optional workspace can stay unbound. Inside the Task, the variable `$(workspaces.<name>.bound)` is the text `true` when a volume is bound and `false` when not. The variable `$(workspaces.<name>.path)` is empty for an unbound workspace, so a step must test `bound` first.

The Task below writes a line into the optional workspace `cache` when it exists, and says so when it does not.

<!-- astrona:playground:renew -->

Save this as `task-use-cache.yaml`:

```yaml
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: use-cache
  namespace: starfleet
spec:
  workspaces:
    - name: cache
      optional: true
  steps:
    - name: use
      image: busybox:1.37.0
      script: |
        #!/bin/sh
        set -eu
        if [ "$(workspaces.cache.bound)" = "true" ]; then
          echo "cache is bound at $(workspaces.cache.path)"
          echo "warm" > "$(workspaces.cache.path)/state.txt"
        else
          echo "cache is not bound, working without it"
        fi
```

Save this as `pipeline-maybe-cache.yaml`. The Pipeline declares its workspace optional as well and passes it on:

```yaml
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: maybe-cache
  namespace: starfleet
spec:
  workspaces:
    - name: cache
      optional: true
  tasks:
    - name: use
      taskRef:
        name: use-cache
      workspaces:
        - name: cache
          workspace: cache
```

Apply both:

```sh
kubectl apply -f task-use-cache.yaml -f pipeline-maybe-cache.yaml
```

Start the Pipeline once without a workspace, and once with an `emptyDir`:

```sh
tkn pipeline start maybe-cache -n starfleet --prefix-name cache-off --showlog
tkn pipeline start maybe-cache -n starfleet --prefix-name cache-on -w name=cache,emptyDir="" --showlog
```

The first run prints `cache is not bound, working without it`. The second prints that the cache is bound and gives its path. The same Task and Pipeline served both runs. The `emptyDir=` value in the `-w` flag selects the source type `emptyDir` with its default medium.

A pipeline `when` expression can use the same variable. With `input: "$(workspaces.cache.bound)"`, `operator: in` and `values: ["true"]`, a pipeline task runs only when the run binds the workspace.

## One volume, several folders

Two tasks that write `note.txt` into the same volume overwrite each other. A `subPath` on the workspace entry of a pipeline task mounts one folder of the volume instead of its root. The task sees an ordinary directory, and the other task sees a different one.

Save this as `pipeline-two-folders.yaml`:

```yaml
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: two-folders
  namespace: starfleet
spec:
  workspaces:
    - name: shared
  tasks:
    - name: write-a
      workspaces:
        - name: out
          workspace: shared
          subPath: deck-a
      taskSpec:
        workspaces:
          - name: out
        steps:
          - name: write
            image: busybox:1.37.0
            script: |
              #!/bin/sh
              echo "from a" > "$(workspaces.out.path)/note.txt"
    - name: write-b
      workspaces:
        - name: out
          workspace: shared
          subPath: deck-b
      taskSpec:
        workspaces:
          - name: out
        steps:
          - name: write
            image: busybox:1.37.0
            script: |
              #!/bin/sh
              echo "from b" > "$(workspaces.out.path)/note.txt"
    - name: list
      runAfter:
        - write-a
        - write-b
      workspaces:
        - name: all
          workspace: shared
      taskSpec:
        workspaces:
          - name: all
        steps:
          - name: list
            image: busybox:1.37.0
            script: |
              #!/bin/sh
              find "$(workspaces.all.path)" -type f
```

Apply it:

```sh
kubectl apply -f pipeline-two-folders.yaml
```

`tkn` reads the claim template for the workspace from a file. Save this as `workspace-template.yaml`:

```yaml
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 16Mi
```

Then start the Pipeline:

```sh
tkn pipeline start two-folders -n starfleet --prefix-name folders -w name=shared,volumeClaimTemplateFile=workspace-template.yaml --showlog
```

The log of `list` shows two files, `deck-a/note.txt` and `deck-b/note.txt`, each below the workspace path. The two parallel tasks wrote the same file name without a conflict.

## Pods that share a volume

A `ReadWriteOnce` claim can be mounted by pods on one node at a time. If the TaskRuns of a run land on different nodes, the second one cannot start. The feature flag `coschedule` in the ConfigMap `feature-flags` of `tekton-pipelines` controls how Tekton avoids that. Read it:

```sh
kubectl get configmap feature-flags -n tekton-pipelines -o jsonpath='{.data.coschedule}{"\n"}'
```

The value in Tekton Pipelines v1.17.1 is `workspaces`. It has four possible values. With `workspaces`, the controller starts an affinity assistant pod for each PVC-backed workspace of a run, and all TaskRuns that use that workspace run on the same node. A pipeline task may then use at most one PVC-backed workspace. With `pipelineruns`, all pods of one run go to one node, whatever they mount. `isolate-pipelinerun` does the same and also keeps other runs off that node. `disabled` switches the help off, and then you must provide the node placement yourself, for example with a `podTemplate` node selector. On a one-node cluster such as `kind`, the setting has no visible effect.

You can now make a workspace optional, test it, split one volume into folders and explain how Tekton keeps pods that share a claim together. The module is complete when you can use these features to repair a Pipeline whose parameters and workspace do not fit its Tasks.

## Common pitfalls

> [!WARNING]
> - **Using `$(workspaces.cache.path)` without testing `bound`.** For an unbound workspace the path is empty, and the step writes to the wrong place.
> - **Declaring the workspace optional in the Task but not in the Pipeline.** The Pipeline then requires a binding, and the run fails with `InvalidWorkspaceBindings`.
> - **Forgetting the workspace entry in a pipeline task.** The Pipeline declares the workspace, but the task never receives it, and `bound` is `false` there.
> - **Expecting `subPath` to isolate data.** It only selects a folder. Any task that mounts the root sees every folder.
> - **Changing `coschedule` to `disabled` on a multi-node cluster.** Pods that share a `ReadWriteOnce` claim can then land on different nodes and stay pending.

## Your mission: Pass Typed Parameters And An Optional Workspace

You can now declare array and object parameters, pass them to a Task, and map an optional workspace. The graded lab gives you a Pipeline that fails because of its parameter types and then shows a second fault in its workspace mapping. Fix both and prove it with a PipelineRun.

The lab runs in its own cluster, so first pause your playground. Nothing in it is lost:

```sh
astrona stop ats-126-playground-010-02
```

Then start the lab:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS126.git -c sections/section-010/module-02/labs/lab-01
```

The task is on the next page. Solve it on your own first. When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-010/module-02/labs/lab-01
```

When you are done, remove the lab and resume your playground:

```sh
astrona destroy ats-126-lab-010-02
astrona start ats-126-playground-010-02
```
