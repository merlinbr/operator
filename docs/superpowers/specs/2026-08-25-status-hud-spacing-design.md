# Status HUD Spacing and Dividers

**Date:** 2026-08-25  
**Status:** Design approved; specification review pending

## Goal

Improve readability of the centered top status HUD without changing its overall width or its existing action placement. The four status fields must read as distinct values instead of one continuous string:

`12,480 CR | LOWER VESPER | DAY 14 | 23:41     | COLLAPSE ▲`

The location remains `LOWER VESPER`. `DAY 14` and `23:41` remain separate fields.

## Existing Context

`StatusChip` already owns the four status labels and the integrated workspace action. Its child row is built programmatically in `scenes/ui/status_chip.gd` as four labels, an expanding spacer, one divider, and the action button. `Main._apply_layout()` sizes and centers the chip from its combined minimum size. The scene supplies the existing wide minimum footprint, and the current divider before the action marks the transition into the workspace command.

## Design

### Component boundary

Keep `StatusChip` as the only top HUD component. Do not add a wrapper, rename the class, or move layout responsibility into `Main`. `GameState` and collapse behavior remain unchanged.

### Content and layout

Keep the existing horizontal row and child order, changing only the status-field portion:

1. credits label;
2. padded divider;
3. district label;
4. padded divider;
5. day label;
6. padded divider;
7. time label;
8. existing expanding spacer;
9. existing divider before the action;
10. existing Collapse/Expand button.

Each of the three new dividers is a native `VSeparator` wrapped in a `MarginContainer`. Give each wrapper approximately `14–18 px` of horizontal padding on both sides. Use the same padding for all three separators so the four fields have a consistent rhythm.

The expanding spacer before the action must remain. It continues to consume remaining width and preserves the large visual separation between status information and `COLLAPSE`. The existing divider immediately before the action must remain as a separate control; it is not one of the three status dividers.

Do not increase the chip's overall width to accommodate the spacing. Preserve the existing scene minimum width and centered layout. The new separator margins should consume available room inside that footprint; if the layout needs to reclaim space, the flexible spacer before the action shrinks first. Do not introduce a second responsive layout or a fixed-position workaround.

### Visual treatment

Use the existing monospace typography and panel palette. Keep the new dividers thin and muted, matching the existing divider before the action. Do not add new colors, decorative symbols, shadows, extra borders, or a new theme family. The spacing is the primary visual change.

### Interaction and state

The three status dividers and all status labels remain non-interactive. The existing action button remains the only interactive child. Credits, district, day, time, collapse state, tooltips, and signal wiring retain their current behavior.

## Affected Files

- `scenes/ui/status_chip.gd` — insert the three padded native divider controls while preserving the existing spacer and action divider.
- `tests/test_status_chip.gd` — verify the four status labels remain separate and the row contains three status dividers plus the existing action divider.

Do not change `Main`, `GameState`, scene sizing, theme colors, workspace collapse semantics, icon rail behavior, ticker behavior, or unrelated UI.

## Verification

Run the existing headless test suite. The changed HUD test must demonstrate:

1. the four labels still initialize as `12,480 CR`, `LOWER VESPER`, `DAY 14`, and `23:41`;
2. exactly four `VSeparator` controls exist in the row;
3. three separators sit between the four status labels;
4. the fourth separator remains immediately before `WorkspaceAction`;
5. status updates and collapse/expand action behavior remain unchanged.

Launch the Godot project for a visual smoke check at the reference viewport. Confirm that the status fields are visibly separated, each divider has balanced horizontal breathing room, the large gap before `COLLAPSE` remains, the HUD stays centered, and its outer width does not grow.

## Scope Exclusions

Do not add responsive breakpoints, custom drawing, animation, new HUD abstractions, new dependencies, or text-based separator characters. Do not alter the HUD's data, action semantics, overall placement, or existing divider before `COLLAPSE`.
