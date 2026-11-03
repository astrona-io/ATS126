# Read And Fix Resolution Failures

A run that cannot resolve its Task or Pipeline never creates a pod. It stops with a reason and a message, and the real error often sits one object deeper, in the `ResolutionRequest`. The faults are few: a misspelled parameter, a path that does not exist, a namespace that is not allowed, and a name that is not found. This part makes four of them on purpose and shows where to read each.

## Where the error lives

Start with the run, then go down:

1. `kubectl get pipelinerun <run> -n starfleet -o jsonpath='{.status.conditions[0].reason}: {.status.conditions[0].message}{"\n"}'`.
2. `kubectl get resolutionrequests -n starfleet` and the object for the run, with `-o yaml`.
3. The logs of the resolvers: `kubectl logs deploy/tekton-pipelines-remote-resolvers -n tekton-pipelines-resolvers`.

The reasons you meet are `ResolvingPipelineRef` and `ResolvingTaskRef` while the answer is awaited, and `CouldntGetPipeline` and `CouldntGetTask` when it failed. The message of a failure names the resolver and the error it returned.

## A path that does not exist

<!-- astrona:playground:renew -->

Save this as `pipelinerun-bad-path.yaml`:

```yaml
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  name: bad-path
  namespace: starfleet
spec:
  pipelineSpec:
    tasks:
      - name: hello
        taskRef:
          resolver: git
          params:
            - name: url
              value: http://gitea-http.gitea.svc.cluster.local:3000/starfleet/tekton-catalog.git
            - name: revision
              value: main
            - name: pathInRepo
              value: tasks/say-goodbye.yaml
```

Apply it and read the failure:

```sh
kubectl apply -f pipelinerun-bad-path.yaml
kubectl wait --for=condition=Succeeded=False pipelinerun/bad-path -n starfleet --timeout=180s
kubectl get pipelinerun bad-path -n starfleet -o jsonpath='{.status.conditions[0].reason}: {.status.conditions[0].message}{"\n"}'
```

The reason is `CouldntGetTask`, and the message carries the error from the git resolver about the missing file. The fix is the path: list the repository with the Gitea API and copy it exactly. Git paths are case-sensitive.

## A namespace or name that is not found

Save this as `pipelinerun-bad-name.yaml`:

```yaml
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  name: bad-name
  namespace: starfleet
spec:
  pipelineSpec:
    tasks:
      - name: call
        params:
          - name: message
            value: hello
        taskRef:
          resolver: cluster
          params:
            - name: kind
              value: task
            - name: name
              value: announce
            - name: namespace
              value: team-catlog
```

The namespace `team-catlog` is a typo. Apply it and read the failure:

```sh
kubectl apply -f pipelinerun-bad-name.yaml
kubectl wait --for=condition=Succeeded=False pipelinerun/bad-name -n starfleet --timeout=180s
kubectl get pipelinerun bad-name -n starfleet -o jsonpath='{.status.conditions[0].reason}: {.status.conditions[0].message}{"\n"}'
```

Again the reason is `CouldntGetTask`. The message says the Task was not found, and names the Task and namespace as the resolver saw them. Compare them letter by letter with the object; a typo is the most common cause.

## A run that waits forever

If no resolver answers, the run does not fail at once. It stays in `ResolvingTaskRef` until a timeout ends it. Causes are a resolver that is switched off with its flag, a Deployment `tekton-pipelines-remote-resolvers` that is not running, or a resolver name that does not exist. Check the Deployment first:

```sh
kubectl get deployment tekton-pipelines-remote-resolvers -n tekton-pipelines-resolvers
kubectl get configmap feature-flags -n tekton-pipelines-resolvers -o jsonpath='{.data}{"\n"}'
```

Then check the spelling of the `resolver` field. A request for a resolver that does not exist is never answered.

## A resolved definition that is invalid

The resolver can succeed and still deliver a file that Tekton rejects, for example a file that is not a Task, or a Task with a field that does not exist. The run fails with a validation message that names the field. The fix is in the source file, not in the run.

## A checklist

When a resolved run fails, ask in this order:

1. Is the reason `ResolvingTaskRef` for a long time, or a failure reason? Waiting means no answer; a failure means a wrong answer.
2. Do the parameters match the resolver? `cluster` needs `kind`, `name`, `namespace`; `git` needs `url`, `revision`, `pathInRepo`; `http` needs `url`.
3. Is the source reachable from the cluster and readable without a login?
4. Does the file validate as a Task or Pipeline?
5. Do the names inside the definition exist in the namespace of the run?

## Common pitfalls

> [!WARNING]
> - **Debugging the Pipeline when the Task was never fetched.** There are no TaskRuns to look at.
> - **Deleting the ResolutionRequest to retry.** Create a new run instead.
> - **Ignoring the resolver logs.** They hold the clone and API errors.
> - **Fixing a typo in a run that already failed.** A finished run does not retry; create a new one.
> - **Assuming a resolved Task is checked for safety.** It runs with the permissions of the run's service account.
