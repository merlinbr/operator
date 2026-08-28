# Luna Handoff: Persistent Housing System

## Start Here

Read the approved design first:

`docs/superpowers/specs/2026-08-29-persistent-housing-system-design.md`

Implement the ordered plan second:

`docs/superpowers/plans/2026-08-29-persistent-housing-system.md`

The plan is authoritative for task order, exact methods, tests, commands, and commit boundaries. Do not edit source until the required Tier-2 artwork exists.

## Blocking Asset Prerequisite

Provide exactly one new image before environment work:

```text
res://assets/tier-2-apartment.png
```

It must be 16:9 and preserve the Tier-1 image's painted-window composition. The existing normalized window/rain/glint/lightning calibration must remain valid; no fallback art or recalibration system is allowed.

## Goal

Turn housing into manageable survival progression:

```text
explicit REST or contract travel advances calendar
→ lease rent becomes due every 30 days
→ player pays, recovers from overdue rent, moves, or optionally buys out Studio
→ state persists across restart
```

There is no real-time clock, daily contract quota, eviction, interest, debt collection, financing implementation, equipment system, audio change, or property market.

## Exact Economy

| Residence | Rent | Entry | Ownership |
|---|---:|---:|---|
| Lower Vesper Studio | 2,000 CR / 30 days | Starting tenant; first due Day 30 | Optional 150,000 CR buyout only while resident. |
| Sector 9 Loft | 6,000 CR / 30 days | 8,000 CR, first term plus relocation | Rental only. |

The Studio buyout is optional, removes only Studio rent, and grants no contract/Heat/combat/equipment bonus. Loft is a lifestyle choice with higher ongoing cost, not a hidden mechanical buff.

## Required State and Interface

GameState owns all mutation and validation. Add:

```gdscript
var current_residence_id: StringName = &"lower_vesper_studio"
var owned_residence_ids: Array[StringName] = []
var next_rent_due_day := 30
var rent_due_amount := 0
var rent_status: StringName = &"current"

func rest_until_next_day() -> bool
func pay_rent() -> bool
func move_to_residence(id: StringName) -> bool
func buy_out_current_residence() -> bool
```

Add semantic calendar/residence/rent signals. Successful mutations save and notify; rejected calls return `false` without changes, ticker/Comms, or save writes.

## Time and Recovery Rules

- `REST // ADVANCE TO DAY <n>` appears only with no active contract; it sets next day at 00:00.
- Contract travel continues advancing authored durations; all time paths settle every crossed due date.
- Sufficient funds auto-pay rent. Insufficient funds create exactly one due bill.
- Three days later it becomes overdue. Work remains available forever.
- `PAY RENT` clears the one bill and schedules the next payment 30 days from payment.
- Due/overdue blocks moves and buyouts only. No duplicate bills, interest, eviction, or unrecoverable save.
- Return from Loft to Studio only when rent is current. An owned Studio is rent-free; otherwise the return begins a new Studio lease.

## Persistence

Persist all existing mutable operator state plus housing state in `user://operator_save.json` after every successful mutation. Write temporary JSON then replace the profile. Missing profile starts clean. Malformed/incompatible profile reports one actionable error and starts clean; boot must remain usable.

## UI and Environment Ownership

| File | Owns | Must not own |
|---|---|---|
| `data/housing/residence_catalog.gd` | Static two-residence records. | Runtime state. |
| `autoload/game_state.gd` | Clock/rent/move/buy validation, profile I/O, signals, notifications. | UI calculations or environment textures. |
| `scenes/modules/home/home_panel.gd` | Residence status and intent-only REST/pay/move/buy controls with exact-cost confirmation. | Credit/time/rent mutation. |
| `scenes/main/main.gd` | Wires Home intents to GameState and refreshes visible panels. | Housing rules. |
| `scenes/main/environment.gd` | Switches only `ApartmentBackground.texture` on residence change. | Workspace/effect/layout refactor. |

Keep rain, glints, lightning, time profiles, `EnvironmentLayer` ordering, and mouse-ignore rules unchanged.

## Execute in Exact Order

1. Write failing persistence/catalog tests; add catalog, GameState fields, JSON save/load/recovery; run `test_persistence`; commit.
2. Write failing REST/rent/move/buy tests; centralize calendar settlement in GameState and add the four intent methods; run `test_game_state`; commit.
3. Write failing Home control tests; implement intent-only Residence UI and Main wiring; run `test_panels_basic`; commit.
4. Write failing Studio/Loft environment tests; add texture swap only; run `test_environment` and `test_main`; run complete suite and manual smoke; commit.

Every command uses `rtk`. Do not combine tasks or skip red/green checks.

## Verification

Tests must prove fresh Studio state, active-contract REST rejection, next-midnight REST, multi-day rent settlement, auto-pay, due→overdue→paid recovery, exact move/buy costs, blocked housing actions with rent debt, persistence/recovery, intent-only UI, and texture-only environment swaps.

Manual smoke: REST, current/due/overdue rent, payment recovery, Loft move, Studio buyout, restart persistence, corrupt-save recovery, and both apartment images. Do not report completion until all focused tests and the complete headless suite pass.

## Deferred Financing

Do not implement a loan. A later fixed-loan extension must explicitly define down payment, principal, installment cadence/amount, total cost, early payoff, one grace period, and recovery to Studio lease. No credit score, random lender, refinance, rate market, or generic finance engine.
