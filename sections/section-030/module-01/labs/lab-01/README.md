---
estimated_duration: 45m
---

# Build An End-To-End CI Pipeline

- **ID:** LAB
- **Slug:** ats-126-lab-030-01
- **Author:** Paris Nakita Kejser
- **Type:** Astrona graded lab

Graded lab for the namespace `starfleet`, with Gitea and a registry in the cluster. Read `question.md` for the task; `solution.md` is the walkthrough.

Not yet run: this lab was written from the Tekton v1.17.1 documentation and
has not passed `astrona validate` or `astrona test` yet. The kaniko task was
tried against `registry:3.0.0` with Podman outside a cluster; nothing else ran.

## Run it

```sh
astrona run -c .
astrona submit
astrona destroy ats-126-lab-030-01
```

`astrona destroy` takes the environment name (`metadata.name` = `ats-126-lab-030-01`), not
the config path.

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Environment definition, bootstrap and grading |
| `question.md` | The task |
| `solution.md` | Step-by-step walkthrough |
| `prerequisites.md` | Assumed knowledge and what the environment provides |
| `bootstrap/` | tkn CLI and Tekton Pipelines; then Gitea, the registry, the repository, ci-bot, the CI Tasks and the starting Pipeline |
| `manifests/` | `lab-start.yaml` (starfleet, Gitea, registry, tester), `ci-tasks.yaml`, `ci-rbac.yaml`, the starting `pipeline-bridge-ci.yaml`, and the files committed to Gitea under `gitea/` |
| `solution/` | Reference solution used by `astrona test`: the complete Pipeline and the two runs |
| `testing/` | Waits for Tekton, Gitea and the registry |
| `validation/` | Grading scripts, one per check; the last one runs its own PipelineRun on the branch `broken` |
