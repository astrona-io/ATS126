---
estimated_duration: 25m
---

# Run A Pipeline With A Service Account, Limits And Timeouts

- **ID:** LAB
- **Slug:** ats-126-lab-020-02
- **Author:** Paris Nakita Kejser
- **Type:** Astrona graded lab

Graded lab for the namespace `starfleet`. Read `question.md` for the task; `solution.md` is the walkthrough.

Not yet run: this lab was written from the Tekton v1.17.1 documentation and
has not passed `astrona test` yet.

## Run it

```sh
astrona run -c .
astrona submit
astrona destroy ats-126-lab-020-02
```

`astrona destroy` takes the environment name (`metadata.name` = `ats-126-lab-020-02`), not
the config path.

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Environment definition, bootstrap and grading |
| `question.md` | The task |
| `solution.md` | Step-by-step walkthrough |
| `prerequisites.md` | Assumed knowledge and what the environment provides |
| `bootstrap/` | tkn CLI and Tekton Pipelines, then the ServiceAccount and the Pipeline |
| `manifests/` | The namespace `starfleet`, the ServiceAccount `builder` and the Pipeline `render` |
| `solution/` | Reference solution used by `astrona test` |
| `testing/` | Waits for the Tekton Deployments |
| `validation/` | Grading scripts, one per check |
