# Next Features — Synthesis & Recommendation

Cross-document review of `feature-ideas-a.md`, `feature-ideas-b.md`, `feature-ideas-c.md`, `feature-ideas-d.md`. Verdict first, evidence after.

## Verdict

The four proposals converge on active Heat and the missing Prepare step. Every depth item they ranked has now shipped: deadline enforcement, optional preparation, active Heat, the Mara favor/aftermath depth pass, the operator dossier, and richer resolutions. What remains on the board is breadth — plus one test-harness defect that the last pass exposed and that will keep hiding regressions until it is fixed.

## What each document proposes

| Doc | Stance | Content |
|---|---|---|
| A | Breadth | Loadout asset catalog (#1), specialist roster/delegation (#2), heat sweeps/raids (#3), intel/market modifiers (#4), terminal hardware progression (#5) |
| B | Breadth | Item inventory (#1), roster/delegation (#2), heat audits (#3), pre-mission intel sniffing (#4), district travel map (#5), procedural contract generator (#6) |
| C | Depth, ranked by value-per-effort | Deadline enforcement (#1, implemented), heat ladder + decay (#2, implemented), wire-or-cut `alerts` (#3, removed), prep stage (#4, implemented), richer resolutions (#5, implemented), favor ledger (#6, implemented), contact arcs (#7), deferred breadth (#8) |
| D | Depth, minimal scope | Preparation choice (main rec), active heat (#1), small favor economy (#2), aftermath (#3), authored venues (#4), operator dossier (#5), explicit defer list |

## Similarities

**Heat → active consequences: 4/4.** All agree Heat is currently a passive gate with no cost to take. Proposals overlap heavily: sweeps/audits/raids (A#3, B#3, C#2), locking clean choices at high heat (C#2, D#1), decay only via explicit action (C#2). A and C cross-reference each other on this.

**Preparation phase: 4/4, one slot difference.** A, C, and D place it between ACCEPT and PROCEED (the documented loop: Discover → Evaluate → Prepare → Execute). C calls its version the cheaper v1 of A's loadout system and names the mechanism (`requires_prep` in the existing `_available_choices()` filter). B's intel-gathering variant sits one step earlier (pre-accept). Same instinct.

**Crew/roster/delegation: 3 propose, 1 defers.** A#2 and B#2 are near-identical (specialists, solo 100% vs delegated 30–50% cut, injury/capture risk). C lists one recruit as later breadth (#8). D explicitly defers.

**Districts: 4 mentions, 4 scopes.** A: ticker event modifiers. B: full travel map with transit costs. C: deferred ("destinations are display-only text"). D: authored local venues, no map system. No shared design.

**A and B are near-duplicates.** A#1≈B#1 (same example items: scrambler, burner transponder, forged credentials), A#2≈B#2, A#3≈B#3, A#4≈B#4. Only A#5 (hardware), B#5 (districts), B#6 (procedural) diverge.

**C and D converge on the same minimal first batch** (prep + heat pressure + favors/aftermath) and both explicitly defer A/B's breadth. D's defer list names A/B's proposals directly.

## Verified state of the current build

Grounding, checked against code (`autoload/game_state.gd`, `data/contracts/contract_catalog.gd`, `scenes/modules/contracts/contract_detail.gd`):

- **Deadlines are enforced, not display-only.** The approved [publication-relative deadline design](docs/superpowers/specs/2026-09-05-contract-deadlines-design.md) uses authored `deadline_window_minutes` to assign each published contract a persistent `deadline_at_minute`; the catalog no longer uses fixed `deadline_day` / `deadline_minute` fields. Unaccepted offers expire and active jobs fail at `now >= deadline`, including during same-day or long clock advances. Acceptance and reload do not renew the saved window.
- **Heat has authored consequences.** Upward crossings of 3 / 6 / 9 publish one highlighted ticker and one SYSTEM message per band. Go to Ground advances 24 hours, settles rent and deadlines, then reduces Heat by 1; ordinary Rest and calendar advancement do not reduce Heat. Silent Partner's custodian route pays 4,700 CR through Heat 5; above that the same route degrades to the 4,300 CR intermediary outcome with no standing change.
- **Alerts has been removed.** New profiles omit the legacy field; old v4 profiles still load, and a saved `active_module: alerts` normalizes to Home.
- **Mara favors work in both directions.** `mara_favor_balance: int` is capped at `-1` (you owe Mara), `0` (square), or `+1` (Mara owes you). Calling Mara creates debt; tracing M-508 settles debt or earns credit; R-311 hand delivery settles debt; M-613 can spend credit for +5,600 CR without added Heat, even at Heat 6+. Comms shows the balance and favor-changing actions have explicit previews and an accent. Saves are v5; v1-v4 migrations preserve deadlines and preparation.
- **Operator Dossier is available from the rail.** Its read-only, scrollable panel derives clean (completed routes adding no Heat), aggressive (completed routes adding Heat), overlapping community (completed clinic jobs), and partial (degraded routes) counts from recorded choices. It shows current Heat bands, existing contact standing and Mara's balance, and completed, partial, and failed operations in catalog order with their selected actions. Unaccepted expired offers are separate; lowering Heat does not rewrite historical counts. No new saved gameplay fields or profile-version change. Unlocked rail modules now support native keyboard focus.
- **Partial resolutions are implemented.** Arriving above a route's Heat threshold no longer deletes the response: it degrades it. Choices may declare `partial_above_heat` plus a `partial` block, and `heat > threshold` resolves the contract as the new terminal status `partial`, paying the authored degraded Credits and standing with degraded text. `heat_delta`, `mara_favor_delta`, and `unlocks_contract_ids` are inherited — the job still happened and still publishes successors. `max_heat` is gone from the catalog; `min_heat` workarounds remain. M-613's duplicate `buy_intermediary_silence` entry was folded into `buy_silence`'s degraded form. Both prepared routes degrade above Heat 6 with full payout and no standing, so payment buys a clean arrival but no longer buys trust. The dossier counts `partial` separately. `PROFILE_VERSION` stays 5; loading remaps a save recorded against the retired intermediary route instead of rejecting it. See the [approved design](docs/superpowers/specs/2026-10-25-partial-resolutions-design.md).
- **The rail reserves the remaining breadth systems.** `resources/module_registry.tres` contains locked modules `crew`, `market`, and `map`. Alerts is no longer registered or rendered.
- **Prior design docs deferred these systems deliberately.** The four idea documents proposed revisiting those deferrals. Deadlines, Contact standing, preparation, active Heat, Mara favors, the operator dossier, and partial resolutions are implemented; broad systems such as inventory, crew, factions, economy, and maps remain deferred.

## Recommendation

Deadline enforcement, optional preparation, active Heat, Mara favor/aftermath, the operator dossier, and richer resolutions are implemented. These depth additions use existing authored contracts and state rather than new simulation systems.

**Implemented — contract deadlines.** The [approved design](docs/superpowers/specs/2026-09-05-contract-deadlines-design.md) uses publication windows rather than fixed calendar dates. Published offers and active jobs retain their calculated absolute cutoff across acceptance, save, and reload; offers become `expired`, active jobs become failed, and both publish abort-path successors without rewards or Heat, standing, or favor changes.

**Implemented — active Heat.** Authored upward crossings at Heat 3 / 6 / 9 publish highlighted ticker and SYSTEM warnings. Go to Ground advances exactly 24 hours before lowering Heat by 1; rent and contract deadlines still advance during that interval. Rest does not lower Heat, and no automatic decay or raid events were added. Silent Partner's low-Heat custodian silence pays 4,700 CR as `completed`; above Heat 5 the same route pays 4,300 CR as `partial` without changing standing or favor. Alerts was removed while legacy v4 saves remain loadable.

**Implemented — optional contract preparation.** Cold-Chain Delivery and Data Retrieval offer an optional preparation purchase on the ready screen (no `preparing` phase): a one-time upfront payment unlocks one additional `requires_prep` response without replacing basic options or advancing time, gated by Credits and surfaced through the existing `_available_choices()` filter — the same mechanism the heat/favor flags use. This is C#4 and the preparation recommendation of D, the cheap v1 of A#1/B#1. No inventory system, no asset catalog; the other five contracts have no preparation purchase. See the [approved preparation design](docs/superpowers/specs/2026-09-05-contract-preparation-design.md).

**Implemented — Mara favor/aftermath.** The [approved design](docs/superpowers/specs/2026-09-29-mara-favor-aftermath-design.md) replaces the one-way boolean with a signed Mara-only balance. Tracing M-508 can earn the credit spent on M-613's optional clean route; opposite favors cancel before creating credit. Existing paid, risky, abort, and preparation routes retain their gates and rewards. The lasting balance and changed later choices are the aftermath, with ordinary resolution messages retained. No timed follow-ups, event queues, extra contracts, or per-contact ledger were added. Verified with all 16 project suites and a rendered main-scene smoke through debt, credit, and high-Heat favor spending.

**Implemented — operator dossier.** The [approved design](docs/superpowers/specs/2026-09-30-operator-dossier-design.md) adds an unlocked Dossier module after Contracts. It displays overlapping work-signature counts, current exposure and relationships, and resolved operations with expired offers separate. Saved module selection restores its open/collapsed state without toggling; choice history remains visible after its Heat/favor gate changes. Verified with all 18 runner entries (17 behavioral suites plus the base harness), and a rendered D3D12/Forward+ boot-to-main smoke at 1920×1080 and 1280×720: keyboard/mouse opening and scrolling, Escape, context closure, live Heat/favor updates, Go to Ground, collapse/expand, and actual process relaunch. The final regression run exited 0 with no script errors; existing harness audio/anchor/teardown diagnostics and deliberate persistence-failure diagnostics remain. Original save candidates were restored byte-for-byte after verification.

**Implemented — richer resolutions.** C#5, the last depth item on the value-per-effort ladder, is done: outcomes are no longer binary. Degradation is authored per response and derived from saved Heat, never rolled, and Heat can no longer change while a contract is active, so a preview shown before the player commits is still true when they do. The two blockers found in review — a preparation panel that stopped rendering its purchase button, and a validator that discarded saves naming the retired intermediary route — are fixed and covered. See the [approved design](docs/superpowers/specs/2026-10-25-partial-resolutions-design.md).

**Not next (defer explicitly):** inventory/assets (A#1, B#1), crew roster (A#2, B#2), procedural contract generator (B#6), district travel map (B#5), market, faction matrix. Each is a real system and matches the original vision. The old gate — "build them after the contract loop has depth" — has now been met, so the gate is retired: none of these should be built next, and one should be built only when a proven player loop needs it. When that happens, D#4 (authored venues, no map) is the cheap entry point; the rail's locked `map` module already exists.

**Rejected, not deferred:** A#4 (intel/market modifiers) and A#5 (terminal hardware progression) appeared in the proposals table and were never decided. Both are now declined: modifiers are a second economy layered on Credits without new content, and hardware progression is breadth that competes with crew rather than reinforcing the contract loop.

## Known gaps and defects

- **The test harness cannot fail on an engine error.** `tests/test_base.gd` counts only `check()` results, so a Godot `SCRIPT ERROR` prints to the log and the suite still reports `RESULT: ALL PASSED`. This is not hypothetical: during the partial-resolutions pass, preparation silently stopped rendering its purchase button, `test_main` printed the error nine times, and every suite stayed green. Candidate fix: record any engine error during the run and fail teardown, or make `run_all.ps1` fail on `SCRIPT ERROR` in captured output. Open — it will keep hiding regressions in every future pass.
- **Save corruption by catalog deletion is a standing hazard.** `_reject_profile` responds to any invalid profile by calling `reset_profile`, which deletes all three save files. Retiring an authored choice id therefore wipes the save of anyone who recorded it, unless a load-time remap is added in the same commit. `buy_intermediary_silence` → `buy_silence` is the one existing example. Any future catalog surgery must check this path.
- **The `partial` resolution cue is untested.** `scenes/main/main.gd` plays the completion sound for `partial` as it does for `completed`, but `tests/test_main.gd` only asserts the `completed` mapping.
- **Preparation has a single price for every Heat level.** Its degraded form costs standing rather than credits, which is deliberate, but the 300/500 CR upfront cost does not scale with exposure.

## If only two

**The minimal depth batch is complete, and so is the depth list.** Mara's signed favors, the M-508 -> M-613 authored consequence, and non-binary resolutions now join deadlines, preparation, active Heat, and the operator dossier. Every item C and D ranked as depth is shipped; what remains from those documents is breadth and contact arcs.

**Next real step: D#4 authored venues, not a system.** `GLOSSARY.md` already defines *Venue* and *Visit* and explicitly says a venue is not a contract destination label — the vocabulary for this work exists and nothing implements it. One authored venue with one visitable person is the cheapest way to turn the contract board into a place, and it needs no inventory, crew, market, or map. Contact arcs (C#7) are the natural follow-on and should be built on venues rather than on the contract list.

**Fix the harness first.** Every green run below this item is less trustworthy than it reads; the partial-resolutions pass shipped a broken preparation panel through 19 passing suites. That is one small change to `tests/test_base.gd` and it protects everything after it.

Per-contact favor expansion still waits on a second real relationship; timed follow-ups remain unimplemented. Inventory, crew, market, and maps remain deferred.
