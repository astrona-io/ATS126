---
estimated_duration: 25m
---

# Share A Task And A Pipeline With The Cluster Resolver

- **ID:** LAB
- **Slug:** ats-126-lab-030-02
- **Author:** Paris Nakita Kejser
- **Type:** Astrona graded lab

Graded lab for the namespace `starfleet`. Read `question.md` for the task; `solution.md` is the walkthrough.

Not yet run: this lab was written from the Tekton v1.17.1 documentation and
has not passed `astrona test` yet.

## Run it

```sh
astrona run -c .
astrona submit
astrona destroy ats-126-lab-030-02
```

`astrona destroy` takes the environment name (`metadata.name` = `ats-126-lab-030-02`), not
the config path.

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Environment definition, bootstrap and grading |
| `question.md` | The task |
| `solution.md` | Step-by-step walkthrough |
| `prerequisites.md` | Assumed knowledge and what the environment provides |
| `bootstrap/` | tkn CLI and Tekton Pipelines, then the shared catalog and the broken Pipeline |
| `manifests/` | The namespaces `starfleet` and `ci-catalog`, the shared Task `announce` and Pipeline `release-flow`, and the Pipeline `flow` (one fault) |
| `solution/` | Reference solution used by `astrona test`, with the fixed Pipeline and the two PipelineRuns |
| `testing/` | Waits for the Tekton Deployments |
| `validation/` | Grading scripts, one per check; the last one runs its own PipelineRun |
