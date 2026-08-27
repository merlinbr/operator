# Luna Handoff: Early Contract Portfolio

## Start Here

Implement the approved plan in:

`docs/superpowers/plans/2026-08-28-early-contract-portfolio.md`

Read the approved design first:

`docs/superpowers/specs/2026-08-28-early-contract-portfolio-design.md`

The implementation plan is authoritative for task order, exact fields, test assertions, method names, commands, and commit boundaries. Do not begin implementation until both documents are read.

## Goal

Turn the existing single-contract vertical slice into a small, deterministic early-game portfolio:

```text
C-1042 Cold-chain Delivery resolves
→ D-207 Data Retrieval becomes available
→ D-207 resolves
→ R-311 Clinic Asset Recovery becomes available
→ R-311 resolves
→ early portfolio complete
```

A success **or failure** unlocks the next contract. This must never dead-end the player.

Keep the existing floating workspace: Contract Network is the primary panel and Contract Detail stays in its adjacent `ContextHost`. No full-screen contract UI.

## Non-Negotiable Gameplay Facts

### Portfolio order and availability

| Order | Contract | Initial availability | Success/failure result |
|---:|---|---|---|
| 1 | `C-1042 // COLD-CHAIN DELIVERY` | Enabled | Enables D-207 |
| 2 | `D-207 // DATA RETRIEVAL` | `NETWORK OFFLINE` | Enables R-311 |
| 3 | `R-311 // CLINIC ASSET RECOVERY` | `NETWORK OFFLINE` | Completes the early portfolio |

Reuse the current `is_playable` field as this minimal availability gate. Do not add a progression resource, unlock manager, quest state, or new contract status.

Contract statuses remain exactly `available`, `active`, `completed`, and `failed`. Phases remain exactly `offer`, `ready_to_proceed`, `customs_hold`, and `resolved`.

### C-1042 regression contract

Do not change its visible terminal effects:

| Choice | Status | Credits | Heat | Other effect |
|---|---|---:|---:|---|
| Pay clearance fee | completed | +1,150 CR | +0 | Enables D-207 |
| Call Mara | completed | +1,400 CR | +0 | Sets `mara_favor_owed`; enables D-207 |
| Bypass inspection | completed | +1,400 CR | +2 | Enables D-207 |
| Abort delivery | failed | +0 CR | +0 | Enables D-207 |

Initial Heat is 2. Therefore Bypass raises it to 4 and changes D-207’s available identity route.

### D-207 — Data Retrieval

- **Client:** Northline Systems
- **Destination:** `SECTOR 9 // TRANSIT EXCHANGE`
- **Reward:** 4,200 CR
- **Risk:** Elevated
- **Deadline:** Day 15 // 07:00
- **Proceed action:** `PROCEED TO TRANSIT EXCHANGE`, exactly +55 minutes.
- **Complication:** `REMOTE AUDIT // TRANSIT EXCHANGE`.

At the complication, these outcomes are deterministic:

| Choice | Availability | Credits | Heat | Result |
|---|---|---:|---:|---|
| Spoof service credentials | Heat below 4 | +4,200 CR | +0 | Quiet shard retrieval |
| Buy clean access token // 400 CR | Always | +3,800 CR | +0 | Audited access purchased |
| Force kiosk readout | Always | +4,200 CR | +1 | Audit recorded |
| Use routed vendor ID // 650 CR | Heat 4 or above | +3,550 CR | +0 | Safe alternate identity purchased |
| Abort retrieval | Always | +0 CR | +0 | Failed |

`SPOOF SERVICE CREDENTIALS` and `USE ROUTED VENDOR ID // 650 CR` are mutually exclusive. They are a visible substitution, not disabled controls. A hidden option must also be rejected by `GameState.resolve_contract()` without changing state.

Every D-207 terminal choice enables R-311.

### R-311 — Clinic Asset Recovery

- **Client:** Vesper Community Clinic
- **Destination:** `LOWER VESPER // MEDICAL SUBLEVEL`
- **Reward:** 3,200 CR
- **Risk:** Moderate
- **Deadline:** Day 15 // 12:00
- **Proceed action:** `PROCEED TO MEDICAL SUBLEVEL`, exactly +65 minutes.
- **Complication:** `MAINTENANCE LOCK // MEDICAL SUBLEVEL`.

| Choice | Availability | Credits | Heat | Other effect |
|---|---|---:|---:|---|
| Request clinic override | Always | +3,200 CR | +0 | None |
| Use maintenance bypass | Always | +3,500 CR | +2 | None |
| Settle Mara's favor // Hand delivery | Only when favor owed | +2,600 CR | +0 | Clears `mara_favor_owed` |
| Abort recovery | Always | +0 CR | +0 | Failed |

Hand Delivery deliberately pays less than ordinary return. It must be absent when no favor is owed and must disappear permanently after clearing that Boolean. Do not add a debt, reputation, contact, favor, relationship, or dialogue system.

## Required Ownership

| Owner | Owns | Must not own |
|---|---|---|
| `data/contracts/contract_catalog.gd` | Fresh static authored dictionaries and authored player-visible copy | Mutable state or singleton behavior |
| `GameState` | Runtime records, active ID, time/Credits/Heat/favor effects, availability transitions, conditional filtering/validation, ticker and message emission | Panel layout or transient selected UI state |
| `ContractsPanel` | Existing selectable/disabled network-row rendering | Contract rules or mutations |
| `ContractDetail` | Existing phase rendering and intent-only controls for the supplied snapshot | Condition evaluation, effect calculation, state mutation |
| `Main` | Existing selected ID/context placement and refresh after `contracts_changed` | Contract rules, conditions, or state machine |
| `CommsPanel` | Existing flat rendering of `GameState.messages` | Dialogue or live-chat behavior |

Continue injecting `GameState` through `setup()`. No component may access the autoload singleton by its global name.

## Exact Implementation Rules

1. Add complete catalog fields to every playable contract: `code`, `proceed_label`, `accept_message`, `proceed_message`, and a complication object.
2. Every terminal choice carries exact `preview`, `result`, `ticker`, `message_sender`, and `message_preview` fields. A choice may carry only the optional fields needed here: `max_heat`, `min_heat`, `requires_mara_favor`, `sets_mara_favor_owed`, `clears_mara_favor`, and `unlocks_contract_id`.
3. `GameState.get_contract(id)` must return a deep duplicate with `complication.choices` filtered to choices currently available at the present Heat/favor state.
4. `resolve_contract(id, choice_id)` must resolve only choices in that same filtered set. Invalid IDs, inactive contracts, wrong phases, and hidden choice IDs return `false` and leave all state unchanged.
5. Resolution must apply authored Credits/Heat deltas, set or clear `mara_favor_owed`, unlock the optional successor, make the record terminal, clear `active_contract_id`, emit `contracts_changed`, and emit that choice’s ticker/message feedback.
6. Replace C-1042’s choice-ID-specific feedback `match` with per-choice authored feedback. This is the smallest way to support three contracts. It is not a generalized event system.
7. Continue using generic accept feedback `CONTRACT ACCEPTED // <code>`; use catalog-provided Mara accept/proceed messages; use the complication title for the proceed ticker.
8. In `ContractDetail._render_ready()`, render `PROCEED TO ` plus `c.proceed_label`. Do not add condition logic to UI.
9. Do not modify `main.gd` production code. Its existing `contracts_changed` subscription and snapshot refresh should already coordinate unlocks and detail state; prove this through `test_main.gd`.

## Execute in This Exact Order

1. **Catalog:** write failing static-content test; author complete three-contract data; run `test_contract_catalog`; commit.
2. **GameState:** write failing availability/condition/outcome tests; implement filtered snapshot, hidden-choice validation, authored feedback, and successor unlocking; run `test_game_state`; commit.
3. **Detail UI:** write D-207/R-311 dynamic Proceed and filtered-choice tests; replace hard-coded Dock 17 label; run `test_contracts`; commit.
4. **Main integration:** extend `test_main.gd` through C-1042 abort → D-207 abort → R-311 abort; prove failure-path unlocks and the unchanged adjacent workspace; commit test-only coverage.
5. **Final verification:** correct README’s stale status/link text; run focused/full test suites and both required manual player paths; commit README.

Do not fold tasks, skip the red/green checks, change commit boundaries, or refactor unrelated systems.

## Test Commands

Every shell command uses `rtk`:

```powershell
rtk powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\run_test.ps1 test_contract_catalog
rtk powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\run_test.ps1 test_game_state
rtk powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\run_test.ps1 test_contracts
rtk powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\run_test.ps1 test_main
```

Use fresh `GameState` instances for every terminal-outcome assertion. Tests must establish:

- only C-1042 starts enabled;
- C-1042 and D-207 each unlock their successor after completion **and** failure;
- D-207 exposes spoof at Heat 2 but routed vendor ID at Heat 4;
- invoking a hidden option directly returns `false` with no mutation;
- R-311 Hand Delivery appears only after C-1042 Call Mara and clears the favor exactly once;
- exact Credits, Heat, terminal status, active-ID clearing, result text, ticker, and message feedback for every new choice;
- detail renders only filtered actions and uses catalog-provided Proceed labels;
- Main keeps Contract Network open while its adjacent detail transitions and terminal rows refresh.

Do not add test frameworks, fixtures, mocks, or test-only production paths.

## Manual Smoke Requirements

Use two fresh game launches:

1. **Heat path:** C-1042 → Bypass Inspection → D-207. Verify Routed Vendor ID is present, Spoof Credentials absent, `+3,550 CR` applies without new Heat, and R-311 unlocks.
2. **Mara path:** C-1042 → Call Mara → D-207 → Buy Clean Access Token → R-311. Verify Hand Delivery appears, yields `+2,600 CR`, clears the favor, and produces authored ticker/Comms feedback.

For both, confirm the detail panel remains adjacent to Contract Network; each terminal row disables; Acknowledge closes only detail; and no UI/layout interaction regresses.

## Explicitly Out of Scope

- Save/load, replay/reset controls, repeat jobs, or post-portfolio content.
- Real-time time advance, deadline expiry, clock controls, or further Heat consequences.
- RNG, procedural contracts, contract Resource hierarchy, event graph, quest scripting, manager, or new autoload.
- Combat, stealth movement, free-roam, map navigation, ship/crew/inventory systems, factions, economy, reputation, or galaxy map.
- Dialogue, message threads/read state, relationship meter, contact database, debt ledger, or favor system beyond the existing Boolean.
- HUD, rail, theme, environment, ticker, workspace layout, or full-screen UI changes.

## Deliverable Standard

Do not report completion until all focused tests and the full headless suite pass, and the two manual player paths above have been run in the actual Godot project. The final build must visibly update Credits, Heat, clock, ticker, Comms, Contract Network availability, and adjacent Contract Detail without runtime errors.
