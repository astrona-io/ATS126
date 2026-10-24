# Welcome To The Course

This course trains you for the **Pipelines, Task Graphs & Custom Tasks** part of the Astrona **Tekton** training path. That part is 25% of the path. This page tells you who the course is for, what you can do at the end, which words and example setup it uses, and how its pages fit together.

## Who this course is for

You know your way around Kubernetes: namespaces, pods, ConfigMaps, ServiceAccounts, PersistentVolumeClaims, `kubectl apply`, `kubectl get` and `kubectl logs`. You also know the basics of Tekton: a `Task` is a list of steps, a `TaskRun` is one execution of a `Task`, and Tekton runs each `TaskRun` as one pod with one container per step. You do not need to have written a `Pipeline` before. Each new idea is explained the first time it appears.

## What you can do at the end

A single Task rarely does a whole job. A continuous integration and delivery (CI/CD) process, which builds, tests and releases software on every change, has many steps that depend on each other. This course teaches you to connect Tasks into a `Pipeline`, control how it runs, and build a real CI pipeline. It has three topics, and each one turns into a set of skills you will practise.

The first topic is **Pipelines and the task graph**. You will learn to:

- Write a `Pipeline` and start it with a `PipelineRun`, with parameters and a shared workspace.
- Pass results from one task to the next, and publish results of the whole Pipeline.
- Order tasks into a graph with `runAfter` and result references, and read the status of a `PipelineRun` and its TaskRuns.

A Pipeline also has to decide what runs and what happens when something fails, so the second topic is **control flow**. You will learn to:

- Skip a task with a `when` expression, and read why a task was skipped.
- Run `finally` tasks on success and on failure, and read the execution status of tasks.
- Set timeouts, retry a failing task, and ignore a failure with `onError`.

The third topic is **fan-out, custom tasks and a complete CI pipeline**. You will learn to:

- Fan one task out into many TaskRuns with a `matrix`.
- Explain custom tasks and fetch Tasks from another namespace or a Git repository with resolvers.
- Build a CI pipeline that clones, lints, tests, scans, builds and pushes an image, deploys only from `main`, and reports its result.

Everything is written for **Tekton Pipelines v1.17.1** and **tkn v0.46.2**.

## The words this course uses

The pages use Tekton's and Kubernetes' own terms, because those are the words you meet in the product, the logs and the documentation. Each term gets a short, plain definition the first time it appears on a page. A few terms come back on almost every page, so here they are up front.

| Object | What it is |
| --- | --- |
| `Task` | A reusable list of steps, with parameters, workspaces and results |
| `TaskRun` | One execution of a `Task`. Tekton creates one pod for it |
| `Pipeline` | A graph of tasks with parameters, workspaces and results. It does nothing on its own |
| `PipelineRun` | One execution of a `Pipeline`. Tekton creates one `TaskRun` for each task in the graph |

A **pipeline task** is one entry in the task list of a `Pipeline`: it names a `Task` and gives it values. A **workspace** is a volume that tasks share, a **result** is a short named output value, and a **directed acyclic graph (DAG)** is the order of tasks that Tekton works out from the Pipeline: arrows that point one way and never loop. The **tekton-pipelines-controller** is the program in the cluster that turns each `PipelineRun` into TaskRuns, and **`tkn`** is the command-line tool you use to start and inspect runs.

## The example setup in your playground

Every playground and lab runs on a small `kind` cluster with Tekton Pipelines installed. Your Tasks, Pipelines and runs live in the namespace `starfleet`. The example Pipelines have short names such as `launch-check`, `ship` or `nightly`, and their parameters take crew names such as `bridge`, `scout`, `shuttle` and `probe`. Most steps use the small `busybox` image, so every run is quick.

The last section adds a small Git server (Gitea) and a container registry inside the cluster. Gitea holds a tiny shell application called `bridge`, and the CI pipeline you build clones it, checks it, packs it into a container image and pushes the image to the registry. Nothing leaves your machine except the image downloads.

Many labs start with something broken on purpose: a PipelineRun that fails, a task that runs too early, a report that never arrives. That is the material, not a fault in the course.

## How the course is laid out

The course has three sections. It starts with the structure of a Pipeline, then controls how it runs, and ends with a complete CI pipeline.

| Section | What it covers |
| --- | --- |
| 010 | Pipelines And The Task Graph |
| 020 | Control Flow With When, Finally, Timeouts And Retries |
| 030 | Matrix Fan-Out, Custom Tasks And An End-To-End CI Pipeline |

Each section has one or more **modules**, and each module teaches one skill. A module brings together four kinds of material:

| What | What it is for | Graded? |
| --- | --- | --- |
| **Reading** | A short landing page, a few chapters that teach one idea each, and a summary | No |
| **Playground** | A small cluster on your own machine, to try everything you read | No |
| **Lab** | A cluster in a starting state, a task, and a grader that checks your work | Yes |
| **Capstone** | The last lab in a section, with several faults at once | Yes |

The best order is simple: read the chapters with the playground open next to them, take each lab when a chapter sends you to it, and finish each section with its capstone. The next part of this page explains how a module's pages guide you through that order.

## How to read a page

A module starts with a **landing page**. It says what the module teaches, what you should know first, and the order of its chapters. At the bottom of the landing page you start the module's playground, and you keep it running while you read.

The chapters (the parts of a module) read like the chapters of a technical book. Each one opens with the problem it solves, explains one idea in connected paragraphs, and closes with what you now know. The hands-on steps sit right in the text: a sentence or two on what to run and why, the command, and then what the result shows. Run each step in your playground as you reach it. You learn more from one real result than from a page of text.

Every chapter ends with a box of common pitfalls, the mistakes people make most often with what the chapter taught, and how to spot them. Now and then a page also has a tip box with a habit or shortcut you can use again, well beyond that page. The two boxes look like this:

> [!TIP]
> **A tip.** A habit or shortcut you can use again, well beyond this one page.

> [!WARNING]
> **Common pitfalls.** The mistakes people make most often with what you just learned, and how to spot them. Every chapter ends with one.

When a graded lab tests what a chapter taught, that chapter ends with a **Your mission** section. It tells you what the lab asks, then gives every command you need, in order: pause the playground with `astrona stop`, start the lab with `astrona run`, and send your work for grading with `astrona submit`. Solve the lab on your own before you look at its solution. When the lab is done, remove it with `astrona destroy` and start the playground again with `astrona start`, so you can carry on reading where you left off.

The last page of every module is the **Summary**. It sums up what you learned in a few short paragraphs, organised by idea. It also ends the module's hands-on work: the Summary page removes the playground, so your machine is clean before the next module.

One rule holds on every page. Code blocks are exactly what you type. Never change a command to make it "look right". If the result is different from what the page describes, that difference is the lesson.
