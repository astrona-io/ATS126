# Parameters, Variables And Workspaces In Depth

A Pipeline that only takes one string and one shared volume is easy to write and hard to reuse. The `starfleet` team wants one Pipeline that takes a list of crew members, a group of settings for a release, a configuration file and an optional cache, and that still works when some of them are not given. Tekton supports all of this, but each feature has rules about where it is allowed, and the rules decide whether a run starts or fails before any TaskRun exists. This module teaches those rules.

A parameter is a named input of a `Task` or a `Pipeline`. Its type can be a string, an array or an object. A variable is a text such as `$(params.crew)` that the tekton-pipelines-controller replaces with a value before it creates a pod. A workspace is a named volume that a Task declares and a `PipelineRun` binds to a real volume. The module looks at each of the three in detail.

Keep one sentence in mind: **the controller substitutes variables as text before the pod exists.** A variable that the controller cannot resolve fails the run early. A value that ends up inside a script is part of the script. A workspace that is not bound is either an error or, if the Task marks it optional, simply absent.

The module has four parts. **Parameter Types And Defaults** uses string, array and object parameters and reads the reasons for type errors. **Variables And Context** lists which variables exist where, and passes run information into Tasks. **Workspace Volume Sources** binds a ConfigMap, a Secret, an `emptyDir` and a PersistentVolumeClaim. **Optional Workspaces, Sub-Paths And Scheduling** covers workspaces that may be missing, one volume used by several tasks, and how the pods that share a volume land on one node. A graded lab follows the fourth part.

## Learning objectives

After this module you can:

- Declare string, array and object parameters with defaults, and pass each type from a `Pipeline` to a `Task`.
- Use `$(params.name[*])`, `$(params.name[0])` and `$(params.name.key)` in the places where they are allowed.
- Name the reasons `ParameterMissing`, `ParameterTypeMismatch` and `ObjectParameterMissKeys` and fix the run that shows them.
- Pass run information with `$(context.pipelineRun.name)` and friends, and keep parameter values out of scripts with environment variables.
- Bind a workspace to a ConfigMap, a Secret, an `emptyDir`, a PersistentVolumeClaim or a `volumeClaimTemplate`, and explain which of them can be written.
- Mark a workspace optional, test it with `$(workspaces.<name>.bound)`, give tasks a `subPath`, and read the `coschedule` setting.

## Before you start

You need to know how a `Pipeline` passes parameters and workspaces to pipeline tasks, how results move between tasks, and how a `PipelineRun` starts the Pipeline and binds a volume.

Your playground is a single-node `kind` cluster with these parts:

| Part of the playground | What it is |
| --- | --- |
| Namespace `tekton-pipelines` | Tekton Pipelines v1.17.1: the controller, the webhook and the events controller |
| Namespace `tekton-pipelines-resolvers` | The remote resolvers |
| Namespace `starfleet` | Empty. Your Tasks, Pipelines and runs go here |
| StorageClass `standard` | The `kind` local-path provisioner, which creates the volumes for workspaces |
| `tkn` on your PATH | The Tekton command-line tool, version 0.46.2 |

Every command in the parts runs against the playground cluster, and `kubectl` already points at it.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
