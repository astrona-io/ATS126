# Find, Follow And Clean Up Runs

A team that uses a Pipeline all day does not run it once. After a week there are dozens of `PipelineRun` objects, each with TaskRuns, pods and a PersistentVolumeClaim. You need to find the right run, follow a run that is still going, stop one that should not continue, and remove the old ones. This part shows how to do all four with `tkn` and with `kubectl`, and which labels Tekton puts on every object so that you can select them.

## Labels that tie the objects together

The tekton-pipelines-controller adds labels to everything it creates. A `PipelineRun` that refers to a Pipeline with `pipelineRef` gets the label `tekton.dev/pipeline` with the name of the Pipeline. Each TaskRun it creates gets `tekton.dev/pipelineRun` with the name of the run and `tekton.dev/pipelineTask` with the name of the pipeline task. A pod carries `tekton.dev/taskRun`. These labels are the reason a selector such as `-l tekton.dev/pipelineRun=<RUN>` finds exactly the TaskRuns of one run.

The Pipeline below is small and slow on purpose, so a run stays active for about half a minute. That gives you time to follow it and to stop it.

<!-- astrona:playground:renew -->

Save this as `pipeline-slow-check.yaml`:

```yaml
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: slow-check
  namespace: starfleet
spec:
  tasks:
    - name: first
      taskSpec:
        steps:
          - name: wait
            image: busybox:1.37.0
            script: |
              #!/bin/sh
              echo "first: start"
              sleep 15
              echo "first: done"
    - name: second
      runAfter:
        - first
      taskSpec:
        steps:
          - name: wait
            image: busybox:1.37.0
            script: |
              #!/bin/sh
              echo "second: start"
              sleep 15
              echo "second: done"
```

Apply it and start three runs. The `--prefix-name` flag makes `tkn` use the prefix in the generated name:

```sh
kubectl apply -f pipeline-slow-check.yaml
tkn pipeline start slow-check -n starfleet --prefix-name slow-a
tkn pipeline start slow-check -n starfleet --prefix-name slow-b
tkn pipeline start slow-check -n starfleet --prefix-name slow-c
```

## Find a run

`tkn pipelinerun list` shows the runs of a namespace with their start time, duration and status. `tkn pipeline describe` lists the Pipeline together with its latest runs.

```sh
tkn pipelinerun list -n starfleet
tkn pipeline describe slow-check -n starfleet
kubectl get pipelineruns -n starfleet -l tekton.dev/pipeline=slow-check --sort-by=.metadata.creationTimestamp
```

The first two commands are the `tkn` view. The `kubectl` command gives the same list, selected by the label `tekton.dev/pipeline`, in the order of creation. Use `kubectl` when you want a script to read the result; use `tkn` when you want a human to read it.

## Follow a run

`tkn pipelinerun logs` prints the logs of all steps of a run, in order, with the pipeline task and step name in front of each line. The flag `-f` keeps following while the run is active. The flag `-t` limits the output to one pipeline task. `--last` selects the newest run, so you do not need to copy the name.

```sh
tkn pipelinerun logs --last -n starfleet -f
tkn pipelinerun logs <RUN-B> -n starfleet -t second
```

Replace `<RUN-B>` with the name of the second run, as `tkn pipelinerun list` shows it; it starts with `slow-b-`. The same logs are in the pods: `kubectl logs <pod> -c step-wait`. The advantage of `tkn` is that you do not have to know the name of the pod. The advantage of `kubectl` is that it works on any machine that has no `tkn`.

## Stop a run

`tkn pipelinerun cancel` asks the controller to cancel the run. The controller sets `spec.status: Cancelled` on the `PipelineRun`, cancels every TaskRun that is still running, and ends the run with the reason `Cancelled`. Replace `<RUN-C>` with the name of the third run, which starts with `slow-c-`. Cancel it while its first task is still sleeping:

```sh
tkn pipelinerun cancel <RUN-C> -n starfleet
kubectl get pipelinerun <RUN-C> -n starfleet -o jsonpath='{.spec.status}{" "}{.status.conditions[0].reason}{"\n"}'
```

The first value is the `spec.status` that `tkn` wrote. The second value is the reason of the condition, which becomes `Cancelled` once the controller has handled the request. A run that has already finished cannot be cancelled.

## Clean up

Every finished `PipelineRun` stays in the cluster until someone deletes it, together with its TaskRuns, its pods and its volume claim. Kubernetes removes the children because they have the `PipelineRun` as owner. `tkn pipelinerun delete` has selection flags so that you do not have to name each run:

```sh
tkn pipelinerun delete --pipeline slow-check --keep 1 -n starfleet
tkn pipelinerun list -n starfleet
```

`--pipeline` limits the command to the runs of one Pipeline, and `--keep 1` keeps the newest one. The command asks for confirmation before it deletes. `--all` would delete every run of the namespace, and `-f` (force) skips the question; use those two with care. A scheduled cleanup, for example a Kubernetes CronJob that runs `tkn pipelinerun delete --keep`, keeps the history short.

You can now find a run by Pipeline or by label, follow its logs, cancel it and clean up old runs. Everything the controller records about a run stays in its status until you delete it, so cleaning up is a habit and not a luxury.

## Common pitfalls

> [!WARNING]
> - **Reading logs of a deleted run.** Logs live in the pods. When the run and its pods are deleted, the logs are gone unless a log system collected them.
> - **Using `--all` without `--pipeline`.** It deletes every run in the namespace, also the ones of other Pipelines.
> - **Cancelling and expecting a clean finish.** A cancelled run ends with the reason `Cancelled` and `Succeeded` set to `False`. Tasks that were running stop in the middle of a step.
> - **Forgetting the namespace.** `tkn` and `kubectl` use the namespace of the current context. Pass `-n starfleet` every time.
