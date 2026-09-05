# Task 3 implementation report

## Files changed

- `scenes/modules/contracts/contracts_panel.gd`
- `scenes/modules/contracts/contract_detail.gd`
- `scenes/main/main.gd`
- `tests/test_contracts.gd`
- `tests/test_main.gd`
- `README.md`
- `context.md`
- `next-features.md`
- `.superpowers/sdd/2026-09-05-contract-deadlines/task-3-report.md`

The pre-existing edits in `README.md`, `context.md`, `next-features.md`, the
feature-idea files, and `tests/run_all.ps1` were preserved. The feature-idea
files and `tests/run_all.ps1` were not part of this Task 3 commit.

## Implementation

- Added the `EXPIRED // ...` row state. The existing terminal-state
  selectability predicate continues to disable expired records.
- Replaced fixed-date detail rendering with the persistent
  `deadline_at_minute` display and authored execution duration on offer and
  active screens. Added the text warning when proceeding would reach or cross
  the cutoff without disabling the action.
- Added system-owned `deadline_missed` result rendering with the calculated
  deadline, zero reward/Heat, and only `ACKNOWLEDGE`; authored complication
  choices are not consulted for this outcome.
- Connected the injected `GameState.clock_changed` signal in `main.gd` so an
  open selected contract detail refreshes as the clock changes. Existing
  contract-change refreshes and semantic audio signals remain separate.
- Extended the focused contract UI test with expired rows, calculated timing,
  late-arrival warning, deadline failure, acknowledgement, and stale-action
  removal. Extended the existing main-scene fixture to prove selected-detail
  clock refresh while retaining the normal audio journey.
- Updated the three existing documents with the implemented
  publication-relative deadline behavior, persistent remaining windows, hard
  expiry/failure, and the approved design link. Heat, preparation, and favor
  work remain future features.

## Tests and commands

Godot 4.7.1 was run from disposable staged copies under
`C:\Users\merli\AppData\Local\Temp\opencode`. The requested
`Sync-DeadlineStage` and `Invoke-DeadlineSuite` functions were not available,
so equivalent direct Godot invocations were used. No checked-in runner was
used because it targets the real project identity.

Focused runs, after staging the final working files:

```text
godot --headless --path <stage> --script res://tests/test_contracts.gd
RESULT: ALL PASSED
EXIT_CODE=0

godot --headless --path <stage> --script res://tests/test_main.gd
RESULT: ALL PASSED
EXIT_CODE=0
```

The complete existing suite was then run once by enumerating every
`tests/test_*.gd` file directly. All 16 suites printed `RESULT: ALL PASSED`
and exited 0: `test_base`, `test_boot`, `test_contract_catalog`,
`test_contracts`, `test_deadlines`, `test_environment`, `test_game_state`,
`test_icon_rail`, `test_main`, `test_module_registry`, `test_panels_basic`,
`test_persistence`, `test_smoke`, `test_status_chip`, `test_theme`, and
`test_ticker_bar`.

```text
git diff --check
exit 0
```

The existing persistence suite also passed its Task 2 coverage for current
version reloads, v1/v2 migration, cutoff preservation, and idempotent overdue
reconciliation.

## Runtime verification

The exact disposable seed script from the brief was created only in the stage
as `deadline_smoke.gd` and exited 0:

```text
Deadline smoke profile ready; user data: C:/Users/merli/AppData/Roaming/Godot/app_userdata/OperatorDeadlineTask3-cef749fc5fce4010941e79b7b59977f0
```

The normal staged project was launched through the Godot runtime tool on the
D3D12 renderer and stopped cleanly. The available runtime tooling provided no
window input or screenshot surface, so a manual graphical playthrough was not
claimed. Instead, two stage-only disposable main-scene drivers exercised the
actual `main.tscn` surface and were removed afterward:

- The initial-clock driver confirmed the opening offer cutoff and 80-minute
  duration, REST to Day 15 00:00 without expiry, REST to Day 16 00:00 with the
  opening row expired/disabled, successor windows processed chronologically,
  unchanged Credits/Heat, and the missed-deadline Comms message.
- The seeded late-active driver confirmed the selected-detail warning, actual
  main-scene proceed action, immediate deadline failure, no customs/stale
  actions, active-slot release, failed row refresh, usable Data Retrieval
  successor timing, and reload without cutoff renewal or duplicate feedback.

Both direct drivers printed `RESULT: ... MAIN DEADLINE SMOKE PASSED` and exited
0. The staged project and its unique user-data directory were removed after
verification. The real `Operator` profile was not removed or reset.

## Concerns

- Manual graphical interaction and screenshots were unavailable; runtime
  evidence is the successful D3D12 launch plus direct headless main-scene
  surface inspection.
- Godot emitted existing non-fatal project warnings during runtime startup
  (global-name shadowing, integer-division, and test-harness object/audio
  cleanup diagnostics). No parser errors, crashes, save loss, or stale-action
  failures occurred, and all assertions passed.
- No deviations from the approved Task 3 brief were made.
