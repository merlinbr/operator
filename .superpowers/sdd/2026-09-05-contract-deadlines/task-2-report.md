# Task 2 implementation report

## Files changed

- `autoload/game_state.gd`
- `tests/test_persistence.gd`
- `.superpowers/sdd/2026-09-05-contract-deadlines/task-2-report.md`

Pre-existing changes in `README.md`, `context.md`, the feature-idea files,
`next-features.md`, and `tests/run_all.ps1` were left untouched. UI and other
Task 3 files were also left untouched.

## Implementation

- Bumped `PROFILE_VERSION` to `3`.
- Kept `_migrate_v1_profile` as the version-1-to-version-2 contact and catalog
  migration, including an array guard for legacy contract input.
- Added `_migrate_v2_profile`, which assigns deadlines from the saved absolute
  minute and authored catalog windows only. It clears cutoffs for terminal and
  unpublished records and never trusts serialized reward or window data.
- Updated candidate loading and validation to stage version 1 through version 2,
  accept only validated version 2 or 3 profiles, and persist the version-2
  migration once. A migration write failure leaves the loaded in-memory state
  intact and leaves the existing candidate-recovery behavior in place.
- Restored only the mutable `deadline_at_minute` contract field from a profile.
- Added version-aware contract validation: version 2 does not require cutoff
  fields or allow `expired`; version 3 validates cutoff types and ranges,
  published/unpublished invariants, active identity, deadline outcomes, and
  authored terminal choices. `deadline_missed` is handled as a runtime reason,
  not as an authored complication choice, and remains rejected in version 2.
- Settled historical cutoffs after every successful load. Reconciliation keeps
  the saved clock and credits, publishes successors at the crossed cutoff, and
  saves changed state so repeated loads do not replay feedback.
- Updated persistence fixtures to construct a valid Day-27 active deadline and
  added actual file-load coverage for version-3 round trips, version-1 and
  version-2 migration, idempotent overdue reconciliation, and malformed cutoff
  and terminal-reason rejection.

## Migration and validation decisions

- `_read_profile_candidate` performs only the existing v1-to-v2 stage before
  validation. The v2-to-v3 stage is performed in `load_profile` only after the
  candidate has passed version-2 validation.
- Version 1 is never accepted as a final staging version. Non-integer and
  unsupported versions are rejected.
- A v3 available or active published record must have a non-negative cutoff;
  unpublished records must retain `-1`. Normal terminal records may retain the
  legacy `-1` cutoff, while a `deadline_missed` terminal record must be
  published, resolved, and retain a non-negative cutoff.
- Failed deadline outcomes are allowed for active records that crossed a
  cutoff; expired deadline outcomes are allowed for offers. Both require the
  runtime `deadline_missed` reason.

## Tests, commands, and observed output

The save-writing tests were run from disposable staged project copies under
`C:\Users\merli\AppData\Local\Temp\opencode`, each with a unique Godot
project name and therefore a separate `user://` identity. The repository shell
did not expose the requested `Sync-DeadlineStage` and `Invoke-DeadlineSuite`
PowerShell functions, so the equivalent direct Godot invocations were used.

```text
godot --headless --path <disposable-stage> --script res://tests/test_persistence.gd
RESULT: ALL PASSED
EXIT_CODE=0

godot --headless --path <disposable-stage> --script res://tests/test_deadlines.gd
RESULT: ALL PASSED
EXIT_CODE=0

git diff --check
exit 0
```

The persistence output included the expected diagnostics from deliberate atomic
write-failure and invalid-profile cases; their assertions passed. A final
all-test sweep in a disposable stage passed every suite except the known
Task-3 UI contract suite: `test_contracts` has four failures because
`contract_detail.gd` still reads removed `deadline_day` fields. That UI behavior
is explicitly outside Task 2 and was not changed.

## Concerns

- The full suite remains red only in the pre-existing Task-3-facing
  `test_contracts` coverage until the UI deadline migration is implemented.
- The required persistence and deadline suites pass completely in disposable
  identities.
