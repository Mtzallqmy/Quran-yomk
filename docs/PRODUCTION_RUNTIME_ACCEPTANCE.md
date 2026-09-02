# Tarteel Radio Production Runtime Acceptance

Status: **FAIL — P0 OPEN**

This document records the current combined-runtime evidence. A green unit/integration suite or separate Icecast/Liquidsoap soak is not sufficient to mark this gate PASS. The required acceptance is one protected runtime path from persisted scheduling/commands through the real coordinator and audio stack to decoder ACK/history/Now Playing.

## Exact candidate commit

- Commit: `8a0686fc736b925a974578f48f7370489e7163cf`
- Branch: `hardening/phase5-radio-runtime`
- Pull request: `#14` — draft

## Environment type

- Non-production protected Supabase project endpoint: `qkroecnecdxghcqvvoxn.supabase.co`
- Dedicated development station id: `00000000-0000-4000-8000-000000000006`
- GitHub-hosted Ubuntu runner
- Local ephemeral Icecast credentials are generated per run
- Liquidsoap and FFmpeg are installed on the same runner as the Radio Engine coordinator

The workflow explicitly refuses to proceed without a protected Supabase runtime credential. No credential value is recorded in this document or in artifacts.

## Required runtime path

```text
Schedule / command state in Supabase
  -> occurrence materialization / claim
  -> queue persistence
  -> command processing / decision
  -> Radio Engine coordinator
  -> Liquidsoap
  -> Icecast
  -> FFmpeg decoder/listener
  -> playback ACK correlation
  -> play history
  -> Now Playing
```

## Latest combined-runtime run

- GitHub Actions run: `33645081793`
- Workflow: `Radio Combined Runtime Acceptance`
- Result: **FAIL**
- Failing step: `Preflight protected runtime credential`
- Failure class: required secret-backed Supabase runtime credential was unavailable to the workflow run

Because preflight failed, the following acceptance steps did **not** execute in that run:

- Radio Engine build/unit/reliability execution inside the combined gate;
- real Icecast startup for the combined gate;
- deterministic development media fixture creation;
- protected coordinator startup;
- Supabase -> coordinator -> Liquidsoap -> Icecast -> FFmpeg execution;
- ACK/history/Now Playing proof.

Therefore the combined runtime is not accepted and no production PASS claim is valid.

## Scenario coverage required before PASS

The coordinator/unit/reliability tests in this PR cover application behavior, but the final protected runtime acceptance must demonstrate the real path for the relevant scenarios before this document can become PASS:

- normal scheduled transition;
- `PLAY_NOW`;
- `PLAY_NEXT`;
- `SKIP`;
- `STOP_AFTER_CURRENT`;
- `RESUME_AUTO`;
- duplicate command/idempotency;
- engine restart;
- stale fencing token;
- media/provider resolution failure;
- empty queue/fallback;
- temporary DB failure where safely reproducible;
- no listeners;
- multiple listeners.

A scenario may be backed by a deterministic lower-level test when forcing it in the protected shared runtime would be unsafe, but the core schedule/command -> real audio -> ACK/history/Now Playing chain must be demonstrated end to end in one run.

## Metrics and evidence

Current combined-run metrics: **not available**, because execution stopped before the runtime started.

Expected evidence after a successful run:

- sanitized coordinator log artifact;
- `combined-runtime-result.json` with command/queue/ACK/history/Now Playing identifiers and timings;
- Icecast readiness and decoder success;
- exact workflow run id and candidate commit;
- no secret values in logs/artifacts.

## Open risks

1. **P0 — protected credential gate:** the combined workflow cannot currently access a valid runtime database credential.
2. **P0 — unproven one-runtime chain:** separate database and audio-path evidence does not prove their coordination in one runtime.
3. **P1 — branch is still draft:** PR #14 must remain unmerged until the protected combined gate is green on the final candidate commit.

## PASS criteria

Change this document to PASS only when all of the following are true on the exact release candidate commit:

- protected credential preflight succeeds;
- combined runtime starts against the dedicated non-production station;
- real Liquidsoap/Icecast stream is decoded by FFmpeg;
- the persisted command/queue item correlates to a playback ACK;
- play history and Now Playing reflect that same media identity;
- fencing/idempotency/restart tests are green;
- evidence artifacts are sanitized and retained;
- no production-enabled station was modified by the test.

Until then, Radio Production Runtime Closure remains **P0 OPEN**.
