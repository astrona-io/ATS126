# Question

Solve this question on: `terminal`

**Time:** about 30 minutes · **Topic:** Pipelines

## Scenario

The `starfleet` team publishes release notes with the Pipeline `release-notes`. The pipeline task `fetch` writes `notes.md` into a shared workspace, `lint` counts its lines and `spellcheck` counts its words, and `publish` sends a notice to a channel and returns it as the pipeline result `notice`. The two checks are slow, so the team designed them to run side by side. The PipelineRun `release-notes-run` for version `v1.4` has never worked.

## Your task

1. Find out why `release-notes-run` in the namespace `starfleet` fails. Each time you fix one fault, run it again and read the next failure.
2. Fix every fault. There are three: one in the PipelineRun and two in the Pipeline. One of them does not make the run fail, but makes it slower than designed.
3. Leave a PipelineRun named `release-notes-run` that succeeds and reports `notice` = `notes-v1.4 to launch-news: 3 lines, 11 words`.

## Constraints

- Do not change the four Tasks. In particular, do not give the parameter `channel` of `publish-notes` a default.
- The Pipeline keeps its workspace name `source` and its four pipeline tasks `fetch`, `lint`, `spellcheck` and `publish`. Both checks read `notes.md`, so both must still wait for `fetch`.
- `release-notes-run` must use `pipelineRef` name `release-notes` and the parameter `version` = `v1.4`, and must not set `channel`, so the Pipeline's default `launch-news` applies.

## Done when

- `lint` and `spellcheck` both declare `runAfter` with `fetch` and neither waits for the other, and `publish` passes `channel` = `$(params.channel)`.
- `release-notes-run` binds the workspace `source`, succeeded, its `notice` is `notes-v1.4 to launch-news: 3 lines, 11 words`, its TaskRuns of `lint` and `spellcheck` overlapped in time, and `publish` started after both had finished.
- A new PipelineRun with `version` = `v2.0` and `channel` = `outpost-news` succeeds with `notice` = `notes-v2.0 to outpost-news: 3 lines, 11 words`.
