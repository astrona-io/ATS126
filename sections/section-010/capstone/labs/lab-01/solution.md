# Solution: Repair A Release Notes Pipeline

Work the task yourself first. Running `astrona submit -c sections/section-010/capstone/labs/lab-01` after a step tells you which checks pass, without telling you what is left.

The grader checks three things: the Pipeline runs the two checks after `fetch` only and passes `channel` to `publish`; `release-notes-run` binds `source`, succeeded with the expected notice, its two checks overlapped and `publish` waited for both; and a new run with `channel` = `outpost-news` reports the right notice.

## Step 1: Read the first failure

Start with the PipelineRun:

```sh
kubectl get pipelinerun release-notes-run -n starfleet -o jsonpath='{.status.conditions[0].reason}{"\n"}{.status.conditions[0].message}{"\n"}'
kubectl get taskruns -n starfleet -l tekton.dev/pipelineRun=release-notes-run
```

The reason is `InvalidWorkspaceBindings`, and the message says that the PipelineRun does not bind the Pipeline's workspaces correctly. No TaskRun exists. Compare the names:

```sh
kubectl get pipeline release-notes -n starfleet -o jsonpath='{.spec.workspaces[*].name}{"\n"}'
kubectl get pipelinerun release-notes-run -n starfleet -o jsonpath='{.spec.workspaces[*].name}{"\n"}'
```

The Pipeline declares `source`; the PipelineRun binds `notes`.

## Step 2: Create the run again with the right workspace name

A started `PipelineRun` cannot change its spec. Write it to a file with the right name, delete the old one and create it again.

Save this as `pipelinerun-release-notes-run.yaml`:

```yaml
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  name: release-notes-run
  namespace: starfleet
spec:
  pipelineRef:
    name: release-notes
  params:
    - name: version
      value: v1.4
  workspaces:
    - name: source
      volumeClaimTemplate:
        spec:
          accessModes:
            - ReadWriteOnce
          resources:
            requests:
              storage: 16Mi
```

Then replace the run:

```sh
kubectl delete pipelinerun release-notes-run -n starfleet
kubectl apply -f pipelinerun-release-notes-run.yaml
kubectl get pipelinerun release-notes-run -n starfleet -o jsonpath='{.status.conditions[0].reason}{"\n"}{.status.conditions[0].message}{"\n"}'
```

The run fails again at once, now with `PipelineValidationFailed`. The message says that the Task `publish-notes` is missing values for params which have no default values: `channel`. The Pipeline declares a parameter `channel` with the default `launch-news`, but the pipeline task `publish` never passes it on. A Pipeline parameter is not handed to the Tasks by itself.

## Step 3: Pass channel and run the checks in parallel

While you edit the Pipeline, look at the edges of the two checks too:

```sh
kubectl get pipeline release-notes -n starfleet -o jsonpath='{range .spec.tasks[*]}{.name}{" after: "}{.runAfter}{"\n"}{end}'
```

`spellcheck` runs after `lint`, but it only reads `notes.md`, which `fetch` writes. That edge makes the run wait about ten seconds longer than it has to. Fix both in one file.

Save this as `pipeline-release-notes.yaml`:

```yaml
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: release-notes
  namespace: starfleet
spec:
  params:
    - name: version
      type: string
    - name: channel
      type: string
      default: launch-news
  workspaces:
    - name: source
  results:
    - name: notice
      value: $(tasks.publish.results.notice)
  tasks:
    - name: fetch
      taskRef:
        name: fetch-notes
      params:
        - name: version
          value: $(params.version)
      workspaces:
        - name: source
          workspace: source
    - name: lint
      runAfter:
        - fetch
      taskRef:
        name: lint-notes
      workspaces:
        - name: source
          workspace: source
    - name: spellcheck
      runAfter:
        - fetch
      taskRef:
        name: spellcheck-notes
      workspaces:
        - name: source
          workspace: source
    - name: publish
      taskRef:
        name: publish-notes
      params:
        - name: revision
          value: $(tasks.fetch.results.revision)
        - name: lines
          value: $(tasks.lint.results.lines)
        - name: words
          value: $(tasks.spellcheck.results.words)
        - name: channel
          value: $(params.channel)
```

`publish` needs no `runAfter`: its three result references already make it wait for `fetch`, `lint` and `spellcheck`.

Apply it, and create the run once more:

```sh
kubectl apply -f pipeline-release-notes.yaml
kubectl delete pipelinerun release-notes-run -n starfleet
kubectl apply -f pipelinerun-release-notes-run.yaml
kubectl wait --for=condition=Succeeded pipelinerun/release-notes-run -n starfleet --timeout=300s
```

## Step 4: Check the result and the order

```sh
kubectl get pipelinerun release-notes-run -n starfleet -o jsonpath='{.status.results[?(@.name=="notice")].value}{"\n"}'
kubectl get taskruns -n starfleet -l tekton.dev/pipelineRun=release-notes-run --sort-by=.status.startTime -o custom-columns='TASK:.metadata.labels.tekton\.dev/pipelineTask,START:.status.startTime,END:.status.completionTime'
```

The notice is `notes-v1.4 to launch-news: 3 lines, 11 words`. `lint` and `spellcheck` start within a second or two of each other, both after `fetch` ended, and `publish` starts after both ended.

## Step 5: Submit

```sh
astrona submit -c sections/section-010/capstone/labs/lab-01
```

## Why the obvious shortcuts are wrong

| Shortcut | What happens |
| --- | --- |
| Rename the Pipeline workspace to `notes` | The run then works, but other runs and the grader bind `source` |
| Give `channel` a default in the Task `publish-notes` | Every run publishes to that default, and the grader's run with `outpost-news` reports the wrong channel |
| Type `launch-news` into the pipeline task `publish` | The grader's run with `channel` = `outpost-news` still reports `launch-news` |
| Remove `runAfter` from `spellcheck` completely | `spellcheck` may read `notes.md` before `fetch` writes it |
| Leave `spellcheck` after `lint` because the run succeeds | The checks do not overlap; the grader compares their times |

## Common mistakes

- Thinking a Pipeline parameter reaches every Task. It reaches only the pipeline tasks that pass it with `$(params.<name>)`.
- Stopping after the run succeeds. A graph can be correct and still slower than designed; read the times.
- Adding `runAfter: [lint, spellcheck]` to `publish` as well. It does no harm, but the result references already give that order.

## Practice on your own

- Start the Pipeline with `tkn pipeline start release-notes -n starfleet -p version=v3.0 -w name=source,volumeClaimTemplateFile=<file>` and leave out `channel`. Which value does the notice show?
- Add a fifth task that runs in parallel with `publish` and needs only `fetch`. Predict its start time before you run it.
- Bind the workspace to `emptyDir: {}` and read which task fails, and why.
