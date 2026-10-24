---
estimated_duration: 25m
---

# Fix The Task Graph Of A Pipeline

- **ID:** LAB
- **Slug:** ats-126-lab-010-01
- **Author:** Paris Nakita Kejser
- **Type:** Astrona graded lab

Graded lab for the namespace `starfleet`. Read `question.md` for the task; `solution.md` is the walkthrough.

Not yet run: this lab was written from the Tekton v1.17.1 documentation and
has not passed `astrona validate` or `astrona test` yet.

## Run it

```sh
astrona run -c .
astrona submit
astrona destroy ats-126-lab-010-01
```

`astrona destroy` takes the environment name (`metadata.name` = `ats-126-lab-010-01`), not
the config path.

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Environment definition, bootstrap and grading |
| `question.md` | The task |
| `solution.md` | Step-by-step walkthrough |
| `prerequisites.md` | Assumed knowledge and what the environment provides |
| `bootstrap/` | tkn CLI and Tekton Pipelines, then the broken Pipeline and its failed run |
| `manifests/` | The namespace `starfleet`, the Tasks `write-manifest`, `count-crew`, `report`, the Pipeline `launch-check` (two faults) and the PipelineRun `launch-check-run` |
| `solution/` | Reference solution used by `astrona test`, with the fixed Pipeline and the PipelineRun |
| `testing/` | Waits for the Tekton Deployments |
| `validation/` | Grading scripts, one per check; the last one runs its own PipelineRun |
