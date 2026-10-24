# Summary

A continuous integration (CI) pipeline in Tekton is a graph of small Tasks, each doing one job, and the `Pipeline` decides how they fit together. A matrix repeats a task over a list of values, resolvers bring in Tasks from outside the namespace, and custom tasks hand work to other controllers. With those tools, one `Pipeline` can take a commit from a Git server to a pushed image and a recorded release, and report every outcome.

## What you learned

A `matrix` on a pipeline task lists values for some of its parameters. The controller creates one TaskRun per combination of `matrix.params`, named `<pipelinerun>-<pipeline task>-<index>`, and runs them in parallel. `matrix.include` adds values to matching combinations or adds new combinations of its own, and its `name` becomes the display name of that TaskRun. String results of a matrixed task are collected into an array, consumed as `$(tasks.<task>.results.<result>[*])`, and `$(tasks.<task>.matrix.length)` gives the number of TaskRuns. The default limit is 256 combinations.

A `taskRef` with `resolver` and `params` fetches its Task through `tekton-pipelines-remote-resolvers`: the `cluster` resolver from another namespace (`kind`, `name`, `namespace`), the `git` resolver from a repository (`url`, `revision`, `pathInRepo`), and the `bundles`, `hub` and `http` resolvers from an OCI bundle, Artifact Hub or a URL. Only the definition is fetched; the TaskRun runs in the namespace of the `PipelineRun`, and a missing Task fails the run with `CouldntGetTask`. A custom task has a `taskRef` with `apiVersion` and `kind`; Tekton creates a `CustomRun` for it, and only a controller for that kind can run it. Without one, the `CustomRun` gets no status until the run times out or is cancelled.

A good CI graph clones once, runs its checks in parallel, builds only after every check passed, guards the deploy with a `when` expression on the branch, and reports from `finally` with execution status instead of results. kaniko builds and pushes an image from a Dockerfile inside an ordinary container, without a Docker daemon or privileged mode. The key facts to remember are these:

- A matrix multiplies TaskRuns; its results come back as one array.
- A resolver changes where a Task comes from, not where it runs.
- A `CustomRun` needs its own controller.
- Tag images with a commit hash, run TaskRuns that write to the cluster as a ServiceAccount with only the permissions they need, and keep `finally` reports free of results.

<!-- astrona:playground:destroy -->
