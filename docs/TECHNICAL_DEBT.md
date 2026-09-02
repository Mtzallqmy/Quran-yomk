# Technical Debt Register

| ID | Severity | Area | Description | Risk | Recommended fix |
|---|---|---|---|---|---|
| TD-001 | P1 | Android CI | Formatting mutates the CI workspace instead of check-only mode. | CI can hide formatting drift. | Switch to Dart format check mode during CI reorganization. |
| TD-002 | P0-ENV | Radio acceptance | The combined protected Radio runtime has no configured Actions runtime credential, so its fail-closed preflight stops the run. | One-runtime production acceptance remains unproven. | Configure the protected DEVELOPMENT runtime value and rerun the combined workflow. |
| TD-003 | P1 | Quran API | Canonical Quran data exists, but the public Quran API still needs final proof/cutover away from mutable live text. | Production text can remain upstream-dependent. | Complete canonical read cutover with parity and checksum tests. |
| TD-004 | P2 | Admin | `lib/api.ts` and `admin-client.tsx` remain large multi-domain files. | Higher review and maintenance cost. | Extract domain services and panels incrementally after security gates stabilize. |
| TD-005 | P2 | Flutter | Mushaf, radio and player screens remain large. | Higher refactor risk. | Extract tested feature helpers incrementally; do not rewrite screens wholesale. |
