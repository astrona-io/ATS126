# The Hub Resolver

The `hub` resolver fetches a Task or a Pipeline from a catalog on the internet. By default the catalog is Artifact Hub; Tekton Hub is the other supported kind. A team can use a maintained `git-clone` or `buildah` Task without copying its YAML into the cluster. In exchange, the cluster needs outbound access to the hub, and the Task comes from outside your control.

## Parameters

| Parameter | Meaning |
| --- | --- |
| `catalog` | The catalog name. For Artifact Hub the default catalog is `tekton-catalog-tasks` |
| `kind` | `task` or `pipeline` |
| `name` | The name of the resource in the catalog |
| `version` | The version of the resource |
| `type` | `artifact` for Artifact Hub, `tekton` for Tekton Hub; the default is `artifact` |

The resolver has its own flag, `enable-hub-resolver`, in `resolvers-feature-flags`, and its settings, such as the URL of the hub API, are in the ConfigMap `hubresolver-config`. Read both:

<!-- astrona:playground:renew -->

```sh
kubectl get configmap resolvers-feature-flags -n tekton-pipelines-resolvers -o jsonpath='{.data}{"\n"}'
kubectl get configmap hubresolver-config -n tekton-pipelines-resolvers -o jsonpath='{.data}{"\n"}'
```

## A reference

```yaml
taskRef:
  resolver: hub
  params:
    - name: catalog
      value: tekton-catalog-tasks
    - name: kind
      value: task
    - name: name
      value: git-clone
    - name: version
      value: "0.9"
```

Write the version as a string in quotes, because YAML would read `0.9` as a number. A cluster without a route to the internet cannot fetch this Task, and the run ends with the reason `CouldntGetTask`. The message names the hub address, not a registry, which tells you which resolver failed.

## Using the hub safely

- Pin a version. A reference without `version` takes whatever the hub returns as the latest.
- Review the Task before you trust it. Its steps run in your cluster with your service account.
- Do not let release pipelines depend on a public service being up. Many teams copy reviewed Tasks into a bundle or a Git repository they control, and reference that.
- A cluster owner can switch the resolver off with the flag if the policy forbids outside code.

## Choosing a resolver

| Need | Resolver |
| --- | --- |
| A Task shared inside the cluster | `cluster` |
| A definition that is reviewed with the application code | `git` |
| A versioned artifact in the registry you already run | `bundles` |
| A maintained community Task | `hub`, with a pinned version |
| One file at a known URL | `http` |

You can now use all five resolvers, choose between them, and say which risk each one adds.

## Common pitfalls

> [!WARNING]
> - **Writing the version as a number.** `0.9` in YAML is a float; quote it.
> - **Omitting `version`.** The result can change between runs.
> - **Using the hub from a cluster without outbound access.** The run fails with `CouldntGetTask`.
> - **Trusting a catalog Task without reading it.** It runs with your permissions.
