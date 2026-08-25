# Status HUD Compact Time Field Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Day and Time compact, centered 80 px fields and remove the flexible gap before the Collapse action so the HUD narrows to its content.

**Architecture:** Keep the existing programmatic `StatusChip` row and three padded native status dividers. Configure Day and Time labels directly with one shared 80 px field constant, remove the spacer child, and let the existing action divider/button follow Time directly. Remove only the scene's fixed horizontal minimum; `Main` continues to center the chip through its existing minimum-size path.

**Tech Stack:** Godot 4.7.1, GDScript, native Godot containers/labels, and the repository's minimal headless `SceneTree` tests.

## Global Constraints

- Use one shared compact field width of `80 px` for Day and Time.
- Center the Day and Time label values horizontally.
- Keep Credits and `LOWER VESPER` content-sized and left-aligned; do not assign a fixed location width.
- Remove the expanding spacer completely; do not replace it with a capped spacer or manual positioning.
- Preserve the three existing padded status dividers and the existing divider before `COLLAPSE`.
- Preserve `WorkspaceAction`, its labels/tooltips, signal, focus behavior, and collapse semantics.
- Remove the scene's fixed `640 px` horizontal minimum while retaining its `38 px` vertical minimum.
- Do not change `Main`, `GameState`, status data, theme divider treatment, icon rail behavior, ticker behavior, or unrelated UI.
- Do not add dependencies, custom drawing, responsive breakpoints, animation, or a new HUD abstraction.
- Prefix shell commands with `rtk`.

---

### Task 1: Specify compact field and row contracts

**Files:**
- Modify: `tests/test_status_chip.gd:39-67`
- Test: `tests/test_status_chip.gd`

**Interfaces:**
- Consumes: Existing `StatusChipScene` construction, four status labels, current padded-divider wrappers, and `WorkspaceAction`.
- Produces: A failing test contract for 80 px centered Day/Time fields, a nine-child row, direct Time-to-action-divider adjacency, and a shrinkable scene width.

- [ ] **Step 1: Update the row-size and action-boundary assertions**

Change the existing row contract to expect nine children and move the preserved action divider/action checks from child indices 8/9 to 7/8:

```gdscript
	check(row_children.size() == 9, "status row removes the flexible spacer")
	check(row_children.size() > 7 and row_children[7] is VSeparator,
		"existing divider remains immediately after the time field")
	check(row_children.size() > 8 and row_children[8] == action,
		"workspace action remains the final row child")
```

Keep the existing checks for the three padded dividers at indices 1, 3, and 5 and the four total `VSeparator` nodes.

- [ ] **Step 2: Add the compact field and scene-width assertions**

After the existing four label text assertions, add:

```gdscript
	check(labels[2].custom_minimum_size.x == 80.0, "day field uses 80 px minimum width")
	check(labels[3].custom_minimum_size.x == 80.0, "time field uses 80 px minimum width")
	check(labels[2].horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER,
		"day value is centered")
	check(labels[3].horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER,
		"time value is centered")
	check(labels[1].custom_minimum_size.x == 0.0,
		"location field remains content-sized")
	check(chip.custom_minimum_size == Vector2(0.0, 38.0),
		"HUD removes fixed width while retaining 38 px height")
```

The current implementation must fail these new checks because Day/Time have no explicit compact sizing, the row still contains the flexible spacer, and the scene still declares a 640 px horizontal minimum.

- [ ] **Step 3: Run the focused test and confirm the expected failure**

Run:

```powershell
rtk powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\run_test.ps1 test_status_chip
```

Expected: existing status/action checks pass, while the new width, alignment, row-size, and scene-minimum checks fail.

- [ ] **Step 4: Commit the failing contract test**

```powershell
rtk git add tests/test_status_chip.gd
rtk git commit -m "test: specify compact status time field"
```

---

### Task 2: Implement compact fields and content-sized HUD

**Files:**
- Modify: `scenes/ui/status_chip.gd:7-51`
- Modify: `scenes/ui/status_chip.tscn:5-8`

**Interfaces:**
- Consumes: Task 1's row/field contract.
- Produces: An 80 px centered Day/Time pair, no flexible spacer, preserved dividers/action, and a HUD whose width derives from content.

- [ ] **Step 1: Configure Day and Time with the shared width constant**

Add this constant beside the existing divider margin constant:

```gdscript
const COMPACT_FIELD_WIDTH := 80.0
```

Immediately after creating `_day_label` and `_time_label`, configure both labels:

```gdscript
	_day_label.custom_minimum_size.x = COMPACT_FIELD_WIDTH
	_day_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_time_label.custom_minimum_size.x = COMPACT_FIELD_WIDTH
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
```

Do not assign a custom minimum width to `_credits_label` or `_district_label`.

- [ ] **Step 2: Remove the flexible spacer without changing the action boundary**

Delete this block after `_time_label` is added:

```gdscript
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
```

Leave the existing direct `VSeparator`, `WorkspaceAction` setup, signal connection, and final button insertion unchanged. The final row must be:

`Label, MarginContainer, Label, MarginContainer, Label, MarginContainer, Label, VSeparator, Button`

- [ ] **Step 3: Remove only the fixed scene width**

Change `scenes/ui/status_chip.tscn`:

```ini
custom_minimum_size = Vector2(0, 38)
```

Keep the existing scene node, offsets, script, and vertical minimum. Do not change `Main._apply_layout()`.

- [ ] **Step 4: Run the focused test and confirm it passes**

Run:

```powershell
rtk powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\run_test.ps1 test_status_chip
```

Expected: `RESULT: ALL PASSED`, including centered 80 px Day/Time fields, nine row children, direct action-divider adjacency, preserved status updates, and collapsed action presentation.

- [ ] **Step 5: Commit the implementation**

```powershell
rtk git add scenes/ui/status_chip.gd scenes/ui/status_chip.tscn tests/test_status_chip.gd
rtk git commit -m "feat: compact status time field"
```

---

### Task 3: Run regression and visual HUD smoke checks

**Files:**
- Verify: `scenes/ui/status_chip.gd`
- Verify: `scenes/ui/status_chip.tscn`
- Verify: `tests/test_status_chip.gd`
- Verify unchanged: `scenes/main/main.gd`

**Interfaces:**
- Consumes: The completed compact content-row HUD.
- Produces: Evidence that all existing status/collapse behavior remains intact and the running project presents the narrower layout.

- [ ] **Step 1: Run the full existing headless suite**

Run:

```powershell
rtk powershell -NoProfile -Command "$tests = 'test_smoke','test_game_state','test_module_registry','test_theme','test_placeholder_data','test_status_chip','test_icon_rail','test_ticker_bar','test_panels_basic','test_contracts','test_main'; foreach ($test in $tests) { & .\tests\run_test.ps1 $test; if (`$LASTEXITCODE -ne 0) { exit `$LASTEXITCODE } }"
```

Expected: every test prints `RESULT: ALL PASSED` and the command exits successfully.

- [ ] **Step 2: Launch the actual Godot project and inspect the HUD**

Run:

```powershell
rtk powershell -NoProfile -Command "& 'C:\Users\merli\Documents\Godot Projects\Godot_v4.7.1-stable_win64_console.exe' --path ."
```

At the reference viewport, verify that `DAY 14` and `23:41` are centered in comparable compact fields, `LOWER VESPER` remains wider, the existing three dividers are unchanged, the action divider follows Time directly, the HUD is slightly narrower and centered, and Collapse/Expand still works.

- [ ] **Step 3: Check the final diff and whitespace**

Run:

```powershell
rtk git diff --check
rtk git status --short
```

Expected: no whitespace errors and only the intended implementation/test/docs changes remain.
