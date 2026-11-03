# The Bundles Resolver

The `cluster`, `git` and `http` resolvers fetch a definition as YAML. The `bundles` resolver fetches it from an OCI image in a container registry. A Tekton bundle is an image whose layers hold Tekton objects, so the registry that already stores your images can also store, version and distribute your Tasks and Pipelines. Access control, tags and digests then work the same way as for any image.

## Parameters

A `taskRef` or `pipelineRef` with `resolver: bundles` takes these parameters:

| Parameter | Meaning |
| --- | --- |
| `bundle` | The image reference of the bundle: a registry host, a repository and a tag or digest |
| `name` | The name of the object inside the bundle |
| `kind` | `task` or `pipeline`; the default is `task` |

The resolver is enabled with the flag `enable-bundles-resolver` in the ConfigMap `resolvers-feature-flags` of the namespace `tekton-pipelines-resolvers`. Read it:

<!-- astrona:playground:renew -->

```sh
kubectl get configmap resolvers-feature-flags -n tekton-pipelines-resolvers -o jsonpath='{.data}{"\n"}'
```

The ConfigMap `bundleresolver-config` in the same namespace holds the defaults of the resolver, such as the default `kind` and the default service account used to read private registries.

## Using a bundle

A reference looks like this. The registry address is the playground registry, which accepts plain HTTP for lab use. A production registry would use TLS and a digest.

```yaml
taskRef:
  resolver: bundles
  params:
    - name: bundle
      value: registry.registry.svc.cluster.local:5000/starfleet/tasks:v1
    - name: name
      value: announce
    - name: kind
      value: task
```

A bundle is built and pushed with the `tkn bundle push` command from Task files. The command reads the files, puts each object in a layer, and pushes the image. It needs a registry that the machine running it can reach, so it is not part of the exercises of this course.

## Why teams use bundles

- A digest in the reference, written as `repository@sha256:<digest>`, names exactly one version. Nobody can change what it points to, unlike a branch or a tag.
- Registries already have permissions, replication and scanning, so no second system for Tasks is needed.
- A bundle holds many objects, and one version label covers all of them.

The costs are a build and push step for every change, and registry credentials for the run when the registry is private. The resolver reads credentials through the service account of the run.

## Reading a bundle failure

A bundle that cannot be fetched ends the run with the reason `CouldntGetTask` or `CouldntGetPipeline`, and the message carries the registry error. The usual causes are a wrong reference, a name that the bundle does not contain, a registry without anonymous access and no credentials, and a registry that needs TLS while the reference points to a plain HTTP address. Read the `ResolutionRequest` of the run to see the message:

```sh
kubectl get resolutionrequests -n starfleet
kubectl get resolutionrequest <NAME> -n starfleet -o jsonpath='{.status.conditions}{"\n"}'
```

You can now describe how the `bundles` resolver finds a definition, which parameters it needs, and how to read its failures.

## Common pitfalls

> [!WARNING]
> - **Using a tag in a release Pipeline.** A tag can be pushed again. Use a digest.
> - **Writing `Task` for `kind`.** The values are lowercase.
> - **Naming the image instead of the object in `name`.** `name` selects an object inside the bundle.
> - **Forgetting registry credentials.** A private registry needs a secret on the service account of the run.
