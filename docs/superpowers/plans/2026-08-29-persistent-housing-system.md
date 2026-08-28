# Persistent Housing System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add persistent operator state, explicit REST time progression, recoverable rent, and a Studio/Loft housing choice.

**Architecture:** `GameState` remains the sole validator/mutator and persists one JSON profile. A static residence catalog defines the two homes; Home emits intents, while Environment swaps only its background texture from injected state. Rent is processed by every time-advance path, never UI code.

**Tech Stack:** Godot 4.7.1, GDScript, `FileAccess`, `JSON`, existing headless SceneTree tests.

## Global Constraints

- Implement `docs/superpowers/specs/2026-08-29-persistent-housing-system-design.md` exactly.
- Supply `res://assets/tier-2-appartment-update.png`, 1672×941, before environment integration; calibrate a Tier-2 environment-art profile rather than reusing Tier-1 effect coordinates.
- Persist at `user://operator_save.json`; malformed data starts clean and reports one actionable error.
- No financing, debt interest, eviction, equipment, contract buffs, extra residences, audio changes, or workspace redesign.
- Prefix shell commands with `rtk`.

---

### Task 1: Residence Catalog and Persistent Profile

**Files:**
- Create: `data/housing/residence_catalog.gd`
- Modify: `autoload/game_state.gd`
- Create: `tests/test_persistence.gd`

**Interfaces:**
- Produces `ResidenceCatalog.all()` with exact Studio/Loft fields from the spec.
- Produces `GameState.save_profile() -> bool`, `GameState.load_profile() -> bool`, `GameState.reset_profile() -> void`, and `residence_changed`/`rent_changed` signals.

- [ ] Write failing tests: a clean state has Studio, Day-30 rent, no ownership; mutate Credits/clock/contract/housing, save, recreate GameState, and assert every field restores; write malformed JSON and assert clean playable state.
- [ ] Run `rtk powershell -ExecutionPolicy Bypass -File tests/run_test.ps1 test_persistence`; expect missing catalog/method failures.
- [ ] Add the two authored records. Add GameState housing fields exactly from the spec and serialise all mutable gameplay fields to a temporary JSON file before replacing `operator_save.json`. Validate loaded IDs, nonnegative Credits, allowed rent statuses, contract records, and ownership; invalid input calls `push_error` once and resets authored state.
- [ ] Re-run `test_persistence`; expect `RESULT: ALL PASSED`.
- [ ] Commit: `rtk git add data/housing autoload/game_state.gd tests/test_persistence.gd && rtk git commit -m "feat: persist operator housing state"`.

### Task 2: Time, Rent, and Housing Intents

**Files:**
- Modify: `autoload/game_state.gd`
- Modify: `tests/test_game_state.gd`

**Interfaces:**
- Produces `rest_until_next_day()`, `pay_rent()`, `move_to_residence(id)`, `buy_out_current_residence()`, each returning `bool`.
- Contract: all successful mutations save once and emit existing/new notifications; rejected calls do neither.

- [ ] Write failing tests for active-contract REST rejection; REST to next-day midnight; automatic 2,000/6,000 rent payment; one due bill; overdue after three days; due payment scheduling 30 days from payment; travel crossing multiple due dates; move cost 8,000; studio buyout cost 150,000; and blocked move/buy with due rent.
- [ ] Run `rtk powershell -ExecutionPolicy Bypass -File tests/run_test.ps1 test_game_state`; expect missing intent-method failures.
- [ ] Route both `advance_minutes()` and REST through one private calendar settlement function. It processes each crossed due date, never duplicates unpaid rent, and sets `due`/`overdue` exactly as specified. Implement each intent with catalog lookup, current-residence/rent/funds checks, exact deductions, semantic signals, ticker/Comms feedback, then `save_profile()`.
- [ ] Re-run `test_game_state`; expect `RESULT: ALL PASSED`.
- [ ] Commit: `rtk git add autoload/game_state.gd tests/test_game_state.gd && rtk git commit -m "feat: add rent and residence progression"`.

### Task 3: Home Residence Controls

**Files:**
- Modify: `scenes/modules/home/home_panel.gd`
- Modify: `tests/test_panels_basic.gd`

**Interfaces:**
- Produces intent signals `rest_requested`, `rent_payment_requested`, `move_requested(id)`, `buyout_requested`.
- Home reads GameState snapshots/signals but never changes Credits, calendar, or rent itself.

- [ ] Write failing tests for `RESIDENCE` copy, current rent/due labels, REST disabled during active work, PAY RENT only when due, and two-step exact-cost confirmation buttons.
- [ ] Run `rtk powershell -ExecutionPolicy Bypass -File tests/run_test.ps1 test_panels_basic`; expect missing nodes/signals.
- [ ] Build a compact Residence section and confirmation state. Connect intents in `main.gd` to GameState methods, refresh Home after successful signals, and retain existing Home summary behavior.
- [ ] Re-run focused test; expect all existing and residence assertions pass.
- [ ] Commit Home/Main/tests with `feat: add residence terminal controls`.

### Task 4: Residence Artwork and Regression

**Files:**
- Modify: `scenes/main/environment.gd`
- Modify: `scenes/main/main.gd`
- Modify: `tests/test_environment.gd`
- Modify: `tests/test_main.gd`

- [ ] Write failing tests proving Studio selects existing art, Loft selects `tier-2-appartment-update.png`, and each residence uses its authored window/effect rectangles without changing Workspace order, mouse filtering, or time profiles.
- [ ] Run `rtk powershell -ExecutionPolicy Bypass -File tests/run_test.ps1 test_environment` and `test_main`; expect art-selection failures.
- [ ] Add the Tier-2 preload plus an authored per-residence art profile for source size, window, spill, glint, and lightning UV rectangles. On residence change, select the texture and its profile; retain the existing effect-node order and workspace behavior.
- [ ] Re-run both focused tests; expect `RESULT: ALL PASSED`.
- [ ] Run full suite: `rtk powershell -NoProfile -Command "Get-ChildItem tests/test_*.gd | ForEach-Object { & .\tests\run_test.ps1 $_.BaseName; if (`$LASTEXITCODE -ne 0) { exit `$LASTEXITCODE } }"`.
- [ ] Manually verify REST, automatic/due/overdue recovery, Studio/Loft move, Studio buyout, restart persistence, corrupt-save recovery, and both artworks.
- [ ] Commit: `rtk git add scenes/main tests && rtk git commit -m "feat: render persistent residence upgrades"`.

## Plan Self-Review

- Task 1 establishes the authored catalog and durable state required by every later task.
- Task 2 centralizes all calendar/rent rules in GameState and covers recovery boundaries.
- Task 3 adds UI intent only; Task 4 owns visual selection only.
- Financing remains absent; no task introduces a generic financial, equipment, or audio abstraction.
