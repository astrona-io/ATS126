# Fan Out And Build A CI Pipeline — Playground

- **ID:** PLAYGROUND
- **Slug:** ats-126-playground-030-01
- **Author:** Paris Nakita Kejser
- **Type:** Astrona playground — clean environment, no task, no grading

A single sandbox environment with Tekton Pipelines v1.17.1, the tkn CLI 0.46.2, Gitea with the repositories `starfleet/bridge` and `starfleet/tekton-catalog`, a plain HTTP registry, a `tester` pod, the ServiceAccount `ci-bot` and the CI Tasks in `starfleet`. Nothing to submit.

Not yet run: this playground was written from the Tekton documentation and
the v1.17.1 release manifest and has not been started on a cluster yet.

## Run it

```sh
astrona run -c .
astrona destroy ats-126-playground-030-01
```

`astrona destroy` takes the environment name (`metadata.name` = `ats-126-playground-030-01`), not
the config path. `astrona submit` and `astrona test` do not apply — there is no
grading.

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Environment definition (runtime + bootstrap only) |
| `bootstrap/prepare.sh` | tkn and Tekton Pipelines |
| `bootstrap/seed.sh` | Gitea, the registry, the repositories, ci-bot and the CI Tasks |
| `manifests/lab-start.yaml` | The namespace `starfleet`, Gitea, the registry and the `tester` pod |
| `manifests/ci-tasks.yaml`, `manifests/ci-rbac.yaml` | The CI Tasks; the ServiceAccount `ci-bot` with its Role |
| `manifests/gitea/` | The files committed to Gitea (the `bridge` app and its branches, the Git catalog) |
| `docs/overview.md` | What the environment contains and ideas to try |
