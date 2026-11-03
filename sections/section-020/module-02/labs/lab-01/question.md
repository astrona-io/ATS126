# Question

Solve this question on: `terminal`

**Time:** about 25 minutes · **Topic:** Control flow

## Scenario

The cluster owner of the `starfleet` team has new rules for the Pipeline `render`. Every pod of a run must use the service account `builder` and run as the non-root user 1000. The task `build` is the heavy one and must have a memory limit, while `fetch` must stay unlimited. A run may take at most ten minutes. The Pipeline must stay as it is, because other teams use it with other rules.

## Your task

Create a PipelineRun named `render-run` in the namespace `starfleet` that:

1. Refers to the Pipeline `render` with `pipelineRef`.
2. Uses the service account `builder` for every pod, with a pod security context that sets `runAsNonRoot: true`, `runAsUser: 1000` and `fsGroup: 1000`.
3. Sets a memory limit of `128Mi` and a memory request of `64Mi` on the pipeline task `build` only.
4. Limits the whole run to 10 minutes, its tasks to 8 minutes and its `finally` tasks to 2 minutes.

Wait until the run has succeeded.

## Constraints

- Do not change the Pipeline `render` or the ServiceAccount `builder`.
- Do not embed the Pipeline with `pipelineSpec`.
- Do not change `config-defaults`.

## Done when

- The PipelineRun `render-run` succeeded and uses `pipelineRef` `render`.
- Its `taskRunTemplate` names the service account `builder` and the user 1000 with `runAsNonRoot`.
- Only the entry for `build` in `taskRunSpecs` has a memory limit, and it is `128Mi`.
- Its timeouts are `10m`, `8m` and `2m`.
- The pods of both tasks ran with the service account `builder` and the user 1000.
