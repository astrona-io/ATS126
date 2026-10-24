# Custom Tasks And Remote Resolution

A `taskRef` with only a `name` looks for a Task in the namespace of the run. That is fine for one team, but it breaks down quickly. A platform team wants to keep one reviewed copy of the build Task for every namespace. Another team keeps its Tasks in Git next to the code, so a change to a Task goes through the same review as a change to the code. And some steps of a pipeline are not pods at all: waiting for an approval, or calling an outside system. Tekton handles the first two with resolvers and the third with custom tasks. This part tries both resolvers that work offline in your playground, and then shows what a custom task is.

## Fetch a Task from another namespace

A resolver is a component that fetches a Task or Pipeline for the controller. The resolvers run in the Deployment `tekton-pipelines-remote-resolvers` in the namespace `tekton-pipelines-resolvers`. A `taskRef` uses one when it has a `resolver` field and `params` for it, instead of a `name`. The controller then creates a `ResolutionRequest` object, the resolver fills in the Task's YAML, and the controller runs it as if it were an embedded `taskSpec`.

The `cluster` resolver fetches from another namespace of the same cluster. It takes three parameters: `kind` (`task`, `pipeline` or `stepaction`), `name` and `namespace`. Start with a shared namespace and a Task in it.

<!-- astrona:playground:renew -->

Save this as `task-say-hello-catalog.yaml`:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: ci-catalog
---
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: say-hello
  namespace: ci-catalog
spec:
  params:
    - name: crew
      type: string
      default: bridge
  steps:
    - name: hello
      image: busybox:1.37.0
      script: |
        #!/bin/sh
        echo "Hello from the shared namespace, $(params.crew)!"
```

Save this as `pipelinerun-hello-cluster.yaml`:

```yaml
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  name: hello-cluster
  namespace: starfleet
spec:
  pipelineSpec:
    tasks:
      - name: hello
        taskRef:
          resolver: cluster
          params:
            - name: kind
              value: task
            - name: name
              value: say-hello
            - name: namespace
              value: ci-catalog
        params:
          - name: crew
            value: scout
```

Apply both, then check the result:

```sh
kubectl apply -f task-say-hello-catalog.yaml -f pipelinerun-hello-cluster.yaml
kubectl wait --for=condition=Succeeded pipelinerun/hello-cluster -n starfleet --timeout=120s
kubectl logs hello-cluster-hello-pod -n starfleet -c step-hello
kubectl get resolutionrequests -n starfleet
```

The log says `Hello from the shared namespace, scout!`, and the TaskRun and its pod live in `starfleet`, not in `ci-catalog`. Only the definition came from the other namespace. The last command lists the `ResolutionRequest` the controller created for it. The ConfigMap `cluster-resolver-config` in `tekton-pipelines-resolvers` decides which namespaces the resolver may read; its keys `allowed-namespaces` and `blocked-namespaces` are empty by default, so every namespace is allowed. If the Task does not exist in the named namespace, the run fails before any TaskRun with the reason `CouldntGetTask`.

## Fetch a Task from Git

The `git` resolver clones a repository and reads one file from it. Its main parameters are `url`, `revision` (a branch, tag or commit) and `pathInRepo`. With a `url`, it clones anonymously, so the repository must be public; for private repositories it can use a token from a Secret. The playground's Gitea has a public repository `starfleet/tekton-catalog` with the file `tasks/say-hello.yaml`.

Save this as `pipelinerun-hello-git.yaml`:

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
        params:
          - name: crew
            value: probe
```

Apply it, then check the result:

```sh
kubectl apply -f pipelinerun-hello-git.yaml
kubectl wait --for=condition=Succeeded pipelinerun/hello-git -n starfleet --timeout=180s
kubectl logs hello-git-hello-pod -n starfleet -c step-hello
kubectl get pipelinerun hello-git -n starfleet -o jsonpath='{.status.childReferences[0].name}{"\n"}'
```

The log says `Hello from the Git catalog, probe!`. A branch name such as `main` means "whatever `main` points to when the run starts", so two runs can get two different versions of the Task. Pin a commit hash in `revision` when you need the same Task every time; the git resolver also caches only resolutions by commit hash, by default.

The three other built-in resolvers work the same way, with their own parameters. The `bundles` resolver reads a Task from an OCI image, a Tekton bundle (`bundle`, `name`, `kind`). The `hub` resolver fetches from Artifact Hub (`name`, `version`, `kind`; the old Tekton Hub type is deprecated). The `http` resolver fetches a YAML file from a URL. All five are switched on in the ConfigMap `resolvers-feature-flags` of v1.17.1. The `bundles`, `hub` and `http` resolvers need access to the internet or a registry, so this course does not run them.

## Custom tasks and CustomRuns

A custom task is a pipeline task whose `taskRef` has an `apiVersion` and a `kind` that are not a Tekton Task, for example `apiVersion: example.dev/v1alpha1` and `kind: Wait`. For such a task, the controller does not create a TaskRun and no pod. It creates a `CustomRun` (`tekton.dev/v1beta1`), passes it the parameters, and waits. Another controller, one that watches `CustomRun` objects of that kind, must do the work and set the `Succeeded` condition. Projects have built custom tasks for waiting, for approvals and for loops; the `wait` example lives in the `tektoncd/experimental` repository and is not part of a Tekton Pipelines installation.

Your playground has no custom task controller. That makes it easy to see what Tekton Pipelines itself does and what it leaves to the other controller.

Save this as `pipelinerun-wait.yaml`:

```yaml
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  name: wait-1
  namespace: starfleet
spec:
  timeouts:
    pipeline: 45s
  pipelineSpec:
    tasks:
      - name: approval
        taskRef:
          apiVersion: example.dev/v1alpha1
          kind: Wait
        params:
          - name: duration
            value: 10s
```

Apply it, then look at the run and its child:

```sh
kubectl apply -f pipelinerun-wait.yaml
kubectl get pipelinerun wait-1 -n starfleet -o jsonpath='{range .status.childReferences[*]}{.kind}{" "}{.name}{"\n"}{end}'
kubectl get customruns -n starfleet
```

The child reference has the kind `CustomRun`, and `kubectl get customruns` shows `wait-1-approval` with an empty `SUCCEEDED` column: nobody reports on it. After 45 seconds, the timeout of the run, the controller sets the `CustomRun` to cancelled and ends the `PipelineRun` with `Succeeded` `False` and the reason `PipelineRunTimeout`. With a real controller installed, the `CustomRun` would get a condition and results, and the graph would go on like after a TaskRun.

You can now fetch Tasks from a shared namespace and from Git, and you know what a custom task needs before it can work. With the matrix, that is every building block of a CI pipeline. The open question is how to put them together into one Pipeline that is fast, safe and easy to read.

## Common pitfalls

> [!WARNING]
> - **Expecting the TaskRun in the resolver's namespace.** Only the definition is fetched; the TaskRun and its pod run in the namespace of the `PipelineRun`.
> - **Mixing `name` and `resolver` in one `taskRef`.** Use `name` for a Task in the same namespace, or `resolver` with `params`, not both.
> - **Pointing the git resolver at a private repository with `url`.** Anonymous cloning fails; use a public repository or a token Secret.
> - **Relying on a branch name for a stable Task.** `revision: main` can change between runs; pin a commit for the same Task every time.
> - **Waiting for a `CustomRun` without its controller.** Tekton Pipelines creates it but never runs it; only the timeout ends it.
