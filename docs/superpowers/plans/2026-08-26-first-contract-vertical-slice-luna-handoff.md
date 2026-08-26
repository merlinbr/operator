# Luna Handoff: First Contract Vertical Slice

## Start Here

Implement the approved plan in:

`docs/superpowers/plans/2026-08-26-first-contract-vertical-slice.md`

Read the approved design first:

`docs/superpowers/specs/2026-08-26-first-contract-vertical-slice-design.md`

The plan is authoritative for task order, exact test assertions, method names, file ownership, commands, and commit boundaries. Do not begin implementation until both documents are read.

## Goal

Make one playable 5–10 minute contract loop in the current Godot terminal workspace:

```text
Contract Network
→ select C-1042 Cold-Chain Delivery
→ Accept or Close
→ Proceed to Dock 17
→ Customs decision
→ terminal outcome
→ Credits/Heat/time/ticker/Mara feedback
→ Acknowledge back to Contract Network
```

Keep Contract Detail as the existing adjacent floating ContextHost panel. Do not make a full-screen contract UI.

## Non-Negotiable Gameplay Facts

- Contract: `C-1042 // COLD-CHAIN DELIVERY` for Vesper Logistics, Dock 17.
- Deadline display: `DAY 15 // 04:00`.
- Initial clock: Day 14 // 23:41.
- `PROCEED TO DOCK 17` advances **exactly 80 minutes** to Day 15 // 01:01.
- Before accept, the dismiss action is `CLOSE`; it changes no contract state. There is no Decline action or `declined` status.
- Valid statuses only: `available`, `active`, `completed`, `failed`.
- The two non-C-1042 catalog entries remain visible but disabled as unavailable; they never open detail or emit selection.

### Customs outcomes — deterministic

| Choice | Status | Credits | Heat | Other effect |
|---|---|---:|---:|---|
| Pay clearance fee | completed | +1,150 CR | +0 | None |
| Call Mara | completed | +1,400 CR | +0 | `GameState.mara_favor_owed = true` |
| Bypass inspection | completed | +1,400 CR | +2 | None |
| Abort delivery | failed | +0 CR | +0 | None |

`mara_favor_owed` is one explicit boolean only. Do not build a contact, favor, debt, relationship, reputation, dialogue, or message-thread system around it.

## Required Ownership

| Owner | Owns | Must not own |
|---|---|---|
| `GameState` | Runtime contracts, active ID, transitions, time/Credits/Heat effects, messages, Mara boolean, signals/ticker effects | Panel layout, selection UI |
| `data/contracts/contract_catalog.gd` | Fresh static contract dictionaries | Mutable state, singleton behavior |
| `ContractsPanel` | Rows and selectable/disabled treatment; emits contract ID | Contract mutation |
| `ContractDetail` | Offer/active/Customs/result rendering; intent signals | State mutation, outcome calculation |
| `Main` | Selected ID while detail is open; connects UI intent to GameState; re-renders existing panels | Rules/effects/state machine |
| `CommsPanel` | Existing display of `GameState.messages` when opened | Live chat/dialogue features |

Preserve the project convention: injected `GameState` through `setup()`; no component accesses the autoload singleton by name.

## Required Public Interfaces

```gdscript
# GameState
func get_contract(id: StringName) -> Dictionary
func accept_contract(id: StringName) -> bool
func proceed_contract(id: StringName) -> bool
func resolve_contract(id: StringName, choice_id: StringName) -> bool
func add_message(sender: String, preview: String) -> void

signal contracts_changed
signal messages_changed

# ContractsPanel
signal contract_selected(contract_id: StringName)

# ContractDetail
signal accept_requested(contract_id: StringName)
signal proceed_requested(contract_id: StringName)
signal resolution_requested(contract_id: StringName, choice_id: StringName)
signal close_requested
signal acknowledge_requested
```

Invalid GameState transition calls return `false` and mutate nothing.

## Execute in This Exact Order

1. **Static catalog** — create `ContractCatalog`; add `test_contract_catalog.gd`.
2. **State start/proceed** — GameState contract collection, lookup, accept, exact 80-minute proceed transition.
3. **State outcomes** — resolver, messages, ticker feedback, Mara boolean, each terminal branch.
4. **Network UI** — disabled unavailable/terminal rows and ID-only selection signal.
5. **Detail UI** — phase-based rendering and intent-only buttons/signals.
6. **Main/Comms wiring** — GameState injection, context re-rendering, Close/Acknowledge behavior.
7. **Clean cutover** — remove obsolete placeholder data/test files, run focused/full tests, manually smoke all four outcomes.

Each task in the implementation plan is intentionally split into tiny red/green/commit steps. Do not fold tasks together or refactor unrelated shell/UI code.

## Test Commands

Run every command through `rtk`:

```powershell
rtk powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\run_test.ps1 test_contract_catalog
rtk powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\run_test.ps1 test_game_state
rtk powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\run_test.ps1 test_contracts
rtk powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\run_test.ps1 test_main
rtk powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\run_test.ps1 test_panels_basic
```

Use fresh `GameState` fixtures for every terminal result. The focused state tests must prove:

- Day 14 // 23:41 → Day 15 // 01:01 after Proceed;
- all four exact Credits/Heat outcomes;
- `mara_favor_owed` only for Call Mara;
- invalid transitions have no side effects;
- active ID clears on every terminal result.

Do not add test frameworks, fixtures, mock systems, or test-only production branches.

## Explicitly Out of Scope

- RNG, deadlines expiring, Heat threshold logic, timers, or a global time-control feature.
- Procedural contracts, contract Resources, event graphs, quest scripting, a new manager/autoload, or save-game work.
- Combat, navigation, ship/crew/inventory systems, factions/economy, reputation, galaxy map.
- Generalized dialogue, relationship, favor, contact, or Comms interaction systems.
- Workspace redesign, HUD/rail/theme/environment changes, or any full-screen UI.

## Existing Code Landmarks

- `autoload/game_state.gd` already owns Credits, Heat, clock, ticker signal, and workspace state.
- `scenes/main/main.gd` already owns `PrimaryHost`, `ContextHost`, panel setup, and detail placement.
- `scenes/modules/contracts/contracts_panel.gd` and `contract_detail.gd` are intentionally small programmatic panel scripts.
- `tests/test_base.gd` is the headless SceneTree harness; tests are `_run()` functions using `check(...)`.
- Existing shell placeholder providers are temporary: remove them only in the final cleanup task after every caller has migrated.

## Deliverable Standard

Do not report completion until the focused suite passes, the full existing headless suite passes, and the running Godot project has been manually exercised through each of the four outcomes. The final surface must visibly update the existing time/Credits/Heat/ticker/Comms UI and return to the still-open Contract Network after Acknowledge.
