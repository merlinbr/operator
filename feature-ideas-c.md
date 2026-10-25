# Operator — Feature Recommendations (C)

Second recommendation set. Where `feature-ideas-a.md` proposes bread-and-butter systems (prep loadouts, roster, sweeps, intel), this set is ranked by **value-per-effort against the current build**: first make the pressure systems that already exist actually matter, then deepen the contract loop, then breadth.

Grounded facts about the current build (from `autoload/game_state.gd`, `data/contracts/contract_catalog.gd`):

- `deadline_day` / `deadline_minute` exist on every contract and are displayed by `contract_detail.gd` — but **nothing enforces them**. Clock advances only via `rest_until_next_day()` and `proceed_contract()`.
- `heat` only gates choice visibility in `_available_choices()` (via `max_heat` / `min_heat`) and displays in the HUD. There is no reason *not* to take Heat.
- `alerts` is persisted, has a change signal, shows in the status chip and home panel — and is **read nowhere else**.
- Rising heat, sweeps, and raid mechanics already appear in feature-ideas-a.md (#3); this document does not repeat them.

---

## 1. Enforce Contract Deadlines
*Converts a displayed stat into the game's cheapest tension engine.*

- **Mechanic:** A per-day check (extend `_settle_calendar_day()`) that scans contract records:
  - **Available offers** past their deadline → status `expired` (or reverts to unavailable), forcing the player to evaluate offers before resting.
  - **Active contract** past deadline → forced failure state with a "late resolution" penalty tier, or an authored late-completion branch.
- **Impact:** Resting and contract ordering become real decisions. The offer detail already shows `DEADLINE DAY %d // %02d:%02d` — the player currently has no reason to care.
- **Data model:** Uses existing `deadline_day` / `deadline_minute` fields with `day` / `minute_of_day` on GameState. No new content required to be meaningful; authored penalty tiers are a content addition.
- **Note:** Intentionally out of scope across all current plans (`2026-08-26-first-contract-vertical-slice.md` line 128, `2026-08-28-early-contract-portfolio-design.md` line 178). This is the highest-value first extension.

## 2. Heat Consequence Ladder & Decay
*Makes Heat a resource with a cost, not a flavor number.*

- **Mechanic:** Heat thresholds (e.g., 3, 6, 9) trigger escalating ambient consequences:
  - Threshold events broadcast over the existing ticker and surface as `messages`.
  - High Heat locks the clean choices of higher-tier contracts and raises the cost of paid escape routes.
  - Heat decays only through explicit actions: paying a "cleaner" fee, calling in a contact favor, or resting in a safe district.
- **Impact:** The `bypass`/`mirror_archive`/`force_readout` choices — currently strict upgrades — become genuine tradeoffs the player plans around. Doc a.md #3 covers the district-sweep half; this covers the decay/pricing half.

## 3. Wire `alerts` Into the Threat Loop (or cut it)
*Removes dead weight in either direction.*

- **Mechanic:** Connect `alerts` to heat escalation — alert level rises with Heat, alert level (not raw Heat) gates sweep/audit events — or delete the stat entirely.
- **Reason:** It is the only persisted gameplay field with zero consumers. As-is it misleads reading the code because it *looks* wired (signals + HUD + home panel).

## 4. Preparation Stage (Spend-to-Unlock Choices)
*Implements the actual "Prepare" step of the core loop: Discover → Evaluate → **Prepare** → Execute.*

- **Mechanic:** Between `ACCEPT` and `PROCEED`, one prep screen per contract with 1–3 purchasable unlocks (forged papers, bribe fund, intel route), each gated by Credits and optionally a contact.
- **Contract Impact:** Extend the choice filter `_available_choices()` with a `requires_prep` flag so prep purchases surface new complication resolutions. The visibility mechanism already exists (`max_heat`, `min_heat`, `requires_mara_favor`).
- **Relationship to a.md #1:** a.md proposes loadouts from an *asset catalog*; this is the cheaper v1 — per-contract authored prep options, no new inventory system, no asset catalog, one new phase (`preparing`) between `ready_to_proceed` and `customs_hold`.

## 5. Richer Resolutions (Partial Outcomes & Story Threads)
*Honors the pillar "outcomes are richer than binary success/failure."*

- **Partial success:** Choices that complete a contract *with* a cost — keep the cargo but lose the clinic's trust, take the payment as a favor owed, leave with Heat *and* a wounded reputation.
- **Second complication:** A chained event after the first resolution (the audit trail left in D-207 resurfaces in R-311). Same authored-dictionary format; two complications per contract, not a quest engine.
- **Recurring threads:** A light `flags`/`threads` dictionary on GameState feeds already-seeded mysteries ("who planted the audit tag", the corporate audit thread) into later contract availability or message content.

## 6. Favor Ledger (Boolean → Integer)
*One field change; a whole relationship dimension.*

- **Mechanic:** Replace `mara_favor_owed: bool` with a per-contact favor integer (favors owed *and* favors owed *to the player*).
- **Impact:** Settlement currently has a single path (`settle_mara_favor` on R-311). A ledger allows contacts to owe the player — payouts in favors, favors as bail for High Heat, favors as the currency that unlocks the clean option on later contracts. Preserves the existing `requires_mara_favor` / `clears_mara_favor` choice filter with minimal extension.

## 7. Contact Relationship Arcs
*Makes Mara a character, not a message sender.*

- **Mechanic:** Track a small per-contact "history" of the player's resolutions (clean vs. crude vs. abort) and vary authored messaging, future contract availability, or unlock conditions accordingly.
- **Impact:** The design doc's mentor pillar is currently satisfied by `accept_message` / `message_preview` strings. Arcs make the existing 7-contract portfolio replayable in feel without content churn.

## 8. Breadth: What Belongs Later
*Each is a real system; each matches the original vision but should follow the above.*

- **Backgrounds + mentor opening** — design doc §5–§7; Pillar 6 (background remains relevant past the tutorial).
- **Crew/companion (one recruit)** — crew background unlocks a specific complication choice ("rely on your Infiltrator"); injuries as a cost. Design doc §13 mentions one recruitable companion in the slice target.
- **Faction reputation matrix** — generalize the per-contact standing template; reputation *opens and closes content* (Pillar 5) rather than granting percentage bonuses.
- **Districts & travel** — destinations are display-only text; a 2–3 district map turns travel duration into a route/tradeoff decision. Every contract already carries `destination` and `proceed_minutes`.
- **Market/trade** — lowest priority: full subsystem, and the design doc's own instruction is to extend one proven loop first.

## 9. Cheap Player-Facing Quality

- **Lock reasons on the contract board** — "REQUIRES: MARA TRUSTED" alongside unavailable rows; the availability filter already computes it.
- **Resolution ledger** — a record of past choices and their consequences; costs one persisted array.
- **New Game / reset control** — single-profile JSON save already exists; a reset button + confirm is one action (state reset logic already lives in `reset_profile()`).

---

## If Only Three (Recommended First Batch)

1. **Enforce deadlines** — smallest diff, converts displayed data into decisions.
2. **Heat consequence ladder + decay** — makes the existing choice tradeoffs real.
3. **Preparation stage** — implements the design doc's missing loop step using the existing choice-filter mechanism.

All three run on existing fields, signals, and phases; none require a new subsystem. They serve the pillar: *plans should produce tension because complications can change them*.
