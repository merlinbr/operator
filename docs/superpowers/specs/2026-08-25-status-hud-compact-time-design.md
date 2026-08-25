# Status HUD Compact Time Field

**Date:** 2026-08-25  
**Status:** Design approved; specification review pending

## Goal

Remove the visually excessive slot before the Collapse action and make the time field compact and balanced with the Day field. At the reference layout, `DAY 14` and `23:41` should each occupy an approximately 80 px field with centered values. `LOWER VESPER` remains naturally wider because its text requires more room. The overall HUD may become slightly narrower.

## Existing Context

`StatusChip` builds one horizontal row containing four labels, three padded status dividers, an expanding `Control` spacer, the existing divider before the workspace action, and `WorkspaceAction`. The spacer currently absorbs all remaining row width, making the time/action boundary appear much wider than the other status fields. `status_chip.tscn` also declares a 640 px custom minimum width, which prevents the outer HUD from shrinking to its content.

## Design

### Component boundary

Keep all layout ownership in `StatusChip`. Do not add a new HUD wrapper, rename the component, change `Main`, or alter `GameState` and collapse behavior.

### Field sizing and alignment

Add one shared compact field width constant of `80 px`.

Set both the Day and Time labels to:

- `custom_minimum_size.x = 80`;
- centered horizontal text alignment.

Keep Credits and `LOWER VESPER` content-sized and left-aligned. Do not assign a fixed width to the location field; its natural text width must remain wider than the Day/Time fields.

### Row structure

Remove the expanding spacer completely. Keep the existing three padded status dividers unchanged and keep the existing divider before `COLLAPSE`.

The resulting row order is:

1. credits label;
2. padded status divider;
3. district label;
4. padded status divider;
5. day label, 80 px and centered;
6. padded status divider;
7. time label, 80 px and centered;
8. existing action divider;
9. existing Collapse/Expand button.

The action must follow the time section directly through the existing divider. No replacement spacer, maximum-width spacer, or manual positioning is needed.

### Overall HUD width

Remove the scene's fixed 640 px horizontal minimum while preserving its existing 38 px vertical minimum. Let the row's natural child minimum sizes determine the outer width, with the existing panel margins and action button included. `Main._apply_layout()` continues to center the resulting HUD using its existing combined-minimum-size path.

### Visual and interaction treatment

Keep the current 16 px horizontal padding around all three status dividers, existing muted divider styling, amber Credits styling, monospace typography, and panel treatment. Status labels and dividers remain non-interactive. `WorkspaceAction` remains the only interactive child, with its existing labels, tooltip text, signal, and focus behavior unchanged.

## Affected Files

- `scenes/ui/status_chip.gd` — add the 80 px compact field sizing/alignment and remove the flexible spacer.
- `scenes/ui/status_chip.tscn` — remove the fixed 640 px horizontal minimum while retaining the 38 px vertical minimum.
- `tests/test_status_chip.gd` — update the row contract for nine children and assert centered 80 px Day/Time fields plus the direct action-divider boundary.

Do not change `Main`, `GameState`, the three existing status divider margins, action semantics, status data, icon rail behavior, ticker behavior, or unrelated theme surfaces.

## Verification

Run the existing headless suite. The status-chip test must demonstrate:

1. all four status values and their existing updates remain correct;
2. Day and Time each have an 80 px minimum width and centered alignment;
3. the row contains exactly three padded status dividers and the existing action divider;
4. the existing action divider immediately follows the compact Time field;
5. `WorkspaceAction` is the final row child and no flexible spacer remains;
6. collapsed and expanded action labels/tooltips remain unchanged.

Launch the Godot project at the reference viewport and inspect the actual HUD. Confirm that `23:41` no longer occupies the former wide empty slot, Day/Time values are centered in comparable compact fields, `LOWER VESPER` remains wider, Collapse follows the time divider directly, and the centered HUD is slightly narrower without losing readability.

## Scope Exclusions

Do not add responsive breakpoints, custom drawing, new dependencies, animation, a spacer cap, manual x-positioning, or a new status HUD abstraction. Do not redesign the existing dividers or change the Collapse action's behavior.
