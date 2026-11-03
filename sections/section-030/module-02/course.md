# Resolvers In Depth

A Pipeline that lives in one namespace and uses only Tasks from that namespace is the simplest case. Real platforms are different. One team keeps the reviewed Tasks of the company in a shared namespace. Another keeps its whole Pipeline in Git next to the application, so a pipeline change is a pull request. A third pulls a Task from a URL. Tekton calls the mechanism behind all of these remote resolution, and when it fails, the run fails before any pod exists. This module teaches how resolution works, how to use the `cluster`, `git` and `http` resolvers, how to limit them, and how to read the failures.

A resolver is a program in the Deployment `tekton-pipelines-remote-resolvers` that fetches the definition of a Task or a Pipeline from a place. The controller asks for it by creating a `ResolutionRequest` object, the resolver answers with the YAML, and the controller runs it as if it were written inline.

Keep one sentence in mind: **a resolver changes where a definition comes from, never where it runs.** The TaskRuns of a resolved Pipeline run in the namespace of the `PipelineRun`, with its service account and its secrets. Names inside the definition are looked up there too.

The module has four parts. **How Resolution Works** follows one request from the run to the answer. **The Cluster Resolver** shares Tasks and Pipelines between namespaces and limits the namespaces. **The Git And HTTP Resolvers** fetch from a repository and from a URL, and pin versions. **Read And Fix Resolution Failures** reads the reasons and the ResolutionRequest objects. A graded lab follows the fourth part.

## Learning objectives

After this module you can:

- Describe the path of a resolution: `taskRef` or `pipelineRef` with `resolver`, the `ResolutionRequest`, the resolver and the answer.
- Use the `cluster` resolver for a Task and for a Pipeline, and restrict it with `cluster-resolver-config`.
- Use the `git` resolver with `url`, `revision` and `pathInRepo`, and the `http` resolver with `url`.
- Pin a commit so that two runs get the same definition.
- Explain why a resolved Pipeline cannot refer to a local Task by name unless the run's namespace has it.
- Read `ResolvingTaskRef`, `CouldntGetPipeline` and `CouldntGetTask` and find the fault.

## Before you start

You need to know how a `taskRef` and a `pipelineRef` work, and the basic form of the `cluster` and `git` resolvers.

Your playground is a single-node `kind` cluster with these parts:

| Part of the playground | What it is |
| --- | --- |
| Namespace `tekton-pipelines` and `tekton-pipelines-resolvers` | Tekton Pipelines v1.17.1 with its controller, webhook and resolvers |
| Namespace `gitea` | Gitea at `http://gitea-http.gitea.svc.cluster.local:3000`, with the public repositories `starfleet/bridge` and `starfleet/tekton-catalog`, and a `tester` pod |
| Namespace `registry` | A container registry at `registry.registry.svc.cluster.local:5000`, plain HTTP, lab only |
| Namespace `starfleet` | The CI Tasks of the previous module and the ServiceAccount `ci-bot` |
| `tkn` on your PATH | The Tekton command-line tool, version 0.46.2 |

Every command in the parts runs against the playground cluster, and `kubectl` already points at it. This playground needs more memory than the others: give your container engine at least 6 GB.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
