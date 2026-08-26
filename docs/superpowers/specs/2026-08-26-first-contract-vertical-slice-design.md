# First Contract Vertical Slice

**Date:** 2026-08-26  
**Status:** Design approved; specification review pending

## Goal

Make the existing terminal shell playable through one complete, deterministic operator contract. The player takes the C-1042 cold-chain delivery, makes an operational decision at Customs, receives a success or failure result, sees Credits/Heat/time change, receives Mara/ticker feedback, and returns to Contract Network. The loop must take 5–10 minutes, retain the existing floating workspace style, and provide a small repeatable seam for a second handcrafted contract.

## Player Flow

1. The player opens **Contract Network** from the existing module rail.
2. The network lists C-1042 as available. The two existing non-C-1042 offers are visibly unavailable; the encrypted offer remains redacted and unavailable. None of those rows may appear to accept input or open a detail panel.
3. Selecting C-1042 opens the adjacent floating **Contract Detail** panel. It presents the offer, its deadline, and `[ ACCEPT ]` plus `[ CLOSE ]`.
4. `[ CLOSE ]` closes only Contract Detail. C-1042 remains available. There is no decline action and no `declined` contract state.
5. `[ ACCEPT ]` marks C-1042 active. The Network row changes to `ACTIVE`; the existing detail panel re-renders as an active brief with `[ PROCEED TO DOCK 17 ]`. The player remains in the Contract Network workspace.
6. `[ PROCEED TO DOCK 17 ]` advances the game clock by exactly **80 minutes**. Initial time is Day 14, 23:41; its exact result is **Day 15, 01:01**. The active detail panel immediately becomes the Customs interruption.
7. The player makes one Customs decision. Each outcome is deterministic and terminal.
8. The result state displays completion/failure and applied Credits/Heat deltas. `[ ACKNOWLEDGE ]` closes Contract Detail. Contract Network stays open and C-1042 is visibly disabled as `COMPLETED` or `FAILED`.
9. The player can open Comms to see Mara's minimal event messages. No reply, thread, read interaction, or dialogue scene is provided.

## UI States

### Contract Network

| Contract state | C-1042 row treatment | Interaction |
|---|---|---|
| `available` | `COLD-CHAIN DELIVERY` and `1,400 CR` | Selectable; opens Contract Detail. |
| `active` | Pinned or clearly marked `ACTIVE // COLD-CHAIN DELIVERY` | Selectable; reopens the active detail panel. |
| `completed` | `COMPLETED // COLD-CHAIN DELIVERY` | Disabled. |
| `failed` | `FAILED // COLD-CHAIN DELIVERY` | Disabled. |

The list remains a browser, not a mission-control screen. It may retain the current visual ordering except that an active C-1042 row must be unambiguous. Other placeholder offers render as unavailable, including an explicit disabled treatment such as `NETWORK OFFLINE`; they must not emit selection.

### Contract Detail

| Phase | Required content | Actions |
|---|---|---|
| `offer` | `CONTRACT // C-1042`, title, client, destination, `DEADLINE DAY 15 // 04:00`, risk, reward | `[ ACCEPT ]`, `[ CLOSE ]` |
| `ready_to_proceed` | `ACTIVE // C-1042`, destination, deadline, current active status | `[ PROCEED TO DOCK 17 ]`, `[ CLOSE ]` |
| `customs_hold` | `CUSTOMS HOLD // DOCK 17`, concise cargo/inspection explanation, consequence preview per choice | Pay fee, Call Mara, Bypass inspection, Abort delivery |
| `resolved` | `CONTRACT COMPLETE` or `CONTRACT FAILED`, final Credits delta, final Heat delta, one-line operational result | `[ ACKNOWLEDGE ]` |

Accept and subsequent state transitions re-render the existing adjacent detail panel in place. They do not open a full-screen screen, relocate the workspace, or require a modal.

## First Contract Content

### Offer

- **Code:** C-1042
- **Title:** COLD-CHAIN DELIVERY
- **Client:** Vesper Logistics
- **Destination:** Dock 17
- **Deadline:** Day 15 // 04:00
- **Risk:** Low
- **Payment:** 1,400 CR
- **Initial game time:** Day 14 // 23:41
- **Travel action:** `PROCEED TO DOCK 17`, exactly +80 minutes, resulting in Day 15 // 01:01

### Complication

At Dock 17, Customs flags the cold-chain crate for manual inspection. The detail panel exposes these deterministic choices:

| Choice | Result | Credits | Heat | Additional state |
|---|---|---:|---:|---|
| **Pay clearance fee — 250 CR** | Delivery completes normally. | +1,150 CR net | +0 | None |
| **Call Mara** | Mara clears the hold; delivery completes. | +1,400 CR | +0 | `mara_favor_owed = true` |
| **Bypass inspection** | Delivery completes but the bypass is recorded. | +1,400 CR | +2 | None |
| **Abort delivery** | Player exits the delivery before escalation. | +0 CR | +0 | Contract fails |

`Bypass inspection` is a genuine trade-off, not a hidden random failure: it gives the full reward but visibly increases Heat. `Abort delivery` is the rational low-risk exit and supplies the playable failed-contract branch. There is no RNG, deadline failure, probability system, heat threshold, or additional decision.

## State and Data Model

### Static catalog record

Keep the existing Dictionary-oriented content convention. Add one small static contract catalog, with an entry shaped like this:

```gdscript
{
    "id": &"cold_chain_delivery",
    "code": "C-1042",
    "title": "COLD-CHAIN DELIVERY",
    "client": "Vesper Logistics",
    "destination": "DOCK 17",
    "deadline_day": 15,
    "deadline_minute": 4 * 60,
    "risk": "LOW",
    "reward_credits": 1400,
    "proceed_minutes": 80,
    "complication": {
        "title": "CUSTOMS HOLD // DOCK 17",
        "body": "Cold-chain cargo flagged for manual inspection.",
        "choices": [
            {
                "id": &"pay_fee",
                "label": "PAY CLEARANCE FEE // 250 CR",
                "credit_delta": 1150,
                "heat_delta": 0,
                "terminal_status": &"completed",
            },
            {
                "id": &"call_mara",
                "label": "CALL MARA",
                "credit_delta": 1400,
                "heat_delta": 0,
                "terminal_status": &"completed",
                "sets_mara_favor_owed": true,
            },
            {
                "id": &"bypass",
                "label": "BYPASS INSPECTION",
                "credit_delta": 1400,
                "heat_delta": 2,
                "terminal_status": &"completed",
            },
            {
                "id": &"abort",
                "label": "ABORT DELIVERY",
                "credit_delta": 0,
                "heat_delta": 0,
                "terminal_status": &"failed",
            },
        ],
    },
}
```

This is authored contract content, not a generalized quest description language. A second handcrafted contract may add another record with this same small structure only after it needs the same flow.

### Runtime contract fields

`GameState` owns the current catalog records and mutates only these runtime fields:

- `status`: `available`, `active`, `completed`, or `failed`.
- `phase`: `offer`, `ready_to_proceed`, `customs_hold`, or `resolved`.
- `resolution_id`: empty until a terminal choice is made; then the selected choice ID.
- `active_contract_id`: the sole active contract ID, or empty when none exists.

There is at most one active contract. Accepted/completed/failed are contract statuses; selection is only transient `Main` UI state and must not be persisted in `GameState`.

### GameState additions

Add only the state needed by the slice:

- `contracts: Array[Dictionary]`
- `active_contract_id: StringName`
- `mara_favor_owed: bool = false`
- `messages: Array[Dictionary]`
- `contracts_changed`
- `messages_changed`

`messages` holds existing-style minimal records: `id`, `sender`, `preview`, and `unread`. GameState owns the mutable collection; any initial static messages are merely initialization data.

Expose intent-level operations that validate their required state and return `false` without mutation when called out of phase:

- `accept_contract(id: StringName) -> bool`
- `proceed_contract(id: StringName) -> bool`
- `resolve_contract(id: StringName, choice_id: StringName) -> bool`
- `add_message(sender: String, preview: String) -> void`

The state transitions are:

```text
available / offer
  --accept--> active / ready_to_proceed
  --proceed (+80 min)--> active / customs_hold
  --pay_fee | call_mara | bypass--> completed / resolved
  --abort--> failed / resolved
```

There is no `declined`, expired, cancelled, paused, or abandoned state.

## Architecture and Ownership

### GameState

`GameState` remains the single owner of persistent/current game state. It initializes the contract records and message list, validates transitions, advances the existing clock, changes Credits/Heat through existing methods, sets `mara_favor_owed` only for `call_mara`, emits `contracts_changed`, and creates ticker/message feedback.

For terminal resolution, `resolve_contract` applies exactly the chosen record's `credit_delta` and `heat_delta`, records the chosen `resolution_id`, sets terminal status/phase, clears `active_contract_id`, and emits the existing Credits/Heat signals only when their values change.

### Static contract catalog

Use one small replacement for `data/placeholder/placeholder_contracts.gd`, for example `data/contracts/contract_catalog.gd`. It returns fresh contract dictionaries so independent headless tests cannot share mutations. It is not an autoload, manager, scene, or Resource hierarchy.

### ContractsPanel

`ContractsPanel` renders a snapshot of the GameState contract records. It emits a selected **contract ID**, not a contract Dictionary. Available and active C-1042 rows are selectable. Unavailable placeholder rows and terminal C-1042 rows are disabled and must not emit selection.

### ContractDetail

`ContractDetail` receives the selected contract snapshot and renders strictly by `phase`. It emits only user intent:

- `accept_requested(contract_id)`
- `proceed_requested(contract_id)`
- `resolution_requested(contract_id, choice_id)`
- `close_requested()`
- `acknowledge_requested()`

It does not mutate GameState, advance the clock, calculate outcome deltas, enqueue messages, or interpret another module's state.

### Main

`Main` retains the currently selected contract ID only while the detail panel is open. It opens Contract Detail when Contract Network emits a selectable ID; connects detail intents to GameState operations; re-renders the existing list and detail after `contracts_changed`; and closes detail for Close and Acknowledge. After Acknowledge, Contract Network stays open. `Main` does not own contract rules or state transitions.

### CommsPanel and ticker

`CommsPanel` receives `GameState.messages` when opened. It does not need live refresh while already open for this slice. `GameState.add_message` emits `messages_changed` and uses the existing `push_ticker` path to announce `NEW MESSAGE // <SENDER>`. Contract event ticker lines remain direct world notifications.

## Event and Message Flow

All event feedback travels through existing GameState signals; no dialogue/event manager is introduced.

| Trigger | State change | Ticker | Mara message |
|---|---|---|---|
| Initial state | C-1042 is available | `NEW MESSAGE // MARA` | Points the player at the Vesper Logistics delivery. |
| Accept | C-1042 becomes active / ready | `CONTRACT ACCEPTED // C-1042` | `Keep it cold. Keep it boring.` |
| Proceed | Clock becomes Day 15 // 01:01; phase becomes Customs hold | `CUSTOMS HOLD // DOCK 17` | Customs is fishing for an excuse. |
| Pay fee | +1,150 CR; completed | `CONTRACT COMPLETE // +1,150 CR` | Paperwork cost less than a seizure. |
| Call Mara | +1,400 CR; completed; `mara_favor_owed = true` | `CONTRACT COMPLETE // +1,400 CR` | `You owe me one.` |
| Bypass | +1,400 CR; Heat +2; completed | `CONTRACT COMPLETE // +1,400 CR // HEAT +2` | The crate moved; so did their cameras. |
| Abort | failed; no Credits/Heat change | `CONTRACT FAILED // DELIVERY ABORTED` | Walking was cheaper than escalation. |

For each Mara message, GameState also pushes `NEW MESSAGE // MARA` through the ticker queue. The specific contract-status line and the new-message announcement may be adjacent ticker entries.

## Likely Affected Files

- `autoload/game_state.gd` — own contract/message runtime collections, signals, validation and transition operations, `mara_favor_owed`, event effects, and ticker/message integration.
- `data/placeholder/placeholder_contracts.gd` — remove as shell-only placeholder data.
- `data/contracts/contract_catalog.gd` — new static catalog containing C-1042 and the visibly unavailable placeholder offers.
- `scenes/modules/contracts/contracts_panel.gd` — render active/terminal/unavailable states, use disabled rows, and emit IDs.
- `scenes/modules/contracts/contract_detail.gd` — render offer/active/Customs/result phases and emit intent signals.
- `scenes/main/main.gd` — use GameState contract/message data, wire contract intent, retain selection while detail is open, and refresh panel snapshots without changing workspace layout.
- `scenes/modules/comms/comms_panel.gd` — no structural change required if `Main` supplies GameState messages; alter only if its current input contract must become typed/documented.
- `data/placeholder/placeholder_messages.gd` — retain only as initial seed data if useful; otherwise fold the existing seed records into GameState initialization and remove the placeholder provider.
- `tests/test_game_state.gd` — cover state-machine transitions, time rollover, deltas, Mara flag, messages, and invalid intents.
- `tests/test_contracts.gd` — cover list availability/selection behavior and all detail phases/intents.
- `tests/test_main.gd` — cover adjacent detail opening, accept/proceed/resolve wiring, list refresh, and Close/Acknowledge workspace behavior.

Do not change unrelated HUD, rail, environment, theme, workspace-collapse, or ticker rotation behavior.

## Focused Behavioral Tests

### GameState contract tests

1. Fresh state provides C-1042 as `available / offer`, no active ID, false `mara_favor_owed`, and initial Day 14 // 23:41.
2. Accepting C-1042 changes it to `active / ready_to_proceed`, sets `active_contract_id`, emits contract feedback, and does not alter time, Credits, or Heat.
3. Proceeding C-1042 advances exactly 80 minutes: Day 14 // 23:41 becomes Day 15 // 01:01, and phase becomes `customs_hold`.
4. Resolving `pay_fee` produces completed/resolved, Credits `START_CREDITS + 1150`, unchanged Heat, and no active ID.
5. Resolving `call_mara` produces completed/resolved, Credits `START_CREDITS + 1400`, unchanged Heat, `mara_favor_owed == true`, and a Mara message.
6. Resolving `bypass` produces completed/resolved, Credits `START_CREDITS + 1400`, Heat `START_HEAT + 2`, and no Mara favor.
7. Resolving `abort` produces failed/resolved with unchanged Credits and Heat.
8. Invalid transitions — proceeding before accept, resolving before Customs, accepting a terminal contract, or acting on a non-active contract — return false and do not mutate state.

Use fresh GameState instances for each terminal outcome to keep assertions isolated.

### Contract UI tests

1. C-1042's available row is enabled and emits only its ID.
2. Non-playable placeholder rows are visibly unavailable/disabled and emit nothing.
3. Active C-1042 is clearly marked and remains selectable; completed/failed C-1042 is disabled.
4. Offer detail contains `DAY 15 // 04:00`, Accept, and Close; it does not contain Decline.
5. Active detail exposes Proceed; Customs detail exposes all four deterministic choices; resolved detail exposes Acknowledge and exact supplied deltas/status.
6. Detail buttons emit intent signals without directly changing the GameState test fixture.

### Main integration tests

1. Selecting C-1042 opens Contract Detail alongside the unchanged Contract Network host.
2. Accept re-renders both panels as active without closing the context panel.
3. Proceed updates the displayed clock through the existing GameState signal and re-renders Customs choices.
4. A resolution refreshes the list to terminal status; Acknowledge closes only context and leaves Contract Network open.
5. Close on an offer/active detail closes only context and leaves the contract's runtime state unchanged.

### Manual smoke test

Run the Godot project at the reference viewport. Complete all four outcome paths from fresh runs. Confirm the adjacent panel layout, exact Day 14 → Day 15 rollover after Proceed, Credits/Heat HUD updates, disabled network rows, ticker queue feedback, and Mara messages in Comms.

## Implementation Phases

### 1. Catalog and state transitions

Create the small static catalog and move mutable contract/message data into GameState. Implement and test `accept_contract`, `proceed_contract`, `resolve_contract`, and `add_message`, including the exact 80-minute rollover and every terminal outcome. Verify the focused GameState tests before touching UI behavior.

### 2. Contract panel rendering and intent

Update Contract Network to render available, active, terminal, and unavailable rows; update Contract Detail for offer, active, Customs, and result phases. Add intent signals only. Verify Contract UI tests without Main coordination.

### 3. Workspace coordination

Wire Main to GameState transitions and ContractDetail intents. Preserve the adjacent context-host layout, update snapshots after state changes, supply GameState messages to Comms, and implement Close/Acknowledge behavior. Verify Main integration tests.

### 4. End-to-end smoke and cleanup

Run the complete headless suite, then exercise each outcome in the running Godot project. Remove superseded placeholder-contract references and any shell-only test assumptions. Do not refactor unrelated workspace/UI code.

## Explicit Non-Goals

- No generic quest, event-graph, scripting, dialogue, or procedural-contract system.
- No contract Resource inheritance, manager, additional autoload, or simulation engine.
- No real-time timer, clock-pause behavior, global time-advance control, RNG, deadline expiry, or Heat threshold logic.
- No contract state beyond `available`, `active`, `completed`, and `failed`; specifically no `declined`, cancelled, paused, abandoned, or expired status.
- No generalized Mara favor, contact, reputation, debt, or relationship system. `mara_favor_owed` remains one explicit boolean in GameState and is only surfaced narratively.
- No combat, ship navigation, inventory, crew, factions, economy, galaxy map, save-game architecture, or message reply/thread UI.
- No full-screen contract interface, workspace redesign, or unrelated UI refactor.
