# Operator Dossier Design

## Goal and approval

Add the approved read-only Dossier module to the terminal rail: work signature, current relationships, current Heat, and an operations record derived from existing saved state. This document specifies future implementation. The user approved the dedicated module approach; the written specification remains subject to review before implementation planning.

## Player-facing behavior

- Register an unlocked core module with ID `dossier`, display name `DOSSIER`, glyph `▤`, and `normal` size class. Place it after Contracts and before the locked operational modules. Use the existing rail, module host, theme, collapse, switching, and Escape behavior; no separate window or contract context panel.
- The panel has four sections: `WORK SIGNATURE`, `EXPOSURE`, `RELATIONSHIPS`, and `OPERATIONS RECORD`. It is read-only and does not advance time, change gameplay state, or publish messages. Normal module-selection persistence remains unchanged.
- Work signature shows three numeric counts, not a dominant personality, rank, percentage, or new progression statistic. `CLEAN` counts completed contracts whose selected authored choice has `heat_delta == 0`; `AGGRESSIVE` counts completed contracts whose selected choice has `heat_delta > 0`; `COMMUNITY` counts completed contracts with `contact_id == vesper_clinic`. Community overlaps either route category. Include a short visible explanation: clean means no added Heat, aggressive means a Heat-generating route, and community means completed clinic work. Aggressive does not imply combat. Aborts, active jobs, and missed deadlines do not contribute. Before any completion, show zero counts and `NO COMPLETED OPERATIONS YET`.
- Exposure shows current Heat with its existing band thresholds: below 3 `BELOW WARNING THRESHOLD`, 3–5 `ELEVATED`, 6–8 `WATCHED`, 9+ `CRITICAL`. Reuse `HEAT_WARNING_BANDS` for the authored thresholds and names rather than inventing a second ladder. Lowering current Heat does not alter historical work-signature counts.
- Relationships show all contacts in catalog order using `contact_snapshot()`: display name and existing standing label, with Mara's existing `YOU OWE MARA`, `SQUARE`, or `MARA OWES YOU` label. Do not add a second favor ledger or imply favor balances for other contacts.
- Operations record shows each completed or failed job: code, title, terminal status, and the selected authored choice label. An active job lost to its deadline shows `DEADLINE MISSED`, not a selected choice. Use stable action labels rather than static result text that could misrepresent a historical favor transition. No completion timestamp or chronological claim: the current save does not retain completion order, so rows use catalog order.
- Expired unaccepted offers appear separately beneath `EXPIRED OFFERS`, with code and title. They are not failed undertaken jobs and do not contribute to work signature. Available, unpublished, and active contracts are excluded from both historical lists. If there are no completed or failed jobs, show `NO RESOLVED OPERATIONS YET`; omit the expired-offers subsection when there are none.

## Architecture and state

- `autoload/game_state.gd` provides one derived dossier snapshot from its authoritative contracts, Heat, and existing contact snapshot. Resolve historical choice IDs against the current authored catalog, following the existing validated/reconstructed contract-state convention. Do not use currently filtered choices: high-Heat or spent-favor gates must not erase historical choices.
- The snapshot contains signature counts, current Heat and band label, contacts, resolved operation rows, and expired-offer rows. It contains no mutable references that permit the panel to change authoritative state.
- Add `scenes/modules/dossier/dossier_panel.gd` and its scene using the existing `setup(gs, data)` panel convention. The panel renders the snapshot with standard Godot labels/containers; no dependency or generic profile framework.
- Register the module in `resources/module_registry.tres` and load it through `scenes/main/main.gd`. Opening it supplies a fresh snapshot. While it is open, contract, contact, and Heat changes refresh its data using existing state signals. Refreshes replace prior rows instead of accumulating duplicates; hidden panels can refresh when next opened. Reset/load state must be reflected when reopened.
- Confirm module restoration permits `dossier` so reopening the game restores the selected module through the existing save path. Profile version remains 5: no new persisted gameplay fields, counters, timestamps, classification tags, or migration. Older saves derive the dossier from their migrated contract state.
- No changes to existing choice rewards, unlocks, standing, favors, preparation, deadlines, Heat effects, or housing behavior. No inventory, achievements, contact arcs, timed aftermath, editable identity, starting statistics, or narrative milestone engine.

## Layout and accessibility

- Use the terminal's existing font, theme, heading hierarchy, and accent colors. Every status remains readable in text; color is supplementary.
- Keep the panel within its normal-size host. Use a vertical ScrollContainer with horizontal scrolling disabled and wrapping labels so the seven-contract record cannot force the workspace off-screen. Long titles and action labels remain accessible rather than clipped away.
- Rail button remains keyboard-accessible through existing navigation behavior. Scrolling remains usable with mouse and keyboard. Opening the dossier closes any previous contract context through normal module switching.

## Verification and delivery

- Retain one focused behavioral dossier test suite in the existing Godot harness: fresh profile, mixed clean/aggressive/community completions with overlapping counts, abort versus active deadline failure versus expired offer, historical choice surviving changed Heat/favor eligibility, and current relationship/Heat updates. Verify reducing Heat leaves historical signature unchanged and read-only snapshot/rendering leaves gameplay state unchanged.
- Exercise save/reload with Dossier selected and existing completed choices; verify derived counts and history survive without a profile-version change. Run affected existing navigation and persistence suites, then the existing full suite once after integration.
- Smoke the actual rendered main scene: open Dossier from the rail, inspect fresh and populated sections, scroll through the record, switch from contract detail, close with Escape, and reopen after Heat/favor changes. Inspect at the project's normal and smallest supported window sizes for wrapping, reachability, and workspace overflow. Record observed results and any visual-verification limit.
- After smoke proof, update the existing feature synthesis/backlog to mark Operator Dossier implemented and document its count semantics and separate expired-offer display. Remove temporary smoke scaffolding. Do not claim implementation or runtime verification while this document is still a design.
