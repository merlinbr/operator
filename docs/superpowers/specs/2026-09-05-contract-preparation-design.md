# Contract Preparation Design

## Goal and status

Add optional, reliable, Credits-only preparation that unlocks a situational alternative to an existing contract's basic responses. Preparation must not become a routine purchase for a strictly better payout.

The user approved the purchase rules, additive outcomes, two-contract lineup, and 300/500 CR prices below. This document specifies future implementation; it does not claim the feature or its verification has run. Review this written specification before producing the implementation plan.

Implementation starts only after the contract-deadlines feature is complete. Its approved baseline is `docs/superpowers/specs/2026-09-05-contract-deadlines-design.md`. Re-read the finished source before writing implementation steps; the deadline agent was still editing shared files while this specification was prepared.

## Approved gameplay rules

- Preparation is optional and purchased after acceptance, before proceeding, in the existing `ready_to_proceed` view. No new phase, separate screen, or mandatory preparation step.
- At most one purchase per contract. Each of the two supported contracts has one authored preparation; the other five have none. No selection framework, inventory, or reusable equipment.
- The purchase succeeds deterministically when its preconditions hold. No random failure, retries, or attempt counters.
- Pay Credits upfront. Preparation consumes no game time, changes no travel duration, and never renews or extends a deadline.
- A purchase unlocks exactly one additional complication response. Existing responses retain their requirements, rewards, Heat, standing, favor effects, and successors.
- Buying preparation itself awards no standing, changes no Heat or favor state, and does not complete the contract. The player must later choose the prepared response to receive its outcome.
- The player may still select a basic response after buying preparation. Preparation is not automatically selected or refunded when unused.
- No switching, cancellation, or refunds. An abort or deadline failure retains the spent preparation cost. Purchases survive reload.
- A prepared response is guaranteed to be unlocked, not guaranteed to be reached: the active job can still miss its deadline during travel.
- Reputation in this slice means existing Contact standing only. No faction reputation, new Contacts, standing losses, or penalties added to basic responses. Existing Cold / Known / Trusted bounds and acceptance gates remain.
- Every preparation needs both a concrete useful-purchase situation and a sensible skip situation. Do not promise that a fixed percentage of players or playthroughs will skip it.

## Authored content

All amounts below are initial catalog balancing values, not constants embedded in purchase or scheduling code. Normal resolution `credit_delta` remains the amount credited at resolution; it must not subtract the preparation price a second time.

### Cold-Chain Delivery: independent clearance

- Contract: `cold_chain_delivery` / C-1042.
- Purchase label: `ARRANGE INDEPENDENT CLEARANCE // 300 CR`.
- Cost: **300 CR**.
- New response ID: `precleared_documents`.
- Response label: `SUBMIT PRE-CLEARED CARGO DOCUMENTS`.
- Preview explanation: independent clearance earns Mara's trust without asking her to intervene; it creates no new favor debt and does not settle an existing debt.
- Resolution: `completed`, **+1,400 CR**, **Heat +0**, **Mara standing +1**, capped at Trusted.
- Favor effects: neither set nor clear `mara_favor_owed`.
- Additional eligibility: purchased preparation only; no Heat or favor requirement.
- Successors: `data_retrieval`, `dead_drop_audit`, using ordinary successful-resolution publication.
- Result: `PRE-CLEARED DOCUMENTS ACCEPTED // CARGO RELEASED`.
- Ticker: `CONTRACT COMPLETE // +1,400 CR`.
- Message sender: `MARA`.
- Message preview: `You handled clearance without calling me in. I can trust that.`

| Existing or proposed response | Resolution Credits | Preparation cost | Net contract Credits | Heat gained | Mara standing gained | New favor debt |
|---|---:|---:|---:|---:|---:|---|
| Pay clearance fee | +1,150 | 0 | +1,150 | 0 | 0 | No |
| Call Mara | +1,400 | 0 | +1,400 | 0 | +1 | Yes |
| Bypass inspection | +1,400 | 0 | +1,400 | +2 | 0 | No |
| Prepared documents | +1,400 | 300 | +1,100 | 0 | +1 | No |

The comparison assumes preparation was not bought for the basic responses. If it was bought and unused, subtract its 300 CR from their net results too.

**Buy:** earn trust without creating a favor debt. **Skip:** Mara is already Trusted, the player accepts the favor obligation, or the player prefers the greater immediate Credits of a basic response. Ordinary clearance is 50 CR better financially than the prepared response but grants no standing.

### Data Retrieval: independent service cover

- Contract: `data_retrieval` / D-207.
- Purchase label: `ARRANGE INDEPENDENT SERVICE COVER // 500 CR`.
- Cost: **500 CR**.
- New response ID: `verified_work_order`.
- Response label: `PRESENT VERIFIED SUBCONTRACTOR WORK ORDER`.
- Preview explanation: verified service cover offers a quiet, trust-earning route even when Heat prevents spoofing; it does not lower existing Heat.
- Resolution: `completed`, **+4,200 CR**, **Heat +0**, **Mara standing +1**, capped at Trusted.
- Favor effects: neither set nor clear `mara_favor_owed`.
- Additional eligibility: purchased preparation only; no Heat or favor requirement.
- Successors: `silent_partner`, `clinic_asset_recovery`, using ordinary successful-resolution publication. Their standing gates remain unchanged.
- Result: `VERIFIED WORK ORDER ACCEPTED // SHARD RETRIEVED`.
- Ticker: `CONTRACT COMPLETE // +4,200 CR`.
- Message sender: `MARA`.
- Message preview: `The work order held. You kept the retrieval quiet without leaning on my vendor route.`

Net Credits after preparation: **+3,700 CR**.

| Situation | Decision supported by the existing alternatives |
|---|---|
| Heat 0-3 | Skip: `spoof_credentials` already gives +4,200 CR, Heat +0, and standing +1 without preparation. |
| Heat 4+, Mara below Trusted | Prepare for quiet standing gain: +3,700 CR net is 150 CR better than the existing `routed_vendor_id` outcome of +3,550 CR. |
| Heat 4+, Mara already Trusted | Skip: `buy_token` gives +3,800 CR and Heat +0; the extra standing cannot help. |
| Willing to gain Heat | Skip: `force_readout` retains +4,200 CR but adds Heat. |

The existing clean token and routed vendor responses are not renamed, moved into preparation, removed, or changed. Existing paid basic responses continue using their current resolution accounting; this feature adds an actual upfront payment only for preparation.

### Contracts without preparation

- `dead_drop_audit`, `clinic_asset_recovery`, `dialysis_relay`: each already has an unrestricted zero-Heat response that earns standing. Do not add a paid equivalent or weaken the existing response to justify preparation.
- `silent_partner`: requires Trusted Mara standing, so another standing reward would have no benefit. Do not make preparation a routine discount on its clean response.
- `quarantine_manifest`: requires Trusted Clinic standing and already offers full payout with no added Heat. Avoiding its audit has no separate implemented mechanical consequence; do not invent one here.

Do not render disabled preparation placeholders on these five jobs. Their existing ready-to-proceed flow remains unchanged.

## State ownership and interfaces

Keep authored content in `data/contracts/contract_catalog.gd`, authoritative purchases and filtering in `autoload/game_state.gd`, presentation in `scenes/modules/contracts/contract_detail.gd`, and action wiring in `scenes/main/main.gd`. Components continue receiving state through `setup()` injection.

### Catalog and runtime fields

- Supported contracts gain an authored `preparation` dictionary with `label`, `cost_credits`, and `choice_id` referencing the new authored complication response. Unsupported contracts omit it.
- The two new choices use `requires_prep: true`. Existing choices omit this flag and retain current behavior.
- Every runtime contract gains `prep_paid_credits: int`, initially **0**. A positive value means the preparation was purchased and records the actual price paid.
- Use that single integer for both purchase state and net-result accounting. No duplicate purchased boolean, global preparation map, inventory entry, or list of purchases.
- Keep the paid amount on terminal records, including abort and active deadline failure, so reload and result presentation retain sunk costs.
- Paid amounts are historical state. Catalog prices remain authoritative for new purchases; a later price change must not rewrite the amount already paid.
- Catalog integrity requires a positive integer cost and exactly one preparation-gated choice on each supported contract, matching `preparation.choice_id`. Unsupported contracts have no preparation-gated choices.
- `get_contract()` must also expose the referenced authored response as snapshot-only `preparation.choice` for the pre-purchase preview, before filtering `complication.choices`. Otherwise the unpurchased response would disappear from both the action list and its own purchase preview. This preview is not an available response, is not persisted as authority, and cannot bypass `resolve_contract()` validation. Derive it from the already-copied snapshot rather than creating a second authored outcome definition in the UI.

### Purchase action

Add `prepare_contract(id: StringName) -> bool` to `GameState`. It accepts no client-supplied price, response data, or reward data.

Accept only when all conditions hold:

1. The ID identifies the unique active contract (`active_contract_id == id`).
2. Status is `active`, phase is `ready_to_proceed`, and the existing authoritative deadline predicate says the deadline has not passed.
3. The contract has authored preparation and `prep_paid_credits == 0`.
4. Current Credits are at least the authored cost. Exact affordability is valid and may leave zero Credits.

A rejected request returns false without charges, time advancement, purchase feedback, save writes, or state changes. In particular, checking purchase availability does not settle deadlines as a side effect.

An accepted request records the paid cost and deducts it once. Establish purchase state before a Credits notification can re-enter the action; duplicate/re-entrant requests must see it as already purchased. Emit the existing contract refresh notification only after purchase and balance are coherent. Use existing Credits notifications for the HUD.

Publish a single existing-style ticker confirmation identifying the contract and amount spent. Do not emit accepted/proceeded/resolved semantic events or add preparation audio assets. Persist using the existing atomic profile path. Return true for an accepted in-memory action, as other contract actions do; if saving fails, retain the coherent in-memory purchase, report the existing save error, and do not claim disk persistence succeeded. Do not invent a new transaction or retry subsystem.

### Choice filtering and resolution

Extend `_available_choices()` with one additive condition: skip `requires_prep` choices when `prep_paid_credits == 0`. Retain existing Heat and favor filters. The new responses have no additional Heat or favor gates.

`resolve_contract()` continues selecting from authoritative available choices and enforcing active/customs/deadline guards. Directly requesting a prepared response without a purchase must fail. Neither UI-supplied snapshots nor a visible button confer eligibility.

At resolution, apply the authored outcome exactly once through the normal Credits, standing, feedback, and successor path. Do not deduct preparation again. Choosing a basic response does not reset or refund the paid amount. A purchased response remains renderable after terminal state and reload; resolving it does not erase its preparation state.

## Deadline integration

Do not modify the clock algorithm, authored deadline windows, proceed durations, REST restrictions, or publication rules.

- At `now >= deadline`, buying preparation is rejected even if an old UI button remains.
- A still-valid purchase is allowed when the existing late-arrival warning is visible. Keep the warning; preparation does not make that journey safe.
- If travel crosses the cutoff, preserve deadline failure and do not reveal complication responses, award standing, or refund preparation.
- Deadline settlement itself still changes no contract Credits, Heat, standing, or favors. The earlier preparation debit is separate and must not be described as a new deadline penalty.
- Reload of an overdue prepared active job uses existing reconciliation, retaining the purchase cost and resolving the job once.
- Successor publication never transfers a purchase to another contract. Each successor starts with its own zero paid amount.

## Player-facing presentation

### Before proceeding

On the existing ready screen, supported unprepared contracts show the purchase action and a concise preview containing:

- Upfront price, response unlocked, and the fact that the purchase consumes no time and is nonrefundable.
- Resolution payout and net contract Credits after preparation.
- Heat change and the Contact standing benefit; neither purchase grants standing immediately.
- No new favor debt and no settlement of existing debt for the two authored responses.

Use current injected Contact standing to display the effective gain. If Mara is already Trusted, explicitly say the standing gain is zero because trust is at its maximum. Do not advertise an effective +1 gain at the cap. This is information, not a purchase restriction.

Insufficient Credits disables the purchase action with a textual explanation. After purchase, replace the purchase action with a purchased/unlocked summary that includes the amount actually paid. Keep PROCEED and CLOSE. Do not add a separate SKIP step; proceeding without buying is the skip action.

Maintain the deadline feature's cutoff, duration, and late-arrival warning. Purchases must not rebuild the screen from stale pre-deadline markup.

### At the complication and result

Show the additional response only after purchase, alongside the existing available responses. Explain payout, Heat, effective standing gain, and net Credits without suggesting an additional preparation charge is due. Existing response IDs and their actual effects remain unchanged.

For a purchased job's result, distinguish:

- Credits awarded at resolution (zero for deadline failure).
- Preparation already paid, displayed as a historical cost, not another debit.
- Net contract Credits: the selected outcome's `credit_delta` minus `prep_paid_credits`; use zero outcome Credits for deadline failure.

Apply this accounting even when the player bought preparation but chose a basic response or aborted. For example, a delivery deadline failure after preparation shows 0 resolution Credits, 300 CR preparation spent, and -300 CR net. Housing payments are independent and not included in contract net totals.

Normal no-preparation result behavior stays intact. Keep the deadline-specific result branch ahead of authored-choice lookup. Main-scene wiring uses a purchase-request signal carrying the contract ID and the existing `contracts_changed` refresh path; panel refreshes must not replay purchase feedback or contract audio.

## Persistence and migration

The approved deadline baseline writes version-3 profiles. Preparation advances the profile to **version 4**, adding `prep_paid_credits` to every contract record.

- Versions 1 and 2 retain the existing contact and deadline migration stages. Keep each stage's output version explicit: 1 -> 2, 2 -> 3, then 3 -> 4. In particular, the current deadline migration's assignment to the global profile version must become an explicit version 3 when the global constant changes.
- Validate each legacy stage before using its data. The version-3-to-4 step sets every contract's paid amount to zero without touching Credits, clock, standing, favor state, statuses, resolutions, or deadline cutoffs.
- Legacy saves with active jobs at `ready_to_proceed` may buy preparation after migration. Legacy jobs already at the complication remain unprepared and cannot buy retroactively.
- Reject legacy records claiming one of the newly introduced prepared resolution IDs; those outcomes did not exist in versions 1-3.
- Persist a successful migration using existing atomic save handling. Preserve successfully loaded in-memory progress if that write fails and surface the save error. Ordinary version-4 reload does not migrate, debit again, or renew deadlines.
- Preserve all version-3 deadline validation and overdue-load reconciliation for version 4 as well; version comparisons must not accidentally make deadline checks version-3-only.
- Reconstruct authored preparation, choices, prices, rewards, and windows from the catalog. Restore only the paid amount with the existing mutable contract fields; never restore saved authored purchase definitions.

### Version-4 preparation validation

- `prep_paid_credits` is required on each record and must be an integer value >= 0, using existing JSON integer validation conventions. Reject missing, fractional, negative, string, and boolean values.
- A positive paid amount requires a supported, published contract with a nonnegative assigned deadline and status `active`, `completed`, or `failed`. Available/unaccepted, unpublished, unsupported, and `expired` records must have zero paid amount. Legacy terminal records may retain deadline -1 only while unprepared.
- Retain existing phase/status/active-ID validation. An active prepared job may be ready or at the complication; a failed prepared job may have an abort or deadline-missed resolution.
- A prepared resolution requires a positive paid amount and its authored completed outcome. A paid job may legitimately end with a basic resolution instead.
- Do not require a historical positive paid amount to equal today's catalog price. It is used for purchase state and historical display, never as a refund, payout, or future purchase price.
- Valid overdue active records with purchases must survive validation so the deadline reconciliation path can fail them without refunds or duplicate feedback.

## Verification and acceptance

Use existing SceneTree test conventions for uncertain behavioral edges. Run save-writing tests and runtime smoke scenarios only under a disposable project/user-data identity, following the deadline plan's safety approach. Do not run the hard-coded real-profile test wrapper unprotected.

The implementation must demonstrate:

1. Delivery purchase charges exactly 300 CR, leaves time/cutoff/standing/Heat/favor unchanged, and reveals only the new response while preserving basic eligibility. Resolution then yields +1,100 CR net, the capped standing gain, and no new or cleared debt.
2. Exact affordability succeeds; insufficient Credits, duplicate/re-entrant requests, unsupported jobs, wrong active IDs, departed jobs, and cutoff equality cannot charge or unlock anything.
3. Calling a prepared resolution directly without purchasing fails. Selecting a basic response after purchase works and retains the spent cost; selecting a prepared response does not charge twice.
4. Data Retrieval remains fully playable unprepared. At low Heat its free spoof response is financially better than preparation; at high Heat with uncapped Mara standing the prepared route earns standing without Heat and costs less than the existing routed-vendor response. At capped standing the clean token is cheaper. Use actual contract transitions or coherent state fixtures, not assertions about source text.
5. Purchase -> save -> reload preserves the paid amount and available response. Prepared completion, unused preparation, abort, and deadline failure retain correct accounting after reload. Paid state does not leak to successor contracts.
6. Version-3 migration preserves existing cutoffs and progress while setting preparation to zero. Versions 1 and 2 still traverse the deadline migration once, and a subsequent version-4 reload grants no extra window. Malformed preparation/state combinations follow existing candidate rejection and recovery behavior.
7. A purchase immediately before a late journey does not prevent deadline failure, grant outcome benefits, refund its cost, or expose stale complication buttons. Overdue-load reconciliation also retains sunk preparation costs and does not replay feedback.
8. The actual main scene shows cost/net/standing previews, insufficient-Credits text, purchased state, capped-standing explanation, correct basic and prepared choices, and deadline-result accounting. Test both a useful-purchase and a skip-is-better situation. Purchase refreshes do not replay accepted/proceeded/resolved audio.
9. The five unsupported contracts have no preparation controls and retain their existing outcomes. Existing deadline, persistence, normal resolution, housing, Contact, and UI checks remain valid.

Keep regression checks focused on observable gameplay, monetary boundaries, migration, and stale-action behavior. Use a disposable runtime smoke for presentation rather than adding wording snapshots. If graphical interaction is unavailable, exercise the actual main scene with a disposable driver and explicitly report that visual verification was not performed.

## Implementation sequence and non-goals

The later implementation plan should cover catalog/state/filtering, persistence migration, UI/action integration, and focused verification. Shared `GameState` edits must have one owner or be serialized. Do not implement against the deadline agent's partially migrated working tree.

After runtime proof, update the existing README, context, and roadmap to describe the implemented two-contract preparation scope and link this specification. Until then, leave those shared documents and all gameplay files to the deadline agent. Remove only disposable verification artifacts created for this feature, never the user's real profile.

Explicitly excluded: faction reputation, negative standing, new Contacts, favor ledgers, Heat consequences or decay, random preparation, retries, multiple purchases, refunds, inventory, equipment, preparation time costs, deadline changes, new phases, new contract publication paths, new audio assets, and mechanically empty preparation on the other five contracts.
