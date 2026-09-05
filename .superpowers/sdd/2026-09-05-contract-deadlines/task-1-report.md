# Task 1 implementation report

## Files changed

- `data/contracts/contract_catalog.gd`
- `autoload/game_state.gd`
- `tests/test_deadlines.gd`
- `tests/test_deadlines.gd.uid`
- `tests/test_contract_catalog.gd`
- `.superpowers/sdd/2026-09-05-contract-deadlines/task-1-report.md`

Pre-existing changes in `README.md`, `context.md`, the feature-idea files,
`next-features.md`, and `tests/run_all.ps1` were left untouched.

## Implementation

- Replaced all seven fixed calendar deadline pairs with the required
  publication windows: `259, 360, 480, 720, 360, 480, 720` minutes, plus an
  unassigned `deadline_at_minute` of `-1`.
- Added absolute-minute initialization for `GameStateScript.new()` and
  `reset_profile()`, the deadline predicate, and publication-time stamping.
  Publication is first-unlock-only and never renews terminal or already
  published records.
- Added bounded chronological deadline settlement. Advancement stops at the
  target, midnight, or the next cutoff; rent settles before a midnight cutoff,
  and successors use the crossed cutoff as their publication time. Deadline
  outcomes emit the existing contract signals and feedback without applying
  authored rewards or penalties.
- Added availability, proceed, and resolution deadline guards. Travel that
  crosses its cutoff returns accepted (`true`) while preserving the emitted
  terminal failure and saving; it does not emit arrival/proceed feedback.
- Routed the existing REST-to-midnight action through `_advance_minutes()` so
  rest also settles deadlines chronologically while retaining its housing and
  feedback behavior.
- Added the specified boundary/regression suite and catalog invariants for
  on-time execution windows and authored abort routes.

## Tests and observed output

All commands used Godot 4.7.1 in a staged copy with a unique project name and
user-data identity under `C:\Users\merli\AppData\Local\Temp\opencode`.

1. The required pre-implementation red check ran after adding the focused test
   and catalog fields. Import succeeded (`exit 0`); `test_deadlines` failed as
   expected with a parse error because `_unlock_contracts` still accepted one
   argument.
2. Focused staged runs:

   ```text
   godot --headless --path <stage> --script res://tests/test_deadlines.gd
   godot --headless --path <stage> --script res://tests/test_game_state.gd
   godot --headless --path <stage> --script res://tests/test_contract_catalog.gd
   ```

   Each exited `0` and printed `RESULT: ALL PASSED`.

The deadline and game-state runs also printed the existing profile-recovery
diagnostic after the assertions: `Unable to load operator profile: profile
candidates are unreadable, malformed, or incompatible. Starting clean.` This
is the expected Task 1/Task 2 boundary: Task 1 can leave an `expired` record,
while the current pre-migration validator still accepts only the old status
set. The diagnostic occurred only in the disposable identity.

The full suite, persistence suite, and UI suite were not run because Task 2
must first migrate/validate persisted cutoffs and Task 3 must migrate the UI
from fixed-date fields, as directed by the plan.

## Concerns

- Task 2 still needs to persist/restore `deadline_at_minute`, migrate v1/v2
  saves, validate `expired` and `deadline_missed`, and reconcile overdue loads.
- Task 3 still needs to replace UI consumers of `deadline_day` and
  `deadline_minute`; those consumers are intentionally unchanged here.
