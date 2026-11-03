# The Git And HTTP Resolvers

A namespace works for one cluster. A Git repository works for every cluster and gives you history, review and tags for free. The `git` resolver reads a file from a repository, and the `http` resolver reads a file from any URL. Both fetch a definition at run time, so the question is which version a run gets. This part uses both against the Gitea server of the playground, pins a commit, and reads the configuration of the git resolver.

## The git resolver

The parameters are:

| Parameter | Meaning |
| --- | --- |
| `url` | The clone URL of the repository |
| `revision` | A branch, a tag or a commit hash |
| `pathInRepo` | The path of the file in the repository |

The resolver also accepts `org`, `repo` and `token` style parameters for repositories on a hosted service such as GitHub or Gitea, which use the API instead of a clone; a plain `url` works for any server that Git can clone. The resolver clones anonymously unless the cluster owner configures a token.

Read the repository of the playground first. You can ask Gitea for the list of commits of the catalog:

<!-- astrona:playground:renew -->

```sh
kubectl -n gitea exec tester -- curl -s "http://gitea-http.gitea.svc.cluster.local:3000/api/v1/repos/starfleet/tekton-catalog/commits?limit=5"
```

The answer is JSON with one entry per commit. The field `sha` of the newest entry is the commit that `main` points to. Copy the first `sha` value and use it as `<COMMIT>` below.

## Pin a commit

Save this as `pipelinerun-pinned.yaml`, with `<COMMIT>` replaced:

```yaml
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  name: pinned
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
              value: <COMMIT>
            - name: pathInRepo
              value: tasks/say-hello.yaml
```

Apply it and wait:

```sh
kubectl apply -f pipelinerun-pinned.yaml
kubectl wait --for=condition=Succeeded pipelinerun/pinned -n starfleet --timeout=180s
```

A commit hash names one version of the file forever. A branch name names whatever the branch holds at the moment. A tag is in between: it should not move, but Git allows moving it. For anything that ships, pin the commit, and let a pull request change the hash when the Task should change.

## The configuration

The ConfigMap `git-resolver-config` in `tekton-pipelines-resolvers` holds the defaults of the git resolver. The keys used most are:

| Key | Meaning |
| --- | --- |
| `default-revision` | Revision used when a reference gives none (`main`) |
| `default-url` | Repository used when a reference gives none |
| `fetch-timeout` | How long a clone may take (`1m`) |
| `scm-type` and `server-url` | The kind and address of the hosted service for API access |
| `api-token-secret-name`, `api-token-secret-key`, `api-token-secret-namespace` | The Secret that holds the token for the API |

Read what your cluster has:

```sh
kubectl get configmap git-resolver-config -n tekton-pipelines-resolvers -o jsonpath='{.data}{"\n"}'
```

A slow server or a big repository can exceed `fetch-timeout` and make the resolution fail. Raise it for such servers.

## The http resolver

The `http` resolver takes one parameter, `url`, and returns the file behind it. The file must be a Task or Pipeline in YAML. Gitea serves the raw file of a branch at a URL of the form `.../raw/branch/<branch>/<path>`.

Save this as `pipelinerun-http.yaml`:

```yaml
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  name: hello-http
  namespace: starfleet
spec:
  pipelineSpec:
    tasks:
      - name: hello
        taskRef:
          resolver: http
          params:
            - name: url
              value: http://gitea-http.gitea.svc.cluster.local:3000/starfleet/tekton-catalog/raw/branch/main/tasks/say-hello.yaml
```

Apply it and compare the two runs:

```sh
kubectl apply -f pipelinerun-http.yaml
kubectl wait --for=condition=Succeeded pipelinerun/hello-http -n starfleet --timeout=180s
kubectl get resolutionrequests -n starfleet
```

Both resolvers returned the same Task. The difference is what they know. The git resolver knows revisions, so it can pin a commit. The http resolver only knows a URL: it cannot tell a commit from a branch, and a file served from a moving URL changes under you. For private files, the resolver can send a user name and a password from a Secret, but a token-based `git` resolver is the cleaner path.

## Which resolver for which job

| Need | Resolver |
| --- | --- |
| Share between namespaces of one cluster | `cluster` |
| Version and review in Git | `git` |
| One file at a fixed URL | `http` |
| Versioned, signed artifacts in a registry | `bundles` |
| Public community Tasks | `hub` |

## Common pitfalls

> [!WARNING]
> - **Using a branch for a release Pipeline.** The run can change when someone pushes.
> - **Putting a clone URL into the `http` resolver.** It needs the raw file URL.
> - **Pointing `pathInRepo` at a directory.** It must name one file.
> - **Forgetting that the repository must be reachable from the cluster.** The resolver runs in the cluster.
> - **Putting a token in a parameter.** Use the Secret that the configuration names.
