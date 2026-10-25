# Partial Resolutions Design

## Goal

Make arriving dirty cost the player something other than a removed option. Today a contract resolves to `completed` or `failed`, and Heat either deletes an authored response (`max_heat`) or does nothing. This pass replaces the two hard Heat gates with an authored degraded outcome: the same response stays available, pays what it can still earn, and resolves as `partial`.

It also closes the hole those gates expose: preparation purchases have no Heat gate at all, so today a player at maximum Heat can still buy a fully clean, standing-earning result. Under this pass no route is immune to arriving dirty; what differs is which currency the route stood to gain, so that is the currency Heat takes.

The intent is that a resolved contract can cost something specific the player can point at, without adding a new simulation system, a saved field, or a profile migration. This specification describes future work, not implemented behavior. Review it before implementation planning.

## Gameplay

- A response may declare `partial_above_heat: N` plus a `partial` block describing its degraded form. Degradation fires when `heat > N`. That boundary is identical to the removed `max_heat` boundary (`max_heat: 3` meant "available at Heat 3 or lower"), so no existing availability changes when a gate is converted.
- `partial` is a terminal contract status alongside `completed` and `failed`. It is not a phase; the contract is resolved and cannot be resumed.
- A degraded resolution keeps the response's `heat_delta`, `mara_favor_delta`, and `unlocks_contract_ids`. Only Credits, contact standing, and the recorded text change. The job happened: successors publish exactly as they do on a clean completion.
- `max_heat` is removed from the catalog. `min_heat` stays where it is: it gates an authored alternative route (a costlier clean workaround), which is a different mechanic from penalizing arrival state.
- Degradation applies to every route, including paid preparation. A prepared route is already paid for and non-refundable, so its degraded form keeps its full payout and loses the contact standing instead. Charging credits twice for the same mistake would punish buying the thing that is for sale.
- The rule the player learns: arriving dirty costs you whichever thing the route was actually buying. A clean-looking route buys outcome quality; a paid route buys a clean arrival; a prepared route buys trust.
- Deadline proximity is deliberately not part of this pass. Proceeding too late already hard-fails at the cutoff, and the detail panel already warns `PROCEEDING WILL MISS THE DEADLINE`. A partial band next to that warning would make a failure message ambiguous. Revisit only if the Heat rule proves itself.
- No randomness. Degradation is derived from saved Heat, never rolled.

## Data shape

A degraded response carries two sibling keys:

```gdscript
{
    "id": &"spoof_credentials", "label": "SPOOF SERVICE CREDENTIALS",
    "credit_delta": 4200, "heat_delta": 0, "contact_standing_delta": 1,
    "terminal_status": &"completed",
    "partial_above_heat": 3,
    "partial": {
        "credit_delta": 3900,
        "contact_standing_delta": 0,
        "result": "SPOOF PARTIALLY ACCEPTED // SHARD RETRIEVED // AUDIT FLAG",
        "ticker": "CONTRACT PARTIAL // +3,900 CR",
        "message_preview": "You have the shard. The audit kept a copy of your credential.",
        "preview": "+3,900 CR // HEAT +0 // CONTRACT PARTIAL",
    },
}
```

`partial_above_heat` without `partial`, or `partial` without `partial_above_heat`, is a catalog error. The block may not contain `heat_delta`, `mara_favor_delta`, `unlocks_contract_ids`, `terminal_status`, or gates; those are inherited and not overridable in this pass. `partial.credit_delta` may equal the clean value — prepared routes keep their payout and degrade only in standing — but it may not exceed it.

## Content changes

Two responses currently hard-gate, and both convert:

- **D-207 Data Retrieval, `spoof_credentials`** (`max_heat: 3`): at Heat 4+ the response stays available and pays 3,900 CR instead of 4,200, gains no standing, and reports the audit flag. `buy_token` (3,800 CR, clean, no standing) and `routed_vendor_id` (3,550 CR, clean, `min_heat: 4`, standing +1) remain the authored ways to buy back a clean result. A dirty player therefore gains options rather than losing them, and the premium clean routes read as premium.
- **M-613 Silent Partner, `buy_silence`** (`max_heat: 5`): at Heat 6+ it pays 4,300 CR with no standing change, using the existing intermediary text and message. **`buy_intermediary_silence` is deleted** as a duplicate of that degraded form.

Two prepared routes gain a degraded form, both at `partial_above_heat: 6`, so they survive ELEVATED and WATCHED and break once heat exceeds the WATCHED threshold of 6:

- **D-207 `verified_work_order`** (preparation, 500 CR upfront): at Heat 7+ it pays the full 4,200 CR and gains no contact standing. Text states the cover held but earned no trust.
- **C-1042 Cold-Chain Delivery, `precleared_documents`** (preparation, 300 CR upfront): at Heat 7+ it pays the full 1,400 CR and gains no contact standing, on the same terms.

Neither prepared route's purchase cost, unlock requirement, or upfront-payment behavior changes; only the standing the resolution earns does.

Deleting `buy_intermediary_silence` changes one existing outcome label: at Heat 6+ M-613 currently records as `completed`, and will now record as `partial` for the same 4,300 CR and the same zero standing. This is intended — the player paid an intermediary and gained nothing, and the label should say so. The two prepared routes similarly relabel from `completed` to `partial` at Heat 7+. No other existing resolution changes status.

## Presentation

- The customs screen keeps rendering `choice.preview` with no new branch. `_available_choices()` resolves the degraded form into the snapshot it already returns, so the panel never learns about partial-ness.
- Preparation is the one exception: its preview line is computed by `_prepared_outcome_text()`, which derives the standing gain at render time. `get_contract()` marks each returned choice with a transient `partial_now: bool` and the panel reads that flag instead of recomputing `heat > threshold` itself, so the rule stays in `GameState`. When the flag is set, the preparation preview states the contact's standing is unchanged rather than showing `STANDING +1`, and the outcome line reads as partial. `partial_now` is runtime-only and never saved.
- A degraded preview must be truthful at click time. Heat cannot change while a contract is active: `go_to_ground()` and `rest_until_next_day()` both refuse when `active_contract_id != &""`, and no other path mutates Heat. A preview computed at render therefore remains accurate when the player commits.
- The resolved screen shows the degraded Credits and standing from the partial block, and titles the outcome `CONTRACT PARTIAL`. `completed` and `failed` keep their current titles.
- The contracts list row reads `PARTIAL // <title>` and stays non-selectable, instead of falling through to the available-row reward format.
- The dossier counts partial operations separately as `signature.partial` and lists them in the operations record with their response label. Lowering Heat afterwards does not rewrite the count.

## State and data flow

- `data/contracts/contract_catalog.gd` authors the four `partial` blocks and drops `buy_intermediary_silence`.
- `autoload/game_state.gd` gains `_effective_outcome(choice)` returning the credits, standing, `result`, `ticker`, `message_preview`, and `terminal_status` in force for the current Heat. `resolve_contract()` reads effects only from it. `_available_choices()` stops filtering `max_heat` and substitutes the degraded `preview` plus the `partial_now` flag when applicable. `dossier_snapshot()` includes `partial` in its resolved-operation scan and adds the `partial` counter. `_validate_contracts()` accepts `partial` as a valid status only when the recorded response has a `partial` block.
- Validation must not re-derive degradation from current Heat. Heat moves after resolution, and a saved outcome must never become invalid because the player later went to ground. The status is recorded once at resolution and then trusted.
- `get_contract()` substitutes the partial block's `credit_delta`, `contact_standing_delta`, and `result` into the recorded response when `status == partial`, both in the returned choices list and in `preparation.choice`. Resolved contracts are not filtered through `_available_choices()`, so without this the resolved screen would print the clean result text under a `CONTRACT PARTIAL` title.
- No profile field is added and `PROFILE_VERSION` stays 5. No migration is written: no existing save can contain a `partial` status, and every existing v5 save remains valid.
- Out of scope: new saved state, injuries or conditions, per-route status overrides, Heat overrides, deadline-driven degradation, randomness, new contracts, new contacts, and any change to `min_heat` routes, preparation purchase rules, favor, or deadline semantics.

## Verification

- Boundary: a converted response resolves clean at Heat equal to its threshold and partial one point above it.
- Effects: a degraded run pays the partial Credits, gains no standing, applies the response's `heat_delta`, and publishes the same successors as the clean run.
- Prepared routes: at Heat 7+ a purchased preparation still pays its full payout and gains no standing, its preview stated the standing loss before the player committed, and it is still not refunded if the job later fails. At Heat 6 and below it earns standing as it does today.
- Persistence: a profile saved with a `partial` status loads, re-validates, and still renders both its degraded numbers and its response label; a v5 profile without partial statuses is unaffected.
- Dossier: a partial operation appears in the operations record and increments `partial` without incrementing `clean` or `aggressive` in a way that contradicts its Heat delta.
- Truthful preview: `get_contract()` reports the degraded preview for a dirty arrival and the normal preview at or below the threshold, and reports `partial_now` only when degradation actually applies.
- Catalog: no `max_heat` keys remain, `buy_intermediary_silence` is absent, every `partial` block has a matching threshold, and no `partial.credit_delta` exceeds its clean value.
- Manual: play D-207 at Heat 3 and Heat 4, M-613 at Heat 5 and Heat 6, and a prepared D-207 or C-1042 at Heat 6 and Heat 7, confirming button availability, previews, resolved screen, and dossier rows on the real contract detail surface.
