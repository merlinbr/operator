# Next Features — Synthesis & Recommendation

Cross-document review of `feature-ideas-a.md`, `feature-ideas-b.md`, `feature-ideas-c.md`, `feature-ideas-d.md`. Verdict first, evidence after.

## Verdict

The four proposals converge on active Heat and the missing Prepare step. Deadline enforcement, optional preparation, active Heat, and the Mara favor/aftermath depth pass are now implemented. Broader systems remain deferred.

## What each document proposes

| Doc | Stance | Content |
|---|---|---|
| A | Breadth | Loadout asset catalog (#1), specialist roster/delegation (#2), heat sweeps/raids (#3), intel/market modifiers (#4), terminal hardware progression (#5) |
| B | Breadth | Item inventory (#1), roster/delegation (#2), heat audits (#3), pre-mission intel sniffing (#4), district travel map (#5), procedural contract generator (#6) |
| C | Depth, ranked by value-per-effort | Deadline enforcement (#1, implemented), heat ladder + decay (#2), wire-or-cut `alerts` (#3), prep stage (#4), richer resolutions (#5), favor ledger (#6), contact arcs (#7), deferred breadth (#8) |
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
- **Heat has authored consequences.** Upward crossings of 3 / 6 / 9 publish one highlighted ticker and one SYSTEM message per band. Go to Ground advances 24 hours, settles rent and deadlines, then reduces Heat by 1; ordinary Rest and calendar advancement do not reduce Heat. Silent Partner's custodian route is available through Heat 5, with a lower-payout intermediary route at Heat 6+.
- **Alerts has been removed.** New profiles omit the legacy field; old v4 profiles still load, and a saved `active_module: alerts` normalizes to Home.
- **Mara favors work in both directions.** `mara_favor_balance: int` is capped at `-1` (you owe Mara), `0` (square), or `+1` (Mara owes you). Calling Mara creates debt; tracing M-508 settles debt or earns credit; R-311 hand delivery settles debt; M-613 can spend credit for +5,600 CR without added Heat, even at Heat 6+. Comms shows the balance and favor-changing actions have explicit previews and an accent. Saves are v5; v1-v4 migrations preserve deadlines and preparation.
- **The rail reserves the remaining breadth systems.** `resources/module_registry.tres` contains locked modules `crew`, `market`, and `map`. Alerts is no longer registered or rendered.
- **Prior design docs deferred these systems deliberately.** The four idea documents proposed revisiting those deferrals. Deadlines, Contact standing, preparation, and active Heat are implemented; broad systems such as inventory, crew, factions, economy, and maps remain deferred.

## Recommendation

Deadline enforcement, optional preparation, active Heat, and Mara favor/aftermath are implemented. The depth pass uses existing authored contracts and panels, not a new subsystem.

**Implemented — contract deadlines.** The [approved design](docs/superpowers/specs/2026-09-05-contract-deadlines-design.md) uses publication windows rather than fixed calendar dates. Published offers and active jobs retain their calculated absolute cutoff across acceptance, save, and reload; offers become `expired`, active jobs become failed, and both publish abort-path successors without rewards or Heat, standing, or favor changes.

**Implemented — active Heat.** Authored upward crossings at Heat 3 / 6 / 9 publish highlighted ticker and SYSTEM warnings. Go to Ground advances exactly 24 hours before lowering Heat by 1; rent and contract deadlines still advance during that interval. Rest does not lower Heat, and no automatic decay or raid events were added. Silent Partner's low-Heat custodian silence pays 4,700 CR; at Heat 6+, intermediary silence pays 4,300 CR without changing standing or favor. Alerts was removed while legacy v4 saves remain loadable.

**Implemented — optional contract preparation.** Cold-Chain Delivery and Data Retrieval offer an optional preparation purchase on the ready screen (no `preparing` phase): a one-time upfront payment unlocks one additional `requires_prep` response without replacing basic options or advancing time, gated by Credits and surfaced through the existing `_available_choices()` filter — the same mechanism the heat/favor flags use. This is C#4 and the preparation recommendation of D, the cheap v1 of A#1/B#1. No inventory system, no asset catalog; the other five contracts have no preparation purchase. See the [approved preparation design](docs/superpowers/specs/2026-09-05-contract-preparation-design.md).

**Implemented — Mara favor/aftermath.** The [approved design](docs/superpowers/specs/2026-09-29-mara-favor-aftermath-design.md) replaces the one-way boolean with a signed Mara-only balance. Tracing M-508 can earn the credit spent on M-613's optional clean route; opposite favors cancel before creating credit. Existing paid, risky, abort, and preparation routes retain their gates and rewards. The lasting balance and changed later choices are the aftermath, with ordinary resolution messages retained. No timed follow-ups, event queues, extra contracts, or per-contact ledger were added. Verified with all 16 project suites and a rendered main-scene smoke through debt, credit, and high-Heat favor spending.

**Not next (defer explicitly):** inventory/assets (A#1, B#1), crew roster (A#2, B#2), procedural contract generator (B#6), district travel map (B#5), market, faction matrix. Each is a real system and matches the original vision — build them after the contract loop has depth. When districts arrive, D#4 (authored venues, no map) is the cheap entry point; the rail's locked `map` module already exists.

## If only two

**The minimal depth batch is complete.** Mara's signed favors and M-508 -> M-613 authored consequence now join deadlines, preparation, and active Heat. Add per-contact favor expansion only when a second real relationship needs it; separate timed follow-ups remain unimplemented. Inventory, crew, market, and maps remain deferred.
