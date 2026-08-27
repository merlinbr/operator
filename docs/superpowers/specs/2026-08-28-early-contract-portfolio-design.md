# Early Contract Portfolio

**Date:** 2026-08-28  
**Status:** Design approved; specification review pending  
**Scope:** Expand the early-game Contract Network from one completed vertical slice to a linear three-contract portfolio.

## Goal

Make the opening game feel like a small operator career rather than a single demo. Retain the completed C-1042 cold-chain delivery and add two deterministic authored contracts: D-207 Data Retrieval and R-311 Clinic Asset Recovery.

The player completes a linear early portfolio:

```text
C-1042 resolves → D-207 unlocks
D-207 resolves → R-311 unlocks
R-311 resolves → early portfolio complete
```

Every contract remains playable after success or failure of the prior contract. The portfolio must make the existing Heat and `mara_favor_owed` state mechanically meaningful without adding a reputation, faction, contact, debt, dialogue, quest, event-graph, or simulation system.

## Player Flow

1. C-1042 begins as the sole enabled Contract Network row. Its existing offer, travel, Customs decision, and terminal result remain unchanged.
2. Resolving C-1042 enables D-207, whether C-1042 completed or failed.
3. The player selects D-207, accepts it, proceeds to Sector 9, and resolves the remote-audit complication.
4. D-207 offers a quiet credential spoof only at Heat below 4. At Heat 4 or above, it instead offers a more expensive routed vendor ID. The player sees the applicable option before choosing.
5. Resolving D-207 enables R-311, whether D-207 completed or failed.
6. The player selects R-311, accepts it, proceeds to the clinic sublevel, and resolves the diagnostic-drone recovery.
7. If `mara_favor_owed` is true, the R-311 detail offers a lower-paying hand-delivery result that clears the favor. Otherwise, it is absent.
8. All terminal states retain the current behavior: exact Credits/Heat result, authored operational result, ticker notification, Comms message, disabled terminal row, and an Acknowledge action that closes only the detail context.

The early portfolio completes after R-311 resolves. No reset control, repeat contracts, free-roam clock, or post-portfolio progression is added in this scope.

## Contract Content

### C-1042 — Cold-chain Delivery

Existing implementation. It remains the first contract and unlocks D-207 after any terminal resolution.

- **Code:** C-1042
- **Client:** Vesper Logistics
- **Destination:** Dock 17
- **Reward:** 1,400 CR
- **Existing cross-contract effect:** `CALL MARA` sets `mara_favor_owed = true`; `BYPASS INSPECTION` raises Heat to 4.

### D-207 — Data Retrieval

A discreet transit-controller-shard pickup, not a combat mission.

- **Code:** D-207
- **Title:** DATA RETRIEVAL
- **Client:** Northline Systems
- **Destination:** Sector 9 // Transit Exchange
- **Risk:** Elevated
- **Reward:** 4,200 CR
- **Deadline:** Day 15 // 07:00
- **Travel:** `PROCEED TO TRANSIT EXCHANGE`, exactly 55 minutes.
- **Complication:** `REMOTE AUDIT // TRANSIT EXCHANGE` — the abandoned service kiosk holding the shard is under corporate audit.

| Choice | Available when | Credits | Heat | Terminal result |
|---|---|---:|---:|---|
| Spoof service credentials | Heat below 4 | +4,200 | +0 | Quiet shard retrieval. |
| Buy clean access token // 400 CR | Always | +3,800 | +0 | Audited access purchased. |
| Force kiosk readout | Always | +4,200 | +1 | Shard retrieved; audit recorded. |
| Use routed vendor ID // 650 CR | Heat 4 or above | +3,550 | +0 | Safe alternate identity purchased. |
| Abort retrieval | Always | +0 | +0 | Contract failed. |

The quiet credential route and routed-vendor route are mutually exclusive. They are a visible substitution, not a disabled control or random branch. Resolving D-207 unlocks R-311 regardless of the outcome.

### R-311 — Clinic Asset Recovery

A controlled recovery job with no combat: retrieve a diverted diagnostic drone from a locked maintenance sublevel.

- **Code:** R-311
- **Title:** CLINIC ASSET RECOVERY
- **Client:** Vesper Community Clinic
- **Destination:** Lower Vesper // Medical Sublevel
- **Risk:** Moderate
- **Reward:** 3,200 CR
- **Deadline:** Day 15 // 12:00
- **Travel:** `PROCEED TO MEDICAL SUBLEVEL`, exactly 65 minutes.
- **Complication:** `MAINTENANCE LOCK // MEDICAL SUBLEVEL` — the drone is accessible only through a contractor security lock.

| Choice | Available when | Credits | Heat | Additional effect | Terminal result |
|---|---|---:|---:|---|---|
| Request clinic override | Always | +3,200 | +0 | None | Drone returned normally. |
| Use maintenance bypass | Always | +3,500 | +2 | None | Drone returned; security event recorded. |
| Settle Mara's favor // Hand delivery | `mara_favor_owed` | +2,600 | +0 | Clear `mara_favor_owed` | Favor settled through direct return. |
| Abort recovery | Always | +0 | +0 | None | Contract failed. |

Hand Delivery is deliberately less profitable than the normal return. It makes the existing favor flag a real decision without preventing content, adding a relationship system, or requiring repayment immediately.

## State and Data Model

Continue to use the current authored Dictionary catalog and GameState-owned mutable runtime records.

### Contract availability

Reuse the existing `is_playable` field as the small availability gate:

- C-1042 starts `true`.
- D-207 and R-311 start `false` and render `NETWORK OFFLINE`.
- Resolving C-1042 sets D-207 `is_playable = true`.
- Resolving D-207 sets R-311 `is_playable = true`.

`status`, `phase`, `resolution_id`, and single `active_contract_id` retain their existing meanings. Failed jobs still unlock their successor so the early portfolio cannot dead-end.

### Choice fields

Extend only authored choice records with optional fields already needed by the three contracts:

```gdscript
{
    "id": &"spoof_credentials",
    "label": "SPOOF SERVICE CREDENTIALS",
    "credit_delta": 4200,
    "heat_delta": 0,
    "terminal_status": &"completed",
    "max_heat": 3,                   # optional
    "requires_mara_favor": true,     # optional
    "clears_mara_favor": true,       # optional
    "unlocks_contract_id": &"r_311", # optional
    "preview": "+4,200 CR // HEAT +0 // CONTRACT COMPLETE",
    "result": "SERVICE CREDENTIALS SPOOFED // SHARD RETRIEVED",
    "ticker": "CONTRACT COMPLETE // +4,200 CR",
    "message_sender": "MARA",
    "message_preview": "Clean work. Northline will not see your name."
}
```

The actual catalog uses only the applicable optional fields. No generic effects language, condition evaluator, resource hierarchy, manager, autoload, or quest system is introduced.

### GameState rules

`GameState` remains the only owner and validator of mutable gameplay state.

- `get_contract(id)` returns a deep snapshot whose complication list includes only currently available choices.
- `resolve_contract(id, choice_id)` validates against that same available-choice set. A hidden conditional choice returns `false` without state mutation if invoked directly.
- Resolution applies the authored Credits/Heat delta, favor set/clear effect, contract status/phase/resolution ID, active-ID clearing, successor unlock, contract signal, ticker text, and message.
- Resolution feedback moves from C-1042's choice-ID `match` to authored per-choice feedback fields. This is necessary to support three authored contracts; it is not a generalized scripting system.
- Existing C-1042 content receives the same fields and continues to produce its current visible results.

## UI and Ownership

- **Contract Network:** unchanged architecture. `is_playable == false` produces the existing disabled `NETWORK OFFLINE` presentation. Active records remain selectable; terminal records remain disabled.
- **Contract Detail:** unchanged phase-based, intent-only design. It renders only the snapshot’s available choices, so the Heat and Mara consequences appear as ordinary authored controls.
- **Main:** unchanged workspace coordination. `contracts_changed` refreshes the network and the selected adjacent detail after an unlock or terminal resolution.
- **Comms/Ticker:** retain the current flat messages and queued ticker behavior. Each accepted, proceeded, and resolved contract receives one concise authored message and appropriate ticker entry.

## Error Handling and Invariants

- Only one active contract may exist.
- Invalid contract IDs, inactive contracts, out-of-phase actions, invalid choice IDs, and hidden conditional choices return `false` without changing state.
- A failure unlocks the next job exactly like a completion.
- The mutually exclusive D-207 identity choices must never appear together.
- Hand Delivery appears only while a favor is owed; selecting it clears the flag once and cannot reappear afterward.
- All UI controls continue to emit intent only; they do not mutate GameState or calculate outcomes.

## Tests

Extend focused behavioral coverage rather than adding a framework:

1. Fresh state exposes only C-1042; D-207 and R-311 render disabled and unavailable.
2. Resolving C-1042 through both completed and failed paths unlocks D-207.
3. Resolving D-207 through both completed and failed paths unlocks R-311.
4. At Heat 2, D-207 exposes Spoof Service Credentials and hides Routed Vendor ID.
5. At Heat 4, D-207 exposes Routed Vendor ID and hides Spoof Service Credentials; attempting the hidden choice directly fails without mutation.
6. Every D-207 and R-311 option has exact Credits, Heat, terminal status, result, ticker, message, and active-ID assertions.
7. R-311 Hand Delivery appears only when C-1042's Call Mara set the favor; it clears the flag on resolution.
8. Contract UI tests prove only visible choices render and emit their IDs without mutating state.
9. Main integration tests prove sequential unlock refresh, terminal disabled rows, and the existing adjacent context behavior.
10. Full headless suite and a manual player smoke through both Heat variants and both Mara-favor variants pass before delivery.

## Explicit Non-Goals

- No combat, stealth movement, maps, free-roam, or direct action gameplay.
- No procedural contract generation, reusable quest engine, graph, script interpreter, or probability system.
- No real-time time advance, deadline expiry, clock controls, or Heat threshold consequences beyond D-207's authored identity route.
- No reputation, faction standing, contact database, relationship meter, debt ledger, dialogue system, message threading, or Comms read state.
- No saving/loading, replay/reset control, repeat jobs, or post-portfolio content.
- No unrelated environment, HUD, workspace, or theme refactor.
