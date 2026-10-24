---
estimated_duration: 35m
---

# Make A Nightly Pipeline Reliable

- **ID:** CAPSTONE
- **Slug:** ats-126-capstone-020
- **Author:** Paris Nakita Kejser
- **Type:** Astrona graded capstone

Graded capstone for section 020, in the namespace `starfleet`. Read `question.md` for the task; `solution.md` is the walkthrough.

> **Not yet run.** This capstone was written from the Tekton v1.17.1
> documentation and has not passed `astrona test` yet.

## Run it

```sh
astrona run -c .
astrona submit
astrona destroy ats-126-capstone-020
```

`astrona destroy` takes the environment name (`metadata.name` = `ats-126-capstone-020`), not
the config path.

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Environment definition, bootstrap and grading |
| `question.md` | The task |
| `solution.md` | Step-by-step walkthrough |
| `prerequisites.md` | Assumed knowledge and what the environment provides |
| `bootstrap/` | tkn CLI and Tekton Pipelines, then the broken starting state |
| `manifests/` | The namespace `starfleet`, the four Tasks, the Pipeline `nightly` (four faults) and the PipelineRun `nightly-run` |
| `solution/` | Reference solution used by `astrona test`, with the fixed Pipeline and the PipelineRun |
| `testing/` | Waits for the Tekton Deployments |
| `validation/` | Grading scripts, one per check; the last one runs its own PipelineRun |
