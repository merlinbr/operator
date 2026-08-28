# Persistent Housing System

**Date:** 2026-08-29  
**Status:** Design approved; specification self-review passed; user review pending  
**Scope:** Add persistent time, leases, rent, one optional studio buyout, and one better rental residence.

## Goal

Make housing a manageable survival choice rather than a cosmetic purchase. The player can keep a low-cost studio, rent a visibly better Loft at higher recurring cost, or optionally buy out the studio to eliminate its rent. Credits therefore compete among cash reserves, better living space, and ownership; the starter buyout is deliberately not the primary win condition.

## Residence Catalog

Authored residence data is static. Mutable lease/ownership data belongs only in GameState.

| ID | Residence | Artwork | Monthly rent | Move-in cost | Ownership |
|---|---|---|---:|---:|---|
| `lower_vesper_studio` | Lower Vesper Studio | Existing `tier-1-appartment.png` | 2,000 CR / 30 days | None for the starting lease | Optional 150,000 CR buyout while resident. |
| `sector_9_loft` | Sector 9 Loft | Supplied `tier-2-appartment-update.png` | 6,000 CR / 30 days | 8,000 CR, covering the first 30-day term and relocation | Rental only. |

The Loft artwork is 16:9 and is the visible Tier-2 reward. It uses a separately calibrated environment-art profile: its window, spill, glint, and lightning rectangles are authored against this artwork rather than reusing Tier 1's coordinates. Its intended reward is a visibly better life, not a contract, combat, or Heat modifier. A later equipment system may make residence space mechanically useful; this scope creates no unused capacity counters or equipment rules.

The player begins as the Studio's tenant on Day 14 with the first studio payment due on Day 30. The initial studio move-in cost is historical and is not deducted from starting Credits.

## Time and Rent

### Time advancement

Time never passes while reading, selecting terminal UI, or remaining idle. It advances only through authored contract travel/operations and an explicit Home action:

```text
REST // ADVANCE TO DAY <current day + 1>
```

`REST` is available only when no contract is active. It advances to 00:00 on the following calendar day. There is no daily contract quota: multiple short contracts may fit in one day, while any authored contract duration may cross one or more days.

All paths that advance time process every crossed rent due date. Declining to rest leaves the calendar unchanged, but also leaves future calendar content unchanged; it is not a passive-rent exploit.

### Rent lifecycle

A leased current residence has one `next_rent_due_day` every 30 days.

1. On the due day, if Credits cover the rent, deduct it automatically, issue ticker/Comms feedback, and set the next due day 30 days later.
2. If Credits do not cover it, record one `rent_due_amount` equal to that period's rent and set `rent_status = due`. Do not create another bill or interest while that bill remains unpaid.
3. Three calendar days after the unpaid due date, set `rent_status = overdue` and issue a stronger warning. Existing work remains available.
4. `PAY RENT` is available from Home whenever the player has sufficient Credits. It deducts the single due amount, clears the status, and schedules the next payment 30 days after payment.
5. A due or overdue bill blocks moving and buyouts, but never accepting, proceeding, resolving, or collecting payment from contracts. There is no eviction, interest, credit score, debt collection, or unrecoverable save.

Owned residences never create rent bills. Moving from the Loft to the Studio is allowed when rent is current. If the Studio is owned, moving back creates no rent; otherwise it starts a new 30-day studio lease. The player may own the Studio and later rent the Loft; current residence determines the displayed artwork and any current rent.

## Player Flow

1. Home displays a compact `RESIDENCE` block with current residence, `LEASED` or `OWNED`, monthly rent or `RENT FREE`, and next due date or bill state.
2. With no active contract, the player may select `REST // ADVANCE TO DAY <n>`.
3. At a rent date the game automatically pays when possible, or shows `RENT DUE // <amount> CR`. After three days it shows `RENT OVERDUE`.
4. Once rent is current and Credits are at least 8,000, Home offers a two-step-confirmed move to the Loft. The payment is deducted, the current residence changes, and the Loft's first rent date is Day +30.
5. While leasing the Studio, the player may two-step-confirm its 150,000 CR buyout if rent is current and funds are sufficient. It becomes owned and never bills rent.
6. From a current Loft with rent current, the player may return to the Studio. This is a safe downsize path rather than a financial trap.

Every accepted rest, automatic rent payment, due/overdue transition, rent payment, move, and buyout appends concise existing-style ticker and Comms feedback. Invalid buttons never mutate state or produce feedback.

## State, Persistence, and Ownership

GameState remains the single owner and validator of mutable state. Add only:

```gdscript
var current_residence_id: StringName = &"lower_vesper_studio"
var owned_residence_ids: Array[StringName] = []
var next_rent_due_day := 30
var rent_due_amount := 0
var rent_status: StringName = &"current" # current, due, overdue
```

Expose intent-level methods returning `bool` without mutation on invalid calls:

```gdscript
func rest_until_next_day() -> bool
func pay_rent() -> bool
func move_to_residence(id: StringName) -> bool
func buy_out_current_residence() -> bool
```

Add semantic signals for calendar, residence, and rent changes; UI observes these signals and never calculates bills or subtracts Credits.

Persist the complete operator state—existing Credits, clock, contracts, favor, messages, housing state, and future compatible fields—to one `user://operator_save.json` profile after every successful gameplay mutation. Save through a temporary file then replace the main file so a partial write cannot destroy the profile. A missing file initializes the authored starting state. An unreadable, malformed, or incompatible file reports one actionable error and starts a clean state; it must never block boot.

## UI and Environment

- Append the `RESIDENCE` block and contextual actions to Home without changing the existing workspace shell.
- New move and buy actions require a confirmation state showing exact Credits, current rent, and resulting rent before the irreversible deduction.
- Environment receives the current residence snapshot through its existing injected GameState dependency. It swaps only `ApartmentBackground.texture` on `residence_changed`.
- Window rain, spill, glints, lightning, time profiles, layering, layout calibration, and pointer-ignore behavior remain unchanged.
- The supplied Tier-2 art is a required asset; no procedural substitute or visual fallback is added.

## Error Handling and Invariants

- At most one contract is active; REST and residence changes reject while one is active.
- Rent advances only from actual calendar progression and is processed for every crossed due day.
- There is at most one unpaid rent bill; no interest or duplicate charge accrues.
- A current/overdue lease can never prevent contract work or income.
- A residence can be bought once only; rental-only residences cannot be bought.
- A player cannot move or buy while rent is due/overdue, with insufficient Credits, or to the current residence.
- Loading never accepts malformed IDs, negative money, invalid statuses, impossible ownership, or invalid contract state. Invalid persisted fields fall back to the authored clean-state value and report the corrupt profile once.
- UI actions emit intent only. GameState owns validation, deductions, save writes, notifications, and signals.

## Tests

Add focused behavioral coverage:

1. A fresh profile starts in the Studio with Day 30 rent, current status, and no ownership.
2. REST rejects during an active contract and otherwise moves exactly to next-day 00:00.
3. Short and multi-day contract travel process every crossed due date without a daily contract cap.
4. Sufficient funds auto-pay exact rent; insufficient funds create one due bill; the same bill becomes overdue after three days; paying it clears the bill and schedules 30 days from payment.
5. Due/overdue rent still permits contract work but blocks move/buy; current rent restores those actions.
6. Loft move deducts exactly 8,000 CR, sets the current residence and its new due date, and rejects invalid/repeated/underfunded moves.
7. Studio buyout deducts exactly 150,000 CR once, records ownership, and prevents future studio rent; rental-only Loft buyout rejects.
8. Moving from Loft back to Studio works only with current rent and restores the correct lease/owned state.
9. Save/load preserves contracts, clock, Credits, messages, housing fields, and terminal contract states. Missing/corrupt save recovery produces clean playable state.
10. Home renders all contextual residence states and emits only intents. Environment switches the background texture without changing workspace layering or effects.
11. The complete headless suite and manual player smoke cover rest, automatic/current/due/overdue rent, payment recovery, Loft move, Studio buyout, save reload, corrupt-save recovery, and both apartment artworks.

## Deferred Financing Extension

Financing is intentionally not implemented now. The next housing-economy extension may offer the Studio buyout as one deterministic fixed loan. It must define a fixed down payment, principal, installment amount and cadence, total cost, early payoff, one grace period, and a recovery path back to the Studio lease. It must not add credit scoring, random approval, refinance products, interest-rate markets, or a generic financial simulation.

## Explicit Non-Goals

- No AudioManager, audio changes, music, or overlap with Luna's terminal-audio work.
- No equipment, inventory, combat, Heat reduction, contract buffs, extra contract slots, or residence-capacity mechanics.
- No eviction, interest, debt collection, foreclosure, credit score, randomized lenders, financing implementation, property resale, or multi-property market.
- No real-time clock, free-roam, daily contract cap, procedural calendar simulation, or deadline rewrite beyond future authored content.
- No additional residences beyond the Studio and Loft, no art fallback, no workspace redesign, and no unrelated environment refactor.
