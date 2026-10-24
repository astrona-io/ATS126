# Writing style for this repo

All study text here (course pages, lab docs, READMEs, comments in YAML and
scripts) is for people learning a technical subject, often for a
certification exam. Many of them are not native English speakers and have no
university degree.

## Technical documentation in plain English

This is technical documentation. Say exactly what the system does, with the
real technical terms, in clear and simple English. Never hide a concept
behind a metaphor, a made-up name or a vague word: the reader must learn the
words they will meet in the product, the logs and the exam.

Strict guidelines:

1. Use the correct technical term every time (request, response, pod,
   namespace, Service, sidecar proxy, certificate, mTLS, JWT, listener). The
   first time a term appears in a file, define it in one plain sentence that
   says what it is and what it does. Spell out every acronym on first use.
2. No metaphors or analogies in explanations. Not "the communications
   officer", but "the sidecar proxy (Envoy)"; not "a signal", but "a
   request"; not "the planet", but "the namespace".
3. Simple sentences. Target a Flesch-Kincaid Grade Level of 8 or 9 for the
   prose around the terms. Keep sentences direct; split long sentences into
   two. No corporate buzzwords.
4. Use short paragraphs (max 3-4 sentences per paragraph).
5. Use the active voice ("istiod sends the configuration", not "the
   configuration is sent").

## How this applies to course material

- **Know which file you are in.** A module has a short landing page, a few
  deep-dive parts and a summary page. The landing page is a map: goals, what
  to know first, the order of the parts. The real teaching goes in the parts.
  The summary closes the module. A lab
  has a task, a step-by-step solution and a short intro. Keep each file to its
  job. Do not add "Prerequisite: ... Next: ..." navigation lines to pages;
  the landing page and the course outline already give the order.
- **Keep each part short.** One idea per part, about 5 to 8 minutes of
  reading and at most about 8 command blocks, so a learner can finish it with
  the playground in one sitting of about 15 minutes. Split at a natural seam
  where each half ends with something the learner has seen work. Never split
  only to hit a number. When you split, renumber the files, fix every "Part N"
  reference in the module and `astrona.yaml`.
- **Read like a book, not like a web page.** Each part reads as a chapter of
  a technical book. Open with a short paragraph on the problem it solves and
  why it matters. Link each paragraph to the next with a transition sentence.
  Close with a paragraph that sums up what the reader now knows and the
  question still open, before `## Common pitfalls` and the mission. Write
  explanations as prose; keep bullets for real lists (fields, ordered steps,
  options). Use `##` only when the topic changes and `###` only inside a long
  section, never for a single command. Weave hands-on steps into the text:
  one or two sentences on what to run and why, the command, the real output,
  then a sentence or two on what it shows.
- **The module ends with a summary.** The last page of every module is
  `course-0N-summary.md` with the title `# Summary`: a few short prose
  paragraphs on what the reader learned, organised by idea, optionally with
  one short list of key facts. It names no parts, modules, sections or
  chapters, and has no links, lab table, quiz or commands. Its last line is
  `<!-- astrona:playground:destroy -->` on its own line; the platform turns it
  into the step that removes the playground.
- **Every heading gets an intro.** A `##` section that has `###`
  subsections starts with one to three sentences that say what the section
  is about and why it matters, before the first `###`. Never put a `###`
  directly under a `##`.
- **Every module stands on its own.** Never refer to other sections or
  modules: no "see section 040", "as module 3 showed", "you met this in
  section 000", and no links to pages in another module. If the reader needs
  a fact from elsewhere, state the fact directly in one or two sentences.
  This also goes for parts of the same module: never write "Part 2 shows",
  "from Part 1" or "as in Part 3". Say the fact itself ("the commands below
  need the `scout` `DestinationRule` applied"). This includes the summary.
  The landing page does not have a "Where this fits" section.
- **Write words out in full.** Do not use informal short forms in prose:
  write "communications", "configuration", "repository", "administrator",
  "for example" and "that is", never "comms", "config", "repo", "admin",
  "e.g." or "i.e.". Names in code, commands and file paths stay as they are.
- **Exam terms stay.** The product's own names are what the reader must learn
  (for example a resource kind, a field, a command). Use them as they are and
  define each one in plain technical words the first time it appears in a
  file. Spell out acronyms on first use, with a short plain meaning.
- **The space theme is only for examples.** Space appears in two places and
  nowhere else: the names of the example workloads (the Starfleet: `bridge`,
  `scout`, `shuttle`, `probe`, the `starfleet` and `outpost` namespaces) and
  the short scenario that opens a lab task or a practice exercise (for
  example "the `drifter` in `outpost` must keep reaching the probe"). The
  explanation around an example is plain technical text: write "the
  `shuttle` pod sends a request to the `probe` Service", never "the shuttle
  sends a signal to the probe ship". Do not address the reader as an
  astronaut, and do not use space metaphors (communications officer, mission
  control, badge, airlock, guest list, star chart) for Istio or Kubernetes
  concepts. Titles of pages and labs name the technical task ("Require mTLS
  With PeerAuthentication"), not a space story.
- **Show one real example before the rule.** Start with a concrete case the
  reader can run, then give the general rule.
- **Say which part does the work.** Readers often mix up the parts of a system
  that sit close together. Whenever something happens, say which component
  did it.
- **Never change code to fit the style.** Commands, configuration files, field
  names, resource names, log lines and command output stay exactly as they
  are. They were run and checked on a real system. Never make up command
  output. If you shorten it, say that you did.
- **Prose only.** The grade-level and sentence rules apply to explanations.
  They do not apply to code blocks, tables of field names or reference lists
  (those may stay short and dense).
- **Keep the page furniture the same.** Hands-on steps are part of the prose
  (see "Read like a book"), not boxes or headings of their own. A `> [!TIP]` box is
  only for a real tip: advice the reader can reuse beyond this one step (a
  habit, a shortcut, how to spot a problem, an exam habit). Everything else
  is a normal sentence: notes about the current step ("if the log line is
  old, run it again"), background facts, optional extra steps, and plain
  information. Never a command snippet, never two in a row, and most pages
  need zero or one tip. Each part ends with a
  `## Common pitfalls` `> [!WARNING]` block for that part only. Use a Mermaid
  diagram for a flow, an order or a state change, keep it under about 12
  boxes, and follow it with one sentence that says what it shows.
- **Labs come right after the part they practise.** Do not collect all
  graded labs at the end of a module. In `astrona.yaml`, put each lab (its
  `question.md` reading and the `lab` entry) right after the reading part it
  tests. If a part teaches a gradeable skill and no lab covers it, create a
  new lab. That part then ends with a `## Your mission: <lab title>` section:
  one sentence on what the reader can now do, one on what the mission asks,
  then pause the playground (`astrona stop <playground name>`), the
  `astrona run` and `astrona submit` commands, and finally
  `astrona destroy <lab name>` plus `astrona start <playground name>`.
- **Renew the playground before hands-on work.** Every reading part that
  runs commands has `<!-- astrona:playground:renew -->` exactly once, on its
  own line, right before the first hands-on step (the first "Save this as"
  or the first command block), so the playground timer is reset before the
  learner needs the playground. Not on landing pages (they carry
  `<!-- astrona:playground -->`), summary pages (they carry
  `<!-- astrona:playground:destroy -->`) or pages without commands.
- **Mermaid without HTML.** The platform renders Mermaid with HTML labels
  switched off, so `<br/>` and any other HTML tag break the drawing. Rules:
  - One line per box, no `<br/>`, no HTML. Keep the box to the thing's name
    (`"scout-v2"`, `"istiod"`, `"Service: scout"`).
  - Put the logic on the arrows: `E -->|"version: v2"| P2`,
    `I -->|"CDS"| C`, `A -->|"end-user: jason"| B`. Keep edge labels short.
  - Quote every label. Prefer `flowchart TB`; use `LR` only for a short chain.
  - Sequence diagrams: short participant aliases (`participant S as shuttle`)
    and short message text.
  - Anything longer (cluster names, full hostnames) goes in the sentence under
    the diagram.
- **Every course starts with an Introduction.** It lives in `sections/intro/`
  and is the first entry in `astrona.yaml` (`id: module-intro`, title
  "Introduction"). It has exactly these four pages, in this order:
  - `README.md`, `# Introduction`: what the introduction covers and its three
    pages, named in prose (no links), ending with the topic the course starts
    with.
  - `course-01-welcome.md`, `# Welcome To The Course`: who the course is for,
    the exam domain and what the reader can do at the end, the words the
    course uses, the example app, how the course is laid out and how to read
    a page.
  - `course-02-get-your-machine-ready.md`, `# Get Your Machine Ready`: the
    tools to install, the `astrona` commands used every day, and what to do
    when a start goes wrong.
  - `course-03-how-this-course-is-made.md`, `# How This Course Is Made`: how
    content is written and checked, the maintainers, how to report a mistake,
    and the license.
  The Introduction teaches no product content and has no playground, labs or
  summary. Its only links are the repository's contributors page, issues
  page and license.
- **No links to other course files.** A course page (every reading listed in
  `astrona.yaml`, the playground guide `docs/overview.md`, and a lab's
  `question.md` and `solution.md`) never links to or points the reader at
  another page or file of the repository: no links to parts, summaries,
  labs, `question.md`, other modules, sections or the Introduction, and no
  "see `practice.md`" or "open `config.yaml`". The platform shows the pages in
  the order of `astrona.yaml`, so a link only adds a second, often wrong,
  path. Name a thing in plain words when the reader needs it ("the task is on
  the next page"), and state a fact on the page itself instead of sending the
  reader somewhere else. Repository files for authors (the root `README.md`,
  a lab's or playground's `README.md`) may link.
- **No links to outside sources.** Course pages, labs and playground docs do
  not link to or point at outside websites (the one exception is the
  `resources` field of a lab entry in `astrona.yaml`) (official docs, GitHub, blogs,
  RFCs), and they have no "Reference" or "Official docs" lists. Everything the
  reader needs is explained on the page itself. Not affected: addresses the
  reader actually uses in a command or browser (`http://127.0.0.1:9080`,
  `curl https://httpbin.org`), and the Introduction's contributors and
  "report a mistake" links.
- **Configuration goes to a file first.** Whenever the reader should apply
  YAML (course parts, playground docs, labs), use three separate steps:
  1. "Save this as `virtualservice-scout.yaml`:" followed by a plain
     ` ```yaml ` block with only the YAML. No `cat > file <<'EOF'`, no
     `kubectl apply -f - <<EOF`, no shell around it.
  2. "Apply it:" followed by a ` ```sh ` block with only
     `kubectl apply -f virtualservice-scout.yaml`.
  3. "Then check the result:" followed by the check commands, if any.
  The file name says the kind and the object. If a value must come from the
  reader's cluster (an IP address), use a placeholder like `<PARTNER>` in the
  YAML and say how to get the value (`echo $PARTNER`); never put shell
  variables inside YAML. Apply an object the first time its YAML appears; do
  not show it once "to read" and paste it again later. Never tell the reader
  to apply something from the playground's `examples/` folder: they start the
  playground with `astrona run`, so that folder is not on their machine.
- **Helpers have readable names.** Shell helper functions and variables use
  names that say what they do (`check_route`, `count_versions`,
  `$SERVICE_URL`), never single letters.


## About this repo (ATS126 only)

Everything above is general and can be copied to other course repositories. This
section is only true for this one.

### What the student is trying to learn

- **The goal:** master the **Pipelines, Task Graphs & Custom Tasks** domain of
  the **Tekton** training path (`ATP024`). It is 25% of the path. There is no
  official Tekton certification exam; the path's domains and weights are
  Astrona's own, set in `ATP024/path.yaml` (10/20/25/15/15/15 for ATS124 to
  ATS129).
- **Where Tekton sits:** Tekton is an **incubating project of the Cloud Native
  Computing Foundation (CNCF)**. The CNCF accepted it on 13 March 2026. Before
  that it was a founding and graduated project of the Continuous Delivery
  Foundation (CD Foundation). It is **not** a CNCF graduated project, and it is
  no longer a CD Foundation project. Both foundations belong to the Linux
  Foundation. Say this correctly wherever the course mentions it.
- **What the domain really tests:** building and repairing Pipelines, not
  remembering words. The student must *do* things (connect Tasks into a graph
  with `runAfter` and results, bind a workspace, guard a Task with a `when`
  expression, add a `finally` Task, set timeouts and retries, fan a Task out
  with a `matrix`, reference a Task through a resolver, and build a CI
  pipeline end to end). Every explanation should lead to a command they can
  run, and every fix should be proved with a PipelineRun whose `Succeeded`
  condition and child TaskRuns show the expected behaviour: the order of the
  TaskRuns, the skipped Tasks and their reasons, the `finally` Tasks that ran,
  and the results.
- **The three topics:** Pipelines and the task graph, control flow (`when`,
  `finally`, timeouts, retries, `onError`), and matrix fan-out with custom
  tasks, remote resolution and an end-to-end CI pipeline. The README table
  maps each section to its topic.
- **The sections:**

  | Section | Title | Topic |
  | --- | --- | --- |
  | 010 | Pipelines And The Task Graph | Pipelines |
  | 020 | Control Flow With When, Finally, Timeouts And Retries | Control flow |
  | 030 | Matrix Fan-Out, Custom Tasks And An End-To-End CI Pipeline | Matrix and CI pipeline |

- **The versions:** everything is written for **Tekton Pipelines v1.17.1** and
  the **tkn CLI v0.46.2** on a single-node `kind` cluster. Pipelines 1.17 needs
  Kubernetes 1.28 or later. v1.17 is a monthly release (end of life 31 October
  2026); the current long-term support (LTS) release is v1.15. The Dashboard
  (v0.73.0) is not installed in this course. Do not teach fields, flags or
  output from other versions without saying so.
- **The main sources:** the Tekton documentation, <https://tekton.dev/docs/>,
  and the `docs/` folder of `tektoncd/pipeline` at tag `v1.17.1`
  (`pipelines.md`, `pipelineruns.md`, `matrix.md`, `customruns.md`,
  `variables.md`, the resolver pages) and `tektoncd/cli` at `v0.46.2`. Where
  the docs are vague, the course follows the source at `v1.17.1`
  (`pkg/apis/pipeline/v1/pipelinerun_types.go`,
  `pkg/reconciler/pipelinerun/`). Check every page against them.

### Status: every environment passes `astrona test`

All nine environments (three playgrounds, three labs, three capstones) passed
`astrona test` on 2026-10-25 on a laptop `kind` cluster with Podman. Pages
still describe results in words: add a `text` output block only when it is
pasted exactly from a real run. Run `astrona test` again on every environment
you change.

### Terms, not metaphors

Explanations use Tekton's and Kubernetes' own words. Define each one in plain
technical language on first use in a file, for example:

| Term | First-use definition (example wording) |
| --- | --- |
| `Task` / `TaskRun` | A reusable list of steps / one execution of it; Tekton creates one pod per TaskRun |
| `Pipeline` | A graph of Tasks, with parameters, workspaces and results, stored in one namespace |
| `PipelineRun` | One execution of a `Pipeline`; the controller creates one TaskRun per pipeline task |
| Pipeline task | One entry under `spec.tasks` or `spec.finally` of a `Pipeline`; it names a Task and passes it parameters and workspaces |
| Directed acyclic graph (DAG) | A graph whose edges have a direction and no loops; Tekton runs the pipeline tasks in this order |
| `runAfter` | A list of pipeline tasks that must finish before this one starts (an ordering dependency) |
| Result reference | `$(tasks.<task>.results.<result>)`; it passes a value and also orders the two tasks (a resource dependency) |
| Workspace | A named volume that a Task declares and a PipelineRun binds, for example to a `volumeClaimTemplate` |
| `volumeClaimTemplate` | A PersistentVolumeClaim template in a PipelineRun; Tekton creates one claim per run and deletes it with the run |
| Pipeline result | A value the `Pipeline` declares under `spec.results`; Tekton writes it to the PipelineRun's `status.results` |
| `childReferences` | The list in a PipelineRun's status that names each TaskRun or CustomRun it created |
| `when` expression | A guard with `input`, `operator` (`in`, `notin`) and `values`, or a `cel` string; a false guard skips the task |
| Common Expression Language (CEL) | An expression language; Tekton accepts it in `when` only with the alpha flag `enable-cel-in-whenexpression` |
| `skippedTasks` | The list in a PipelineRun's status of tasks that did not run, each with a `reason` |
| `finally` task | A pipeline task that runs after every task under `tasks` has finished, whether they succeeded or not |
| Execution status | `$(tasks.<task>.status)` (`Succeeded`, `Failed`, `None`) and `$(tasks.status)` (`Succeeded`, `Failed`, `Completed`, `None`); only in `finally` |
| `timeouts` | `pipeline`, `tasks` and `finally` durations on a PipelineRun; `timeout` on one pipeline task |
| `retries` | How many more times Tekton runs a failed pipeline task; earlier attempts go to `status.retriesStatus` |
| `onError` | On a pipeline task: `stopAndFail` (default) or `continue`, which ignores its failure (`FailureIgnored`) |
| `matrix` | A field that fans one pipeline task out into one TaskRun per combination of parameter values |
| Custom task / `CustomRun` | A pipeline task with `taskRef.apiVersion` and `kind`; Tekton creates a `CustomRun` that another controller must carry out |
| Resolver | A component in `tekton-pipelines-resolvers` that fetches a Task or Pipeline from a cluster namespace, Git, a bundle, a hub or a URL |
| kaniko | A tool that builds a container image from a Dockerfile inside a container, without a Docker daemon |

A `Pipeline` and a `PipelineRun` are the most confused pair, followed by a
`Task` and a pipeline task. On first use in a file, always say which one you
mean, and say that the TaskRuns belong to the PipelineRun.

### The example workloads

| Name | Image | What it is |
| --- | --- | --- |
| Namespace `starfleet` | | Where every Task, Pipeline and run of the course lives |
| Namespace `ci-catalog` | | Holds shared Tasks for the cluster resolver (section 030) |
| Pipeline `launch-check` (Tasks `write-manifest`, `count-crew`, `report`) | `busybox:1.37.0` | Section 010 lab: a file in a workspace, a result reference, a pipeline result |
| Pipeline `release-notes` (Tasks `fetch-notes`, `lint-notes`, `spellcheck-notes`, `publish-notes`) | `busybox:1.37.0` | Section 010 capstone |
| Pipeline `ship` (Tasks `build-app`, `deploy-app`, `notify`) | `busybox:1.37.0` | Section 020 lab: `when` and `finally` |
| Pipeline `nightly` (Tasks `warm-cache`, `integration`, `docs-check`, `report`) | `busybox:1.37.0` | Section 020 capstone: retries, timeouts, `onError`, `finally` |
| Pipeline `bridge-ci` | see below | Section 030: the end-to-end CI pipeline |
| Gitea repository `starfleet/bridge` | `gitea/gitea:28.2.0-rootless` | The tiny shell application the CI pipeline builds; branches `main`, `feature/banner`, `broken` |
| Registry `registry.registry.svc.cluster.local:5000` | `registry:3.0.0` | In-cluster OCI registry over plain HTTP (lab only) |
| Deployment `tester` in `gitea` | `nicolaka/netshoot:v0.13` | Client pod for API calls from inside the cluster |
| ServiceAccount `ci-bot` | | Runs the CI TaskRuns; may write ConfigMaps in `starfleet` |

The CI Tasks of section 030 and their images: `git-clone` (`alpine/git:v2.49.1`),
`shellcheck` (`koalaman/shellcheck-alpine:v0.11.0`), `unit-test` (the image
comes from its `image` parameter: `busybox:1.37.0` or `alpine:3.22.7`),
`secret-scan` (`busybox:1.37.0`, a stand-in for a real scanner that greps for
assignments of passwords, tokens and secrets; say so honestly), `build-image`
(`ghcr.io/osscontainertools/kaniko:v1.28.5-debug`, the maintained fork of
kaniko; the original `GoogleContainerTools/kaniko` was archived in June
2025), `deploy` and `notify` (`alpine/kubectl:1.34.2`). "Deploy" records the
release in the ConfigMap `bridge-release`; "notify" writes the ConfigMap
`ci-notification-<pipelinerun>`. Say plainly that these stand in for a real
rollout and a real chat or email message.

Every step uses a `script`, never a bare image without `command`: without a
command, the controller asks the registry for the image's entrypoint, which
needs the network even when the image is preloaded on the node.

### Environment facts the text must respect

- **Install from the release manifest.** Pipelines:
  `kubectl apply -f https://infra.tekton.dev/tekton-releases/pipeline/previous/v1.17.1/release.yaml`.
  It creates the namespaces `tekton-pipelines` and `tekton-pipelines-resolvers`,
  the Deployments `tekton-pipelines-controller`, `tekton-pipelines-webhook`,
  `tekton-events-controller` and `tekton-pipelines-remote-resolvers`, and the
  ConfigMaps `config-defaults` and `feature-flags`.
- **Feature flags that matter here (v1.17.1 defaults):**
  `enable-api-fields: "beta"` (so `matrix` and array results work),
  `enable-cel-in-whenexpression: "false"` (CEL in `when` is alpha; only this
  flag is needed), `coschedule: "workspaces"` (the affinity assistant puts
  all TaskRuns that share a PVC workspace on one node). The resolvers
  ConfigMap `resolvers-feature-flags` in `tekton-pipelines-resolvers` enables
  the `bundles`, `hub`, `git`, `cluster` and `http` resolvers. The
  `cluster-resolver-config` ConfigMap allows every namespace by default.
- **PipelineRun status (checked in the v1.17.1 source):** the `Succeeded`
  condition has the reason `Succeeded` (all tasks ran), `Completed` (some
  were skipped), `Failed`, `PipelineRunTimeout`, `Cancelled`, or a validation
  reason before any TaskRun exists: `InvalidWorkspaceBindings`,
  `PipelineValidationFailed` (for example a Task parameter without a value),
  `InvalidTaskResultReference` (a result name that the Task does not
  declare), `InvalidPipelineResultReference`, `CouldntGetTask`,
  `CouldntGetPipeline`, `ParameterMissing`. In `tekton.dev/v1`, pipeline
  results are in `status.results` (in `v1beta1` they were
  `status.pipelineResults`).
- **Skipping reasons (exact strings):** `When Expressions evaluated to
  false`, `Parent Tasks were skipped`, `PipelineRun was stopping` (a task
  failed, so tasks that had not started are skipped), `Results were missing`,
  `PipelineRun timeout has been reached`, `PipelineRun Tasks timeout has been
  reached`, `PipelineRun Finally timeout has been reached`, `Matrix Parameters
  have an empty array`.
- **A task skipped by `when` does not stop its ordering dependents.** A task
  that only `runAfter` such a task still runs; a task that uses a result of
  such a task is skipped with `Results were missing`. A task whose parent
  was skipped for any other reason is skipped with `Parent Tasks were
  skipped`. A `finally` task that uses a missing result is skipped
  too, and the PipelineRun then ends `Completed` instead of `Succeeded`.
- **Execution status values:** `$(tasks.<t>.status)` is `Succeeded`,
  `Failed` or `None` (skipped or not run); `$(tasks.<t>.reason)` gives the
  TaskRun's reason. `$(tasks.status)` is `Succeeded`, `Failed`, `Completed`
  (some skipped) or `None`. Both are only allowed in `finally`. A task with
  `onError: continue` that fails still counts as `Failed` in both (its
  TaskRun is `False` with reason `FailureIgnored`), while the PipelineRun
  itself succeeds.
- **Retries:** the TaskRun keeps its name; each earlier attempt moves to
  `status.retriesStatus`, the reason is `ToBeRetried` in between, and the new
  pod is `<taskrun>-pod-retry1`. `$(context.task.retry-count)` in a step gives
  the attempt number (0 for the first) only for an embedded `taskSpec`; in a
  Task used through `taskRef` it is `0` in every attempt (seen live on
  v1.17.1). The `nightly` capstone's `warm-cache` therefore checks its pod
  name (`HOSTNAME` ends in `-retryN`). `retries` and `onError: continue`
  cannot be set on the same task.
- **Timeouts:** `timeouts.pipeline`, `timeouts.tasks`, `timeouts.finally` on
  the PipelineRun (`pipeline >= tasks + finally`), `timeout` on a pipeline
  task; a TaskRun that runs too long ends with the reason `TaskRunTimeout`.
  The API server stores a duration in Go form, for example `1m0s`.
- **TaskRun names and labels:** `<pipelinerun>-<pipelinetask>`, and
  `<pipelinerun>-<pipelinetask>-<index>` for a matrix. Labels
  `tekton.dev/pipelineRun`, `tekton.dev/pipelineTask`, `tekton.dev/pipeline`,
  `tekton.dev/memberOf` (`tasks` or `finally`). Graders select TaskRuns by
  these labels and compare `status.startTime` and `status.completionTime`.
- **Results of a matrix:** each string result of the fanned-out TaskRuns is
  collected into an array, consumed as `$(tasks.<t>.results.<r>[*])`;
  `$(tasks.<t>.matrix.length)` gives the number of TaskRuns. The default
  limit is 256 combinations (`default-max-matrix-combinations-count`).
- **Custom tasks:** a pipeline task with `taskRef.apiVersion` and `kind`
  makes the controller create a `CustomRun` (`tekton.dev/v1beta1`). No custom
  task controller is installed in this course (the `wait` example lives in
  `tektoncd/experimental`), so a `CustomRun` gets no status until the
  PipelineRun times out or is cancelled. Teach that, and do not claim a
  controller runs it.
- **Gitea and the registry are reached from inside the cluster.** Tasks use
  `http://gitea-http.gitea.svc.cluster.local:3000/starfleet/bridge.git` and
  `registry.registry.svc.cluster.local:5000`. Graders read Gitea and the
  registry through the API server's Service proxy
  (`kubectl get --raw /api/v1/namespaces/registry/services/registry:http/proxy/v2/...`).
  The reader may port-forward to browse. No script binds a fixed host port.
- **Many environments start broken on purpose.** A lab seeds a fault (a
  missing `runAfter`, a misspelled result, a wrong workspace name, a missing
  `when`, a `finally` task that consumes a result, a missing retry). The
  fault is the material. Never "fix" it in the bootstrap.
- **The proof is a PipelineRun.** A fix is proven with a PipelineRun whose
  condition, child TaskRuns, skipped tasks and results match. Graders also
  create their own PipelineRun (`generateName`, label `astrona.io/grader`),
  for example on the `broken` branch to prove that `finally` reports a
  failure, and delete it afterwards.

### Where things are in this repo

| What | Where |
| --- | --- |
| Course outline the platform reads: every reading page and lab, in order. Never list `solution.md` here | `astrona.yaml` |
| Overview, sections and modules tables, how to run things | `README.md` |
| Introduction (see "Every course starts with an Introduction") | `sections/intro/` |
| Section overview and its modules | `sections/section-0N0/README.md` |
| Module reading: landing page, deep-dive parts, closing page | `sections/section-0N0/module-0M/course.md`, `course-0N-*.md` |
| Graded lab: task, walkthrough, setup, grader | `.../labs/lab-01/` (`question.md`, `solution.md`, `prerequisites.md`, `bootstrap/`, `manifests/`, `solution/`, `testing/`, `validation/`) |
| Ungraded sandbox for a module | `.../playground/` (`config.yaml`, `bootstrap/prepare.sh`, `manifests/`, `docs/overview.md`, which is the only learner page) |
| One graded integration lab per section | `sections/section-0N0/capstone/labs/lab-01/` |

A lab folder holds:

| Path | Purpose |
| --- | --- |
| `config.yaml` | Lab definition; `metadata.docs` points at `question.md` and `solution.md` |
| `README.md` | Short intro for authors with `estimated_duration` front matter and the run, submit and destroy commands |
| `prerequisites.md` | What the learner needs before starting |
| `question.md` | The task. Starts with `# Question` and `Solve this question on: \`terminal\`` |
| `solution.md` | Step-by-step walkthrough |
| `bootstrap/01-install-tekton.sh`, `02-seed-state.sh` | The tkn CLI and Tekton Pipelines, then the starting state (in section 030 also Gitea, the registry and the CI Tasks) |
| `manifests/` | `lab-start.yaml` (namespace `starfleet`, and in section 030 Gitea, the registry and the `tester` pod) and the seeded Tasks, Pipelines and runs |
| `solution/apply.sh` | Reference end state, applied only by `astrona test` |
| `testing/wait-for-tekton.sh` | Waits until the Tekton Deployments answer before the reference solution runs |
| `validation/validate-*.sh` | Behavioural grading, one script per check |

### Lab metadata in `astrona.yaml`

`astrona.yaml` has a `training:` block (id `ATS126`, domain
`Pipelines, Task Graphs & Custom Tasks`, weight `25`) and one entry per
section under `modules:` (`module-010`, `module-020`, `module-030`). Each
section's `content` lists, in order: the section `README.md`, then for each
module its landing page, its parts, and right after the part a lab tests, a
`Question` reading (`labs/lab-01/question.md`) followed by the `type: lab`
entry; the module's closing page comes last. The section capstone closes the
section. Playgrounds are not listed. In section 020 the module lab tests the
first two parts, so it sits after the second part; the third part
(timeouts, retries, `onError`) is graded by the capstone.

Every `type: lab` entry carries the same fields, in the same order, as in
ATS016: `title`, `path`, `difficulty`, `estimated_duration`, `topic`,
`task_kind`, `tags`, `learning_goals`, `resources`.

- `difficulty`: `beginner`, `intermediate` or `advanced`.
- `estimated_duration`: realistic time to solve it, for example `15m`, `30m`.
- `topic`: exactly one of `pipelines`, `control-flow`, `matrix`,
  `ci-pipeline`.
- `task_kind`: exactly one of `build`, `troubleshooting` or `migration`.
- `tags`: 4 to 8 ids, only from the tag list below. Add a new tag to the list
  first if nothing fits.
- `learning_goals`: 2 or 3 plain sentences, each starting with a verb.
- `resources`: 1 to 4 pages on `tekton.dev`, each with a `name` and a `url`
  that loads. This is the **only** place outside links are allowed.

**Tag list** (lower case, hyphens, never synonyms):

- Pipelines: `pipeline`, `pipelinerun`, `pipeline-params`, `workspaces`,
  `volume-claim-template`, `run-after`, `dag`, `task-results`,
  `pipeline-results`, `child-references`
- Control flow: `when-expressions`, `skipped-tasks`, `finally`,
  `execution-status`, `timeouts`, `retries`, `on-error`
- Fan-out and CI: `matrix`, `custom-tasks`, `cluster-resolver`,
  `git-resolver`, `git-clone`, `lint`, `unit-tests`, `security-scan`,
  `image-build`, `conditional-deploy`, `notifications`, `rbac`

### Running things

```bash
# Playground (ungraded)
astrona run --git ssh://git@github.com/astrona-io/ATS126.git -c sections/section-010/module-01/playground
astrona destroy ats-126-playground-010-01   # takes metadata.name from config.yaml, not the path

# Lab or capstone (graded against the live cluster)
astrona run --git ssh://git@github.com/astrona-io/ATS126.git -c sections/section-010/module-01/labs/lab-01
astrona submit -c sections/section-010/module-01/labs/lab-01
astrona destroy ats-126-lab-010-01

# Authors: run a local, uncommitted copy, and prove a lab passes with its reference solution
astrona run -c sections/section-010/module-01/playground
astrona test -c sections/section-010/module-01/labs/lab-01
```

Names: a playground is `ats-126-playground-<section>-<module>`, a module lab
is `ats-126-lab-<section>-<module>` and a capstone is
`ats-126-capstone-<section>`; keep those names. Lab bootstrap scripts do not
pin a kube context: astrona sets `KUBECONFIG` for the lab. Every lab must pass
`astrona validate` and `astrona test`.

Graders check **behaviour**, not just that an object exists: a PipelineRun
with the right `Succeeded` reason, child TaskRuns that started only after
the tasks they depend on had finished (or overlapped, where tasks must run in
parallel), skipped tasks with the expected reason, `finally` tasks that ran
on failure, pipeline results, and an image tag in the registry. Graders also
reject the plausible but wrong fix (an inline `pipelineSpec` instead of the
Pipeline, a hard-coded result, two parallel tasks chained one after the
other, a Task copied into `starfleet` instead of the resolver fix, `retries`
on a task that must use `onError`). A lab's `question.md` and `solution.md`
must match what its `validation/` scripts actually check.

Test clusters on the maintainer's machine: one at a time. Each environment
runs four Tekton Deployments; section 030 environments also run Gitea, the
registry and the `tester` pod. No script uses a fixed host port.

### Where to find trusted sources

Check facts here before writing them down. Prefer these over memory.

- **Pipelines:** [Pipelines](https://tekton.dev/docs/pipelines/pipelines/),
  [PipelineRuns](https://tekton.dev/docs/pipelines/pipelineruns/),
  [Matrix](https://tekton.dev/docs/pipelines/matrix/),
  [variables](https://tekton.dev/docs/pipelines/variables/),
  [workspaces](https://tekton.dev/docs/pipelines/workspaces/)
- **Custom tasks and resolution:** [CustomRuns](https://tekton.dev/docs/pipelines/customruns/),
  [cluster resolver](https://tekton.dev/docs/pipelines/cluster-resolver/),
  [Git resolver](https://tekton.dev/docs/pipelines/git-resolver/),
  [bundles resolver](https://tekton.dev/docs/pipelines/bundle-resolver/),
  [hub resolver](https://tekton.dev/docs/pipelines/hub-resolver/)
- **Configuration:** [additional configuration](https://tekton.dev/docs/pipelines/additional-configs/)
  (feature flags and their maturity)
- **CLI:** [tkn](https://tekton.dev/docs/cli/) and `docs/cmd/` in `tektoncd/cli` at `v0.46.2`
- **kaniko:** the README of `osscontainertools/kaniko` at `v1.28.5`
- **The landscape:** Tekton's page on the CNCF site,
  <https://www.cncf.io/projects/tekton/> (incubating, accepted 13 March 2026).

### Skills to use here

The `astrona-course-*` skills do most authoring jobs in this repository:
planning (`domain-plan`), creating the tree (`domain-scaffold`), building
modules (`domain-build`), deep-dive parts (`deep-dive`), labs and playgrounds
(`lab`), lab docs (`lab-docs`), challenges (`create-challenge`), quizzes
(`generate-assessment`) and fact-checking (`review-accuracy`).
