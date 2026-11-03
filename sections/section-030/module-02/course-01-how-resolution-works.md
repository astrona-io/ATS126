# How Resolution Works

When a `taskRef` has a `name`, the controller reads a Task from the namespace of the run. When it has a `resolver`, the controller has to ask someone else. That someone is a resolver, and the conversation happens through a Kubernetes object. Knowing the path makes failures easy to place, because each step leaves a trace you can read. This part follows one resolution from start to end.

## The path of a request

1. The `PipelineRun` or `TaskRun` has a `taskRef` or `pipelineRef` with `resolver: <name>` and a list of `params`.
2. The tekton-pipelines-controller creates a `ResolutionRequest` object in the namespace of the run. It holds the resolver name and the params.
3. The Deployment `tekton-pipelines-remote-resolvers` in the namespace `tekton-pipelines-resolvers` watches these objects. The resolver with the matching name fetches the content.
4. The resolver writes the content and a checksum into the `ResolutionRequest`.
5. The controller reads the content, checks that it is a valid Task or Pipeline, and continues as if the definition were embedded.

Until step 4, the run shows a waiting reason. While a pipeline task is being fetched, the PipelineRun has the reason `ResolvingTaskRef`; for the Pipeline itself it is `ResolvingPipelineRef`. A TaskRun shows `ResolvingTaskRef`.

## Watch a ResolutionRequest

<!-- astrona:playground:renew -->

Save this as `pipelinerun-hello-git.yaml`. It fetches the Task `say-hello` from the Git repository of the playground:

```yaml
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  name: hello-git
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
              value: tasks/say-hello.yaml
```

Apply it and look at the objects:

```sh
kubectl apply -f pipelinerun-hello-git.yaml
kubectl wait --for=condition=Succeeded pipelinerun/hello-git -n starfleet --timeout=180s
kubectl get resolutionrequests -n starfleet
```

The list shows one `ResolutionRequest` for the run, with the column `SUCCEEDED` set to `True`. The object stays after the run, owned by it. Read what the resolver stored:

```sh
kubectl get resolutionrequests -n starfleet -o jsonpath='{.items[0].spec.params}{"\n"}{.items[0].status.annotations}{"\n"}'
```

The first part shows the params you wrote. The second shows details the resolver adds, such as the resolved path and the repository. The content itself is in `status.data` as base64 text.

## Resolve a whole Pipeline

Resolvers work for `pipelineRef` too. The run asks for a Pipeline instead of a Task and nothing else changes:

```yaml
spec:
  pipelineRef:
    resolver: git
    params:
      - name: url
        value: http://gitea-http.gitea.svc.cluster.local:3000/starfleet/bridge.git
      - name: revision
        value: main
      - name: pathInRepo
        value: pipeline.yaml
```

This fragment shows the shape only; the repository of the playground does not hold a Pipeline file. The `cluster` resolver, covered next, is the one you can try with a Pipeline in your own namespace.

## Names inside a resolved definition

The resolved definition runs in the namespace of the run. A resolved Pipeline that contains `taskRef: {name: build}` looks for a Task named `build` in the namespace of the **run**, not in the namespace the Pipeline came from. The run fails if the Task is not there. A shared Pipeline therefore should embed its tasks with `taskSpec`, or use resolvers for its own tasks, or the run's namespace must hold the Tasks.

## Resolvers can be switched off

The ConfigMap `feature-flags` in the namespace `tekton-pipelines-resolvers` has one flag per built-in resolver: `enable-cluster-resolver`, `enable-git-resolver`, `enable-hub-resolver`, `enable-bundles-resolver` and `enable-http-resolver`. A cluster owner switches a resolver off with the value `"false"`. A run that uses a disabled resolver waits and then fails, because no one answers the request.

## Common pitfalls

> [!WARNING]
> - **Expecting the resolved Pipeline to find Tasks in its home namespace.** Local names resolve in the namespace of the run.
> - **Reading only the PipelineRun when resolution fails.** The `ResolutionRequest` has the resolver's own message.
> - **Using `revision: main` and expecting a stable definition.** A branch moves.
> - **Disabling a resolver and forgetting who used it.** Runs that depend on it fail.
> - **Expecting `metadata.namespace` of the resolved object to matter.** The definition runs in the namespace of the run.
