---
estimated_duration: 45m
---

# Repair A Broken CI Pipeline

- **ID:** CAPSTONE
- **Slug:** ats-126-capstone-030
- **Author:** Paris Nakita Kejser
- **Type:** Astrona graded capstone

Graded capstone for section 030, in the namespaces `starfleet` and `ci-catalog`, with Gitea and a registry in the cluster. Read `question.md` for the task; `solution.md` is the walkthrough.

> **Not yet run.** This capstone was written from the Tekton v1.17.1
> documentation and has not passed `astrona test` yet.

## Run it

```sh
astrona run -c .
astrona submit
astrona destroy ats-126-capstone-030
```

`astrona destroy` takes the environment name (`metadata.name` = `ats-126-capstone-030`), not
the config path.

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Environment definition, bootstrap and grading |
| `question.md` | The task |
| `solution.md` | Step-by-step walkthrough |
| `prerequisites.md` | Assumed knowledge and what the environment provides |
| `bootstrap/` | tkn CLI and Tekton Pipelines; then Gitea, the registry, the repository, ci-bot, the Tasks, the broken Pipeline and two failed runs |
| `manifests/` | `lab-start.yaml`, `ci-tasks.yaml` (starfleet), `ci-catalog.yaml` (the Task `build-image`), `ci-rbac.yaml`, the broken `pipeline-bridge-ci.yaml` (four faults), the two runs, and the files committed to Gitea under `gitea/` |
| `solution/` | Reference solution used by `astrona test`: the fixed Pipeline and the two runs |
| `testing/` | Waits for Tekton, Gitea and the registry |
| `validation/` | Grading scripts, one per check; the last one runs its own PipelineRun on the branch `broken` |
