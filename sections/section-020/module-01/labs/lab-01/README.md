---
estimated_duration: 25m
---

# Guard A Deploy And Report With finally

- **ID:** LAB
- **Slug:** ats-126-lab-020-01
- **Author:** Paris Nakita Kejser
- **Type:** Astrona graded lab

Graded lab for the namespace `starfleet`. Read `question.md` for the task; `solution.md` is the walkthrough.

Not yet run: this lab was written from the Tekton v1.17.1 documentation and
has not passed `astrona validate` or `astrona test` yet.

## Run it

```sh
astrona run -c .
astrona submit
astrona destroy ats-126-lab-020-01
```

`astrona destroy` takes the environment name (`metadata.name` = `ats-126-lab-020-01`), not
the config path.

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Environment definition, bootstrap and grading |
| `question.md` | The task |
| `solution.md` | Step-by-step walkthrough |
| `prerequisites.md` | Assumed knowledge and what the environment provides |
| `bootstrap/` | tkn CLI and Tekton Pipelines, then the Tasks, the Pipeline and one run |
| `manifests/` | The namespace `starfleet`, the Tasks `build-app`, `deploy-app`, `notify`, the Pipeline `ship` and the run `ship-feature-0` |
| `solution/` | Reference solution used by `astrona test`, with the finished Pipeline and the two runs |
| `testing/` | Waits for the Tekton Deployments |
| `validation/` | Grading scripts, one per check; the last one runs its own PipelineRun |
