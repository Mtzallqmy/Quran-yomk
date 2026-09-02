# Production Runtime Acceptance

## Status

**BLOCKED — environment credential gate, not declared PASS.**

The application-side Phase 6B coordinator is implemented and the existing real Liquidsoap/Icecast regressions are preserved, but the single combined protected runtime GitHub Actions job cannot start its Supabase-backed portion because the repository does not currently expose any of the expected protected runtime secrets to the workflow.

## Commit under acceptance

Radio combined-runtime implementation head: `8a0686fc736b925a974578f48f7370489e7163cf`.

## Environment type

- GitHub Actions Ubuntu runner.
- Real Liquidsoap and Icecast runtime.
- Real FFmpeg decoder/listener.
- Intended DEVELOPMENT Supabase control-plane target.
- Protected service credential required; publishable keys are explicitly rejected as substitutes.

## Proven code path

Scheduler → occurrence materialization → fenced occurrence claim → persistent queue entry → command processing/effect ledger → Radio Engine → Liquidsoap → Icecast → decoder/listener → playout ACK → history / Now Playing.

The coordinator implementation connects these stages in one long-running process. Reliability tests cover recovery of stale command effects, duplicate work, restart/fencing and temporary store failures.

## Existing passing evidence

Historical Phase 5B and Phase 6 real-stream runs proved Liquidsoap/Icecast, two listeners, no-listener intervals, fixed mount, schedule transitions, PLAY_NOW and PLAY_NEXT, ACK correlation and protected Supabase persistence in trusted executions. See `PHASE5B_REAL_ICECAST_REPORT.md` and `PHASE6_RADIO_AUTOMATION_REPORT.md`.

## Combined acceptance run

Workflow: `.github/workflows/radio-combined-runtime.yml`.

Latest inspected run: `33645081793`.

Result: **FAIL at protected-runtime credential preflight**. Runtime steps were skipped because none of these GitHub Actions secrets was available:

- `TARTEEL_RADIO_SUPABASE_SECRET_KEY`
- `TARTEEL_SUPABASE_SERVICE_ROLE_KEY`
- `SUPABASE_SERVICE_ROLE_KEY`

This is intentionally fail-closed. A publishable/anon key must not be used to make the test green.

## Required acceptance scenarios

The combined workflow/test harness is expected to exercise or preserve coverage for:

- normal scheduled transition;
- PLAY_NOW;
- PLAY_NEXT;
- SKIP;
- STOP_AFTER_CURRENT;
- RESUME_AUTO;
- duplicate command/effect idempotency;
- engine restart and recovery;
- stale fencing token rejection;
- provider/media failure;
- empty queue and fallback decision;
- temporary DB/store failure and recovery where safely injectable;
- no listeners;
- multiple listeners;
- ACK → Play History / Now Playing correlation.

## Metrics/evidence contract

Acceptance artifacts must include exact commit, duration, mount/decoder failures, command/occurrence counts, listener count, fencing/recovery events, ACK count, history/Now Playing correlation, and redacted log references. Secrets and Quran text must not be written to evidence.

## Open risk

Until a protected DEVELOPMENT credential is supplied to the combined workflow and the workflow passes, requirement "Radio Engine proven end-to-end in one secret-backed runtime" remains open. This blocker must not be hidden by a documentation PASS or a lower-privilege substitute.

## Resolution

Configure one protected service credential in GitHub Actions, rerun `Radio Combined Protected Runtime`, inspect its artifact/logs, update this document with the successful run ID and exact tested commit, then mark the radio P0 closed.
