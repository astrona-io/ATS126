# Variables And Context

Parameters are the values you choose. A Pipeline also needs values that Tekton knows and you do not: the name of the run, its namespace, the name of the Pipeline, the status of other tasks. A step that tags an image with the run name, or a notification that names the namespace, needs these. Tekton offers them as variables, and it offers them in different places, so the same variable can work in one field and stay unreplaced in another. This part lists the variables, passes run information into a Task, and shows how to keep parameter values out of shell scripts.

## Substitution happens before the pod exists

The tekton-pipelines-controller replaces a variable with its value while it builds the TaskRun and its pod. The step container never sees `$(params.crew[0])`; it sees the text that replaced it. If a name is not known at that place, the controller leaves the text alone, and the shell may then try to run it as a command substitution, which usually fails with an error that says nothing about Tekton.

Variables of a `Pipeline` are available in the fields of the pipeline tasks and of the `finally` tasks:

- `$(params.<name>)` reads a Pipeline parameter.
- `$(tasks.<pipeline task>.results.<result>)` reads the result of another pipeline task.
- `$(context.pipelineRun.name)`, `$(context.pipelineRun.namespace)` and `$(context.pipelineRun.uid)` give the name, the namespace and the unique identifier of the current `PipelineRun`.
- `$(context.pipeline.name)` gives the name of the Pipeline.
- `$(context.pipelineTask.retries)` gives the `retries` value of the current pipeline task.
- In `finally` tasks only: `$(tasks.status)` is the aggregate status, `$(tasks.<pipeline task>.status)` the execution status of one task, and `$(tasks.<pipeline task>.reason)` its reason.

A Task has its own variables, which work inside its steps:

- `$(params.<name>)` reads a Task parameter.
- `$(workspaces.<name>.path)`, `.claim`, `.volume` and `.bound` describe a workspace.
- `$(results.<name>.path)` is the file that a step writes a result to.
- `$(context.taskRun.name)`, `$(context.taskRun.namespace)`, `$(context.taskRun.uid)` and `$(context.task.name)` describe the current TaskRun and Task.

The two lists do not mix. A Task cannot read `$(context.pipelineRun.name)`, because a Task does not know whether a Pipeline started it. The Pipeline reads the variable and passes it to the Task as a parameter.

## Pass run information into a Task

The Task `whoami` below prints its own context and the three values its Pipeline hands over.

<!-- astrona:playground:renew -->

Save this as `task-whoami.yaml`:

```yaml
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: whoami
  namespace: starfleet
spec:
  params:
    - name: run
      type: string
    - name: pipeline
      type: string
    - name: namespace
      type: string
  steps:
    - name: print
      image: busybox:1.37.0
      script: |
        #!/bin/sh
        echo "TaskRun:     $(context.taskRun.name)"
        echo "Task:        $(context.task.name)"
        echo "PipelineRun: $(params.run)"
        echo "Pipeline:    $(params.pipeline)"
        echo "Namespace:   $(params.namespace)"
```

Save this as `pipeline-identify.yaml`:

```yaml
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: identify
  namespace: starfleet
spec:
  tasks:
    - name: who
      taskRef:
        name: whoami
      params:
        - name: run
          value: $(context.pipelineRun.name)
        - name: pipeline
          value: $(context.pipeline.name)
        - name: namespace
          value: $(context.pipelineRun.namespace)
  finally:
    - name: summary
      taskSpec:
        steps:
          - name: print
            image: busybox:1.37.0
            script: |
              #!/bin/sh
              echo "Aggregate status: $(tasks.status)"
              echo "who: $(tasks.who.status), reason $(tasks.who.reason)"
```

Apply both and start the Pipeline:

```sh
kubectl apply -f task-whoami.yaml -f pipeline-identify.yaml
tkn pipeline start identify -n starfleet --prefix-name identify --showlog
```

The log of `who` prints the generated name of the TaskRun, the Task name `whoami`, the name of the `PipelineRun` that starts with `identify-`, the Pipeline name `identify` and the namespace `starfleet`. The log of `summary` prints the aggregate status `Succeeded` and the status and reason of `who`. Each value is a plain string by the time the step runs. The pod shows it: the script text in its container arguments already holds the values.

## Keep parameter values out of scripts

Substitution is text replacement, so a parameter value becomes part of the script. A value such as `x"; rm -rf /workspace; echo "` would turn into shell commands. Tekton does not escape values for you. The safe pattern is to put the value in an environment variable and let the shell read the variable. The shell never parses the contents of a variable as code.

Save this as `task-safe-echo.yaml`:

```yaml
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: safe-echo
  namespace: starfleet
spec:
  params:
    - name: message
      type: string
  steps:
    - name: echo
      image: busybox:1.37.0
      env:
        - name: MESSAGE
          value: $(params.message)
      script: |
        #!/bin/sh
        set -eu
        printf 'Message: %s\n' "$MESSAGE"
```

Run it with a value that would break a naive script:

```sh
kubectl apply -f task-safe-echo.yaml
tkn task start safe-echo -n starfleet -p message='x"; echo INJECTED; echo "' --showlog
```

The log prints the whole text after `Message:` as one string, and the word `INJECTED` appears only as part of that string. Had the script contained `echo "$(params.message)"` directly, the shell would have run the second `echo` as a command. The same advice applies to every value that comes from outside the cluster, such as a branch name or a pull request title.

You now know which variables exist in a Pipeline and in a Task, how a Pipeline passes run information to a Task, and why parameter values belong in environment variables. The next topic is the other thing Tasks share: volumes, and the ways a `PipelineRun` can provide them.

## Common pitfalls

> [!WARNING]
> - **Using `$(context.pipelineRun.name)` inside a Task.** Only a Pipeline can read it. Pass it to the Task as a parameter.
> - **Using `$(tasks.<name>.status)` outside `finally`.** The variable exists only in `finally` tasks; elsewhere it stays unreplaced.
> - **Writing `$(params.x)` inside a shell script with untrusted values.** The value becomes code. Use an `env` entry and read `"$X"`.
> - **Mixing up the names.** `$(tasks.<name>...)` takes the name of the pipeline task, not the name of the Task.
> - **Expecting Tekton to escape quotes.** It replaces the text and nothing more.
