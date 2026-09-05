# Next Features — Synthesis & Recommendation

Cross-document review of `feature-ideas-a.md`, `feature-ideas-b.md`, `feature-ideas-c.md`, `feature-ideas-d.md`. Verdict first, evidence after.

## Verdict

Two themes appear in all four documents: **make Heat an active threat** and **add the missing Prepare step** to the contract loop. Everything else is contested or scoped differently. The recommended next batch is depth-first, built entirely on existing fields, signals, and phases — no new subsystems.

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
- **Heat gates only choice visibility.** `_available_choices()` filters on `max_heat` / `min_heat` / `requires_mara_favor` and nothing else. Heat mutates only via `choice.heat_delta` at resolution. One high-heat-only "desperate" choice already exists (`routed_vendor_id`, `min_heat: 4`), so the ladder has a seed.
- **`alerts` is dead weight.** Persisted, signaled, shown in the HUD and home panel, read nowhere else. It is also an unlocked rail module with no scene (a dead button).
- **Favor system is one boolean.** `mara_favor_owed: bool` with `requires_mara_favor` / `sets_mara_favor_owed` / `clears_mara_favor` choice flags. Working, but single-contact and one-directional.
- **The rail already reserves the breadth systems.** `resources/module_registry.tres` contains locked modules `crew`, `market`, `map`, `alerts`. The UI anticipates them; that does not make them the right next step.
- **Prior design docs deferred all of this deliberately.** `2026-08-26-first-contract-vertical-slice-design.md` and `2026-08-28-early-contract-portfolio-design.md` explicitly exclude deadline-expiry, favor/contact/reputation systems, inventory, crew, factions, economy, and maps *from those slices*. These four idea documents are the proposals to lift those deferrals — this is the intended next slice, not a contradiction of the plans.

## Recommendation

The deadline slice and the narrow preparation slice are implemented. The next depth-first batch below continues to use existing fields, signals, and phases; none requires a new subsystem.

**Implemented — contract deadlines.** The [approved design](docs/superpowers/specs/2026-09-05-contract-deadlines-design.md) uses publication windows rather than fixed calendar dates. Published offers and active jobs retain their calculated absolute cutoff across acceptance, save, and reload; offers become `expired`, active jobs become failed, and both publish abort-path successors without rewards or Heat, standing, or favor changes.

**1. Heat consequence ladder + decay.** Decay in `_settle_calendar_day()` (e.g. −1/day, or only via paid cleaner/contact action per C#2). Threshold events (3 / 6 / 9) broadcast over the existing ticker and `messages` arrays. High heat already hides clean choices via `max_heat`; add the cost side so `bypass` / `force_readout` become tradeoffs. Fold in **`alerts`**: alert level follows heat and gates sweep/audit events, or delete the stat. Do not build A#3/B#3 raid event sequences yet — threshold ticker/message pressure first.

**2. Preparation stage.** New phase `preparing` between `ready_to_proceed` and `customs_hold`. Per-contract authored prep options (1–3 purchases: forged papers, bribe fund, intel route), gated by Credits, surfaced through a `requires_prep` flag in `_available_choices()` — the exact mechanism of the existing heat/favor flags. This is C#4, the cheap v1 of A#1/B#1. No inventory system, no asset catalog.

**Implemented — optional contract preparation.** Cold-Chain Delivery and Data Retrieval offer an optional preparation purchase on the ready screen (no `preparing` phase): a one-time upfront payment unlocks one additional `requires_prep` response without replacing basic options or advancing time, gated by Credits and surfaced through the existing `_available_choices()` filter — the same mechanism the heat/favor flags use. This is C#4 and the preparation recommendation of D, the cheap v1 of A#1/B#1. No inventory system, no asset catalog; the other five contracts have no preparation purchase. See the [approved preparation design](docs/superpowers/specs/2026-09-05-contract-preparation-design.md).

**3. Aftermath + favor ledger.** Each resolution already emits an authored `message_preview`; add a delayed follow-up message or `flags`/`threads` entry that later contracts or messages can reference (C#5, D#3). Generalize `mara_favor_owed: bool` to a per-contact favor integer (owed both directions) with the existing three choice flags preserved (C#6, D#2). Cheap narrative consequence that makes the 7-contract portfolio replayable without new content systems.

**Not next (defer explicitly):** inventory/assets (A#1, B#1), crew roster (A#2, B#2), procedural contract generator (B#6), district travel map (B#5), market, faction matrix. Each is a real system and matches the original vision — build them after the contract loop has depth. When districts arrive, D#4 (authored venues, no map) is the cheap entry point; the rail's locked `map` module already exists.

## If only two

**Heat ladder + preparation.** Heat consequence pressure deepens the existing risk choices; preparation then adds the missing preparation step without introducing a broad subsystem. Favor/aftermath remains the next depth pass.
