# Read Why A Run Failed Or Waits

A run that does not succeed leaves its reason in the `Succeeded` condition, first on the `PipelineRun` and then on the TaskRun that caused it. Reading the reason before anything else saves time, because each reason points to a different next step. This part triggers four common situations on purpose and reads each reason: a Task that does not exist, a step that exits with an error, an image that cannot be pulled, and a namespace quota that makes a task wait.

## Where to look

Work from the outside in:

1. The `PipelineRun`: `kubectl get pipelinerun <name> -n starfleet -o jsonpath='{.status.conditions[0].reason}: {.status.conditions[0].message}{"\n"}'`.
2. The TaskRuns of the run: `kubectl get taskruns -n starfleet -l tekton.dev/pipelineRun=<name>`.
3. The condition of the failed TaskRun, and for a failed step its entry in `status.steps`.
4. The pod and its events, when the pod exists.

If the run has no TaskRuns at all, the fault is in the run or Pipeline itself, and the message of step 1 names it.

## A Task that does not exist

<!-- astrona:playground:renew -->

Save this as `pipelinerun-missing-task.yaml`:

```yaml
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  name: missing-task
  namespace: starfleet
spec:
  pipelineSpec:
    tasks:
      - name: ghost
        taskRef:
          name: no-such-task
```

Apply it and read the condition:

```sh
kubectl apply -f pipelinerun-missing-task.yaml
kubectl get pipelinerun missing-task -n starfleet -o jsonpath='{.status.conditions[0].reason}: {.status.conditions[0].message}{"\n"}'
```

The reason is `CouldntGetTask`. The message names the Task that Tekton could not find. There are no TaskRuns: the controller could not build the graph. The fix is to create the Task or correct the name.

## A step that exits with an error

Save this as `pipelinerun-exit-three.yaml`:

```yaml
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  name: exit-three
  namespace: starfleet
spec:
  pipelineSpec:
    tasks:
      - name: boom
        taskSpec:
          steps:
            - name: fail
              image: busybox:1.37.0
              script: |
                #!/bin/sh
                echo "about to fail"
                exit 3
```

Apply it and read the run and the TaskRun:

```sh
kubectl apply -f pipelinerun-exit-three.yaml
kubectl wait --for=condition=Succeeded=False pipelinerun/exit-three -n starfleet --timeout=120s
kubectl get pipelinerun exit-three -n starfleet -o jsonpath='{.status.conditions[0].reason}{"\n"}'
kubectl get taskrun exit-three-boom -n starfleet -o jsonpath='{.status.conditions[0].reason}: {.status.conditions[0].message}{"\n"}'
```

The run has the reason `Failed`. The TaskRun has the reason `Failed` and a message that names the step and the exit code. The reason alone does not say what went wrong; the log of the step does:

```sh
kubectl logs exit-three-boom-pod -n starfleet -c step-fail
```

## An image that cannot be pulled

Save this as `pipelinerun-bad-image.yaml`:

```yaml
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  name: bad-image
  namespace: starfleet
spec:
  pipelineSpec:
    tasks:
      - name: pull
        taskSpec:
          steps:
            - name: run
              image: busybox:does-not-exist
              script: |
                #!/bin/sh
                echo "never printed"
```

Apply it and read the TaskRun after a short time:

```sh
kubectl apply -f pipelinerun-bad-image.yaml
kubectl get taskrun bad-image-pull -n starfleet -o jsonpath='{.status.conditions[0].reason}: {.status.conditions[0].message}{"\n"}'
```

The TaskRun fails with the reason `TaskRunImagePullFailed` once the pod cannot pull the image. The pod events give the registry error. Typical causes are a misspelled tag, a private registry without a pull secret in the service account or the pod template, and a registry the cluster cannot reach.

## A task that waits for quota

A `ResourceQuota` can cap the number of pods in a namespace. Create one that allows a single pod:

```sh
kubectl create quota one-pod -n starfleet --hard=pods=1
```

Save this as `pipelinerun-two-at-once.yaml`. The two tasks have no order, so Tekton starts both at the same time:

```yaml
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  name: two-at-once
  namespace: starfleet
spec:
  pipelineSpec:
    tasks:
      - name: left
        taskSpec:
          steps:
            - name: work
              image: busybox:1.37.0
              script: |
                #!/bin/sh
                sleep 20
      - name: right
        taskSpec:
          steps:
            - name: work
              image: busybox:1.37.0
              script: |
                #!/bin/sh
                sleep 20
```

Apply it and list the TaskRuns while the first runs:

```sh
kubectl apply -f pipelinerun-two-at-once.yaml
kubectl get taskruns -n starfleet -l tekton.dev/pipelineRun=two-at-once -o custom-columns='TASK:.metadata.labels.tekton\.dev/pipelineTask,REASON:.status.conditions[0].reason'
```

One TaskRun is `Running`. The other shows the reason `ExceededResourceQuota`, and its message says the pod exceeded available resources. This is not a failure: the controller retries creating the pod, and the second task starts when the first pod has ended and no longer counts against the quota. Wait for the run to finish, then remove the quota:

```sh
kubectl wait --for=condition=Succeeded pipelinerun/two-at-once -n starfleet --timeout=180s
kubectl delete quota one-pod -n starfleet
```

A similar waiting reason, `ExceededNodeResources`, appears when no node has enough free CPU or memory for the requests of the pod. Both reasons mean the task waits, and the cure is more capacity or smaller requests.

## Common pitfalls

> [!WARNING]
> - **Reading only the PipelineRun.** Its reason can be a plain `Failed`. The cause is in the TaskRun and in the log.
> - **Treating `ExceededResourceQuota` as an error.** The task waits and starts later. A timeout can still cut the wait.
> - **Looking for a pod when there are no TaskRuns.** A run that cannot build its graph never creates one.
> - **Deleting the failed run before reading its log.** The pod and the run hold the evidence.
> - **Leaving a quota behind.** A forgotten `ResourceQuota` blocks later runs with the same waiting reason.
