# The Cluster Resolver

The simplest shared catalog is a namespace. A platform team puts reviewed Tasks and Pipelines into one namespace, and every other namespace refers to them with the `cluster` resolver. No Git server, no registry, no network. This part shares a Task and a Pipeline that way, shows what a resolved Pipeline can and cannot refer to, and limits which namespaces the resolver may read.

## The parameters

The `cluster` resolver takes three parameters:

| Parameter | Meaning |
| --- | --- |
| `kind` | `task`, `pipeline` or `stepaction`, in lowercase |
| `name` | The name of the object |
| `namespace` | The namespace that holds it |

Set `kind`, `name` and `namespace` explicitly. The resolver has defaults for `kind` and `namespace` in its configuration, but a reader of your YAML should not need to know them.

## Share a Task and a Pipeline

<!-- astrona:playground:renew -->

Save this as `catalog.yaml`:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: team-catalog
---
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: announce
  namespace: team-catalog
spec:
  params:
    - name: message
      type: string
  results:
    - name: line
  steps:
    - name: announce
      image: busybox:1.37.0
      script: |
        #!/bin/sh
        echo "announce: $(params.message)" | tee $(results.line.path)
---
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: release-flow
  namespace: team-catalog
spec:
  params:
    - name: target
      type: string
      default: dev
  results:
    - name: summary
      value: $(tasks.plan.results.summary)
  tasks:
    - name: plan
      params:
        - name: target
          value: $(params.target)
      taskSpec:
        params:
          - name: target
        results:
          - name: summary
        steps:
          - name: plan
            image: busybox:1.37.0
            script: |
              #!/bin/sh
              echo "deploy $(params.target)" | tee $(results.summary.path)
```

Apply it:

```sh
kubectl apply -f catalog.yaml
```

Two runs show the two forms. Save this as `pipelinerun-shared.yaml`. Its task fetches the shared Task:

```yaml
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  name: shared-task
  namespace: starfleet
spec:
  pipelineSpec:
    results:
      - name: line
        value: $(tasks.call.results.line)
    tasks:
      - name: call
        params:
          - name: message
            value: ready
        taskRef:
          resolver: cluster
          params:
            - name: kind
              value: task
            - name: name
              value: announce
            - name: namespace
              value: team-catalog
```

Save this as `pipelinerun-shared-pipeline.yaml`. This run fetches the whole Pipeline:

```yaml
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  name: shared-pipeline
  namespace: starfleet
spec:
  params:
    - name: target
      value: prod
  pipelineRef:
    resolver: cluster
    params:
      - name: kind
        value: pipeline
      - name: name
        value: release-flow
      - name: namespace
        value: team-catalog
```

Apply both and read the results:

```sh
kubectl apply -f pipelinerun-shared.yaml -f pipelinerun-shared-pipeline.yaml
kubectl wait --for=condition=Succeeded pipelinerun/shared-task pipelinerun/shared-pipeline -n starfleet --timeout=180s
kubectl get pipelinerun shared-task shared-pipeline -n starfleet -o jsonpath='{range .items[*]}{.metadata.name}{": "}{.status.results[0].value}{"\n"}{end}'
kubectl get pods -n starfleet -l tekton.dev/pipelineRun=shared-pipeline -o custom-columns='POD:.metadata.name,NS:.metadata.namespace'
```

The results are `announce: ready` and `deploy prod`. The pods of both runs are in `starfleet`, not in `team-catalog`. The catalog only supplied the definition.

## Limit which namespaces can be read

By default the resolver can read any namespace. The ConfigMap `cluster-resolver-config` in `tekton-pipelines-resolvers` narrows that:

| Key | Effect |
| --- | --- |
| `default-kind` | The kind used when a reference gives none |
| `default-namespace` | The namespace used when a reference gives none |
| `allowed-namespaces` | Comma-separated list; only these namespaces can be read |
| `blocked-namespaces` | Comma-separated list; these namespaces can never be read |

Read it:

```sh
kubectl get configmap cluster-resolver-config -n tekton-pipelines-resolvers -o jsonpath='{.data}'
```

The release manifest holds the keys with empty values or only a documentation key. A cluster owner who sets `allowed-namespaces` to `team-catalog` makes `team-catalog` the only shared source. A reference to any other namespace then fails. Use `blocked-namespaces` for namespaces that hold secrets or private Tasks.

## Common pitfalls

> [!WARNING]
> - **Writing `kind: Task` with a capital letter.** The values are lowercase.
> - **Leaving out `namespace`.** The resolver then uses its default, which may not be where your object is.
> - **Sharing a Pipeline whose tasks use `taskRef` by name.** The names resolve in the namespace of the run.
> - **Changing the shared Task and expecting old runs to follow.** A run copies the definition when it resolves.
> - **Treating the catalog namespace as a security boundary by itself.** Anyone who can create a run can read what the resolver can read, unless `allowed-namespaces` limits it.
