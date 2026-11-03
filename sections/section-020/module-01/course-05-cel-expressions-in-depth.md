# CEL Expressions In Depth

The guard part showed one CEL expression. This part covers the rules for writing them, because a CEL `when` fails in different ways from an `in` expression: some mistakes are caught when you apply the Pipeline and some only when the run evaluates the guard.

## The rules

CEL in `when` is an alpha feature in Tekton Pipelines v1.17.1 and needs `enable-cel-in-whenexpression: "true"` in the ConfigMap `feature-flags`. Then these rules hold:

- An entry of `when` uses either `cel`, or `input`, `operator` and `values`. One entry cannot use both.
- The expression must give a boolean. An expression that gives a string or a number is rejected.
- Several entries in one `when` list are combined with AND. For OR, write `||` inside one `cel` string.
- Tekton replaces `$(params.x)` and result references with their text before CEL reads the string. The replaced text is part of the expression, so wrap it in single quotes to make it a CEL string.
- A result reference is available only if the task that produces it is an earlier task of the same Pipeline.

## Useful expressions

CEL supports comparisons, `&&`, `||`, `!`, `in` for lists, and the string functions `startsWith`, `endsWith`, `contains` and `matches`. A few forms, each as the value of a `cel` field:

| Intent | Expression |
| --- | --- |
| Branch is main or a release branch | `'$(params.branch)' == 'main' \|\| '$(params.branch)'.startsWith('release/')` |
| A result says the check passed | `'$(tasks.scan.results.status)' == 'clean'` |
| The branch is one of several | `'$(params.branch)' in ['main', 'staging']` |
| A tag has the form of a version | `'$(params.tag)'.matches('^v[0-9]+\\.[0-9]+$')` |

The backslashes in the first row only protect the table. In YAML write plain `||`.

<!-- astrona:playground:renew -->

Save this as `pipeline-cel-rules.yaml`:

```yaml
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: cel-rules
  namespace: starfleet
spec:
  params:
    - name: branch
      type: string
  tasks:
    - name: publish
      when:
        - cel: "'$(params.branch)' == 'main' || '$(params.branch)'.startsWith('release/')"
      taskSpec:
        steps:
          - name: publish
            image: busybox:1.37.0
            script: |
              #!/bin/sh
              echo "publishing $(params.branch)"
```

Turn the flag on if it is off, then apply and run it on three branches:

```sh
kubectl patch configmap feature-flags -n tekton-pipelines --type merge -p '{"data":{"enable-cel-in-whenexpression":"true"}}'
kubectl apply -f pipeline-cel-rules.yaml
tkn pipeline start cel-rules -n starfleet -p branch=main --showlog
tkn pipeline start cel-rules -n starfleet -p branch=release/2 --showlog
tkn pipeline start cel-rules -n starfleet -p branch=feature/x --showlog
```

The first two runs publish. The third run succeeds with `publish` skipped. A skipped task shows in `status.skippedTasks` with a reason that names the guard.

## Where mistakes show

- A missing flag is rejected at `kubectl apply` by the webhook.
- An expression that does not compile is rejected at apply time too.
- An expression that compiles but fails while it runs, for example a comparison between a string and a number, ends the run with the reason `CELEvaluationFailed`.
- A missing quote around a replaced value is the most common failure: with `main` unquoted, CEL reads `main` as a variable name and cannot find it.

## When to prefer `in`

Use `input`, `operator` and `values` for a plain comparison. It is easier to read and works without a flag. Use CEL when you need `||`, a pattern, or a function. Do not move logic into CEL that a parameter or a Task could decide.

You can now write and debug CEL guards, and you know which mistakes appear at apply time and which appear in the run.

## Common pitfalls

> [!WARNING]
> - **Leaving a parameter unquoted in a CEL string.** CEL then reads it as a variable.
> - **Putting `cel` and `operator` in one entry.** The webhook rejects it.
> - **Expecting `cel` to work with the flag off.** The Pipeline is rejected at apply time.
> - **Returning a non-boolean value.** The expression must evaluate to true or false.
