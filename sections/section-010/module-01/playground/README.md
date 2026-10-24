# Build A Task Graph With Pipelines — Playground

- **ID:** PLAYGROUND
- **Slug:** ats-126-playground-010-01
- **Author:** Paris Nakita Kejser
- **Type:** Astrona playground — clean environment, no task, no grading

A single sandbox environment with Tekton Pipelines v1.17.1, the tkn CLI 0.46.2 and an empty namespace `starfleet`. Nothing to submit.

Not yet run: this playground was written from the Tekton documentation and
the v1.17.1 release manifest and has not been started on a cluster yet.

## Run it

```sh
astrona run -c .
astrona destroy ats-126-playground-010-01
```

`astrona destroy` takes the environment name (`metadata.name` = `ats-126-playground-010-01`), not
the config path. `astrona submit` and `astrona test` do not apply — there is no
grading.

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Environment definition (runtime + bootstrap only) |
| `bootstrap/prepare.sh` | Environment preparation run once at startup |
| `manifests/lab-start.yaml` | The namespace `starfleet` |
| `docs/overview.md` | What the environment contains and ideas to try |
