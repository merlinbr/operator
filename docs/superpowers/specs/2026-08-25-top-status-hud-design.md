# Top Status HUD Integration

**Date:** 2026-08-25  
**Status:** Approved

## Goal

Make the top status HUD wider and flatter while keeping it compact and centered. Integrate the existing Collapse Workspace action into the right side of that same HUD so the result reads as a lightweight system status strip, not a separate toolbar or floating control.

## Existing Context

`Main` currently creates a vertical `StatusChip` near the top center and a separate `CollapseToggle` button near the top-right edge. `GameState` owns `workspace_collapsed`; `Main` owns the workspace shell and connects the current button to `GameState.toggle_workspace()`.

## Design

### Component boundary

Expand `StatusChip` into the complete top HUD. It owns visual layout, status labels, the integrated action button, and the presentation of collapsed versus expanded state. It does not own workspace state.

`StatusChip` emits a `collapse_requested` signal when its action is activated. `Main` connects that signal to the existing `GameState.toggle_workspace()` method. `GameState` remains the single source of truth, and `Main` remains responsible for workspace behavior and visibility.

Remove `Main`'s separate `CollapseToggle` node, builder, layout calculation, and signal connection. Do not add a wrapper HUD or a new one-use scene.

### Content and layout

Render one horizontal row with these status fields, in order:

`12,480 CR | LOWER VESPER | DAY 14 | 23:41 | COLLAPSE ▲`

Build the row as `status fields → flexible spacer → divider → action`. Keep credits, district, day, and time grouped on the left/center portion of the HUD; the action is the right-side control end-cap of the same frame, not another evenly spaced status field.

Keep the HUD centered using the existing `Main._apply_layout()` centering path. Give the control a thin, wide footprint: approximately 36–40 px tall and 620–680 px wide at the reference resolution. Keep the row intact rather than introducing a second responsive layout. Preserve the existing top offset.

### Visual treatment

Use the approved bracket-frame direction:

- thin muted outline around the full HUD;
- square or near-square corners, using the existing panel palette;
- dark, quiet interior rather than a prominent filled toolbar surface;
- existing monospace theme typography and spacing;
- muted resting text for normal status information, with the existing warm amber/yellow emphasis preserved for credits;
- no floating button, icon rail, extra shadow, or decorative toolbar chrome.

The bracket-frame direction means a restrained rectangular status frame, not a separate set of corner widgets or a new visual system.

### Interaction and state

Only the integrated action button is interactive. Clicking other status fields has no effect. Keyboard activation remains available through the `Button`, with the existing quiet focus styling.

The HUD listens to `workspace_collapsed_changed` and updates the action label and tooltip. During `StatusChip.setup(gs)`, initialize the action presentation from the current `gs.workspace_collapsed` value so an already-collapsed workspace immediately shows the expanded-state action.

- expanded: `COLLAPSE ▲`, “Collapse workspace”;
- collapsed: `EXPAND ▼`, “Expand workspace”.

Collapse semantics do not change: primary and context panels hide, while the status HUD, icon rail, and ticker remain visible. Expanding does not reopen a module that was already closed. Existing module selection, Esc handling, and ticker behavior remain unchanged.

## Affected Files

- `scenes/ui/status_chip.gd` — horizontal HUD children, visible day/time fields, action signal, and state label updates.
- `scenes/ui/status_chip.tscn` — wide/flat minimum sizing if needed by the composite row.
- `scenes/main/main.gd` — remove the standalone collapse button and position only the integrated HUD.
- `resources/operator_theme.tres` — tune the existing StatusChip style into the thin bracket-frame treatment without introducing new colors or a new theme family.
- `tests/test_status_chip.gd` — verify four status fields, updates, action signal, and collapsed/expanded label presentation.
- `tests/test_main.gd` — verify there is no standalone collapse node, the integrated HUD survives collapse, and the action toggles `GameState` state.

Preserve the current idempotent child construction used by headless tests and keep setup dependency injection through `setup(gs)`; do not add autoload lookups or new abstractions. Keep the existing `StatusChip` scene/class naming; do not rename it to `StatusHud` or introduce related refactors.

## Verification

Run the existing headless test suite. The changed tests must demonstrate:

1. status content initializes from the default `GameState` values;
2. credits and clock changes update the correct fields, including day rollover behavior already covered by the state signal;
3. the integrated action emits intent and updates its label/tooltip when collapse state changes;
4. an initially collapsed `GameState` makes `StatusChip.setup(gs)` immediately show `EXPAND ▼` and “Expand workspace”;
5. `Main` contains one top HUD and no `CollapseToggle` node;
6. collapse still hides panels while leaving the HUD, rail, and ticker visible;
7. the HUD is wider than it is tall and remains centered.

Launch the Godot project for a visual smoke check at the reference viewport: confirm the thin bracket frame, centered placement, readable dividers, quiet integrated action, and expanded/collapsed label transition.

## Scope Exclusions

Do not change workspace collapse semantics, module layout sizing, icon rail behavior, ticker behavior, game-state fields, or unrelated theme surfaces. Do not add responsive breakpoints, animation systems, tooltips beyond the existing action tooltip, a new HUD abstraction, or a `StatusHud` rename. Do not address workspace/side-rail alignment; keep that as a separate follow-up.
