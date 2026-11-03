# Summary

Remote resolution lets a run use definitions that live somewhere else: another namespace, a Git repository or a URL. The mechanism is the same for all of them, and so are the places you look when it fails.

## What you learned

A `taskRef` or `pipelineRef` with `resolver` and `params` makes the controller create a `ResolutionRequest`. A resolver in `tekton-pipelines-remote-resolvers` fills it with the content, and the controller runs the result as if it were inline. The run waits in `ResolvingPipelineRef` or `ResolvingTaskRef`, and fails with `CouldntGetPipeline` or `CouldntGetTask`. Each built-in resolver can be switched off in the ConfigMap `feature-flags` of `tekton-pipelines-resolvers`.

The `cluster` resolver takes `kind` (lowercase), `name` and `namespace`, and `cluster-resolver-config` limits it with `allowed-namespaces` and `blocked-namespaces`. The `git` resolver takes `url`, `revision` and `pathInRepo`, and `git-resolver-config` sets the defaults and `fetch-timeout`. The `http` resolver takes `url`. Only a commit hash gives the same definition every time. The key facts to remember are these:

- A resolver changes where a definition comes from, not where it runs.
- Local names in a resolved Pipeline resolve in the namespace of the run.
- A branch moves; pin a commit for anything that ships.
- A failed resolution leaves no TaskRuns; read the run, then the ResolutionRequest, then the resolver logs.
- A finished run does not retry; create a new one after fixing the cause.
- The `bundles` resolver fetches from an OCI image, best pinned by digest. The `hub` resolver fetches from a catalog, and its version must be pinned and written as a string.

<!-- astrona:playground:destroy -->
