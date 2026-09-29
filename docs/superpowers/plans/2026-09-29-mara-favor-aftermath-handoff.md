# Implementation Handoff: Mara Favor and Aftermath

## Start here

1. Read the **approved design**: `docs/superpowers/specs/2026-09-29-mara-favor-aftermath-design.md` (commit `b9e9ee5`).
2. Execute the **ordered implementation plan**: `docs/superpowers/plans/2026-09-29-mara-favor-aftermath.md` (commit `22e5893`). It contains file ownership, concrete scenarios, save migration, test commands, smoke path, and commit boundaries. Read live files before edits; the repository may change before implementation.
3. No feature code was written in this session. Planning is approved; no need to reopen the design choices unless implementation reveals a contradiction.

## Decisions that must survive handoff

- Mara only, not a generic per-contact ledger. `mara_favor_balance` is `-1` (player owes), `0` (square), or `+1` (Mara owes player). Opposite favors cancel; no simultaneous mutual debt.
- `call_mara` on C-1042 incurs debt; `trace_tag` on M-508 earns one step of credit; R-311 hand delivery settles negative debt; a new M-613 favor-backed clean route spends positive credit for +5,600 CR, Heat +0. Keep all existing routes available under their existing gates.
- The lasting favor balance and later contract choices **are** the aftermath. Do not add delayed/instant follow-up messages, timers, event queues, threads, or extra contracts. Keep ordinary resolution messages.
- Comms shows Mara's balance; favor-affecting resolution buttons get a light accent, with words in previews describing the actual favor transition. `trace_tag` must say **FAVOR SETTLED** when it cancels debt, not falsely claim Mara owes the player.
- Bump saves from v4 to v5, mapping the old `mara_favor_owed` boolean to `-1` or `0`; preserve older version migrations and deadline/preparation persistence. Remove old favor flags and boolean from current code and tests; keep the old field only in migration/legacy fixtures.
- User explicitly deferred crew, inventory, market, maps, and similar breadth systems. Update `next-features.md` after verifying this depth pass.

## Current code entry points

- `autoload/game_state.gd`: `_available_choices()`, `resolve_contract()`, `_push_resolution_feedback()`, `contact_snapshot()`, `_profile_payload()`, `_validate_profile()`, `load_profile()`.
- `data/contracts/contract_catalog.gd`: C-1042, M-508, R-311, M-613 authored choice dictionaries.
- `scenes/modules/contracts/contract_detail.gd`: `_render_customs()` / `_render_resolved()`; `scenes/modules/comms/comms_panel.gd`: `_make_contact_row()`.
- Existing suites are `tests/test_game_state.gd`, `test_persistence.gd`, `test_contracts.gd`, `test_panels_basic.gd`, plus `test_deadlines.gd`, `test_preparation.gd`, and `test_contract_catalog.gd`. The test runner is `tests/run_test.ps1`; read it before changing commands.

## Working-tree and verification cautions

- At planning time, `feature-ideas-a.md` through `feature-ideas-d.md`, `.pi/`, and `tests/run_all.ps1` were untracked user files. Do not stage, delete, or treat them as implementation artifacts. Check the working tree again before starting; changes made after this handoff belong to the user unless explicitly assigned.
- The spec and plan were written and reviewed, **not** exercised against a changed build. Implementation must run focused tests, the project UI smoke path, then all existing suites as described in the plan. Do not claim behavioral verification from this planning session.
- Follow the plan task order; make code and tests complete before changing `next-features.md`. Preserve unrelated work and stage only named files in commits.
