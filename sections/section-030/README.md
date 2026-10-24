# Section 030: Matrix Fan-Out, Custom Tasks And An End-To-End CI Pipeline

Most continuous integration (CI) pipelines do the same few jobs: fetch the code, check it, test it, scan it, build an image, deploy it from the main branch, and tell the team what happened. Some of those jobs repeat with small changes, such as the same tests on several platforms. Some Tasks live outside your namespace, in a shared catalog or a Git repository. And some work is not a pod at all. This section brings all of that together in one Pipeline that builds a real container image inside your cluster.

You first fan one pipeline task out into many TaskRuns with a `matrix`, and collect their results. Then you look at custom tasks, which hand work to a controller outside Tekton Pipelines, and at resolvers, which fetch Tasks from another namespace or a Git repository. Last, you design and run an end-to-end CI pipeline against an in-cluster Git server (Gitea) and registry: clone, lint, unit tests on two images, a secret scan, a kaniko build and push, a deploy only from `main`, and a notification from a `finally` task.

**Topic covered:** Matrix fan-out and the CI pipeline

## What you will learn

- `matrix.params` and `matrix.include`, the names and number of the TaskRuns a matrix creates, and results from a matrixed task as an array.
- Custom tasks: a pipeline task with `taskRef.apiVersion` and `kind`, the `CustomRun` that Tekton creates, and why it needs its own controller.
- Remote resolution: the `cluster`, `git`, `bundles`, `hub` and `http` resolvers, and how a `taskRef` with `resolver` and `params` fetches a Task.
- How to design a CI Pipeline as a graph: which tasks run in parallel, which wait, which are guarded, and which run in `finally`.
- Building and pushing an image with kaniko without a Docker daemon, and recording a deploy and a notification from the Pipeline.

## The learning path

The section has one module. It has a landing page, three short parts, a graded lab right after the part it tests, and a summary. The module also has its own playground, a cluster where you can explore freely, and the landing page starts it for you.

### 1. Fan Out And Build A CI Pipeline

The module starts at its landing page, which also launches the playground. The playground runs Tekton Pipelines v1.17.1, the `tkn` command-line tool, Gitea with the repository `starfleet/bridge`, a registry, and the CI Tasks in the namespace `starfleet`.

1. Fan Out A Task With A Matrix
2. Custom Tasks And Remote Resolution
3. Design An End-To-End CI Pipeline, followed by the lab **Build An End-To-End CI Pipeline**
4. Summary

## Section capstone: Repair A Broken CI Pipeline

The capstone is one graded scenario that combines the whole module. The CI pipeline of the `bridge` application never builds: it fetches its build Task from the wrong namespace, its matrix passes a parameter the test Task does not know, its deploy runs on the wrong branches, and its notification never arrives when the build fails. Find each fault from the PipelineRun status, fix it, and prove the fix with runs on `main`, on a feature branch and on a broken branch. Work it after the module lab.

Start the capstone:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS126.git -c sections/section-030/capstone/labs/lab-01
```

When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-030/capstone/labs/lab-01
```

When the capstone is done, remove it:

```sh
astrona destroy ats-126-capstone-030
```
