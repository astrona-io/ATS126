# ATS126 — Pipelines, Task Graphs & Custom Tasks (Tekton)

Course material for the **Pipelines, Task Graphs & Custom Tasks** domain of
the Astrona Tekton training path ([ATP024](https://github.com/astrona-io/ATP024)),
which is **25% of the path**. Written for **Tekton Pipelines v1.17.1** and the
**tkn CLI v0.46.2**.

> **Status: draft, not yet run.** Every page, playground and lab was written
> from the Tekton documentation, the v1.17.1 release manifest and the source
> at the pinned tag. None has been started on a cluster, and no lab has
> passed `astrona test` yet. See `CLAUDE.md`.

Tekton is an incubating project of the Cloud Native Computing Foundation
(CNCF) since March 2026; before that it was a graduated project of the
Continuous Delivery Foundation. There is no official Tekton certification
exam; the path's domains and weights are Astrona's own.

The course opens with an Introduction in `sections/intro/` (welcome, machine setup,
how the course is made). Everything else lives under `sections/`. Each section
contains:

- **Modules** — a reading chapter split into a short landing page, ordered
  deep-dive parts and a summary page, a throwaway **playground** to explore in,
  and a graded **lab** placed right after the part it tests.
- **A capstone** — one larger graded lab combining that section's modules into a
  single scenario with several independent faults.

---

## Sections

| Section | Title | Modules | Labs | Topic |
| --- | --- | --- | --- | --- |
| [010](sections/section-010) | Pipelines And The Task Graph | 1 | 1 + capstone | Pipelines |
| [020](sections/section-020) | Control Flow With When, Finally, Timeouts And Retries | 1 | 1 + capstone | Control flow |
| [030](sections/section-030) | Matrix Fan-Out, Custom Tasks And An End-To-End CI Pipeline | 1 | 1 + capstone | Matrix and CI pipeline |

The order goes from structure to control to a real pipeline. Section 010
builds a `Pipeline` from Tasks, passes workspaces and results, and reads the
graph and status of a `PipelineRun`. Section 020 decides what runs and what
happens on failure: `when` expressions, `finally` tasks, timeouts, retries and
`onError`. Section 030 fans tasks out with a `matrix`, explains custom tasks
and resolvers, and ends with a complete CI pipeline against an in-cluster Git
server and registry.

---

## Modules

| Module | Reader | Parts | Labs |
| --- | --- | --- | --- |
| 010-01 | [Build A Task Graph With Pipelines](sections/section-010/module-01/course.md) | 3 | [lab-01](sections/section-010/module-01/labs/lab-01) |
| 020-01 | [Control How A Pipeline Runs](sections/section-020/module-01/course.md) | 3 | [lab-01](sections/section-020/module-01/labs/lab-01) |
| 030-01 | [Fan Out And Build A CI Pipeline](sections/section-030/module-01/course.md) | 3 | [lab-01](sections/section-030/module-01/labs/lab-01) |

| Lab | Title | Kind | Faults or work |
| --- | --- | --- | --- |
| 010-01 | Fix The Task Graph Of A Pipeline | troubleshooting | a misspelled result reference, a missing `runAfter` between two tasks that share a file |
| 020-01 | Guard A Deploy And Report With finally | build | add a `when` expression on the branch, add a `finally` task with execution status, run on two branches |
| 030-01 | Build An End-To-End CI Pipeline | build | complete `bridge-ci`: matrix tests, scan, kaniko build, deploy only on `main`, `finally` notification |

---

## Capstones

| Capstone | Scenario | Faults |
| --- | --- | --- |
| [010](sections/section-010/capstone/labs/lab-01) | Repair A Release Notes Pipeline | a wrong workspace name in the PipelineRun, a Task parameter the Pipeline never passes, two parallel tasks chained |
| [020](sections/section-020/capstone/labs/lab-01) | Make A Nightly Pipeline Reliable | a flaky task without retries, a timeout that is too short, a known failure without `onError`, a `finally` task that consumes a result |
| [030](sections/section-030/capstone/labs/lab-01) | Repair A Broken CI Pipeline | a wrong namespace in a cluster resolver reference, a misnamed matrix parameter, `notin` instead of `in`, a `finally` task that consumes a build result |

---

## The lab environment

Every playground and lab is a single-node **kind** cluster with the `tkn` CLI
0.46.2 installed on the machine, Tekton Pipelines v1.17.1 installed from its
release manifest, and a namespace `starfleet`. Section 010 and 020 steps use
`busybox:1.37.0`. Section 030 environments add **Gitea**
(`gitea/gitea:28.2.0-rootless`) with the repository `starfleet/bridge`, a
plain HTTP **registry** (`registry:3.0.0`), a `tester` pod
(`nicolaka/netshoot:v0.13`) and the CI Tasks, whose images are `alpine/git:v2.49.1`,
`koalaman/shellcheck-alpine:v0.11.0`, `busybox:1.37.0`, `alpine:3.22.7`,
`ghcr.io/osscontainertools/kaniko:v1.28.5-debug` and `alpine/kubectl:1.34.2`.
All of these are preloaded on the node. Tekton's own images come from
`ghcr.io` (and the `place-scripts` shell image from `cgr.dev`) by digest, and
the kaniko build pulls its base image `mirror.gcr.io/library/busybox:1.37.0`,
so every start needs outbound internet.

Graders read Tekton objects with `kubectl`, read Gitea and the registry
through the API server's Service proxy, and often create a PipelineRun of
their own (`generateName`, label `astrona.io/grader: "true"`) to test
behaviour. No script uses a fixed host port.

## Running a playground

```bash
astrona run --git ssh://git@github.com/astrona-io/ATS126.git -c sections/<section>/<module>/playground
astrona destroy <name>
```

## Running a lab

Labs and capstones are graded. Read `question.md`, do the work, and submit:

```bash
astrona run --git ssh://git@github.com/astrona-io/ATS126.git -c sections/<section>/<module>/labs/lab-01
astrona submit -c sections/<section>/<module>/labs/lab-01
astrona destroy <name>
```

Each lab grades the **final cluster state** with independent checks, and
several of them deliberately reject the plausible-but-wrong fix (an inline
`pipelineSpec`, a hard-coded result, chaining tasks that must run in
parallel, retrying a task that must use `onError`, copying a Task into
`starfleet` instead of fixing the resolver reference).
