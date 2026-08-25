# Status HUD Spacing and Dividers Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the four centered status fields readable with three padded native dividers while preserving the existing HUD width, flexible action spacer, and divider before `COLLAPSE`.

**Architecture:** Keep all layout ownership in `StatusChip`. Add three `MarginContainer` wrappers, each containing one `VSeparator`, between the existing status labels; leave the existing expanding `Control`, action divider, and button order unchanged. No changes to `Main`, `GameState`, scene sizing, or theme resources.

**Tech Stack:** Godot 4.7.1, GDScript, native `HBoxContainer`, `MarginContainer`, `VSeparator`, and the repository's minimal headless `SceneTree` tests.

## Global Constraints

- Use exactly three new status dividers between the four labels.
- Set each new divider wrapper's left and right margins to `16` px, within the required `14–18 px` range.
- Preserve the existing expanding spacer before the action.
- Preserve the existing standalone `VSeparator` immediately before `WorkspaceAction`.
- Do not increase `StatusChip`'s overall width or change its scene minimum size.
- Keep status labels and dividers non-interactive; `WorkspaceAction` remains the only interactive child.
- Do not add dependencies, custom drawing, responsive layouts, new abstractions, or text-based separator characters.
- Prefix shell commands with `rtk`.

---

### Task 1: Add structural HUD layout assertions

**Files:**
- Modify: `tests/test_status_chip.gd:35-43`

**Interfaces:**
- Consumes: Existing `StatusChipScene`, four status labels, and `WorkspaceAction` created by `StatusChip.setup(gs)`.
- Produces: Assertions for the exact row sequence and 16 px divider margins that the implementation must satisfy.

- [ ] **Step 1: Add the failing structural checks**

Immediately after the existing `WorkspaceAction` lookup and action checks, add checks for the row shape:

```gdscript
	var row := chip.find_child("HBoxContainer", true, false) as HBoxContainer
	check(row != null, "status fields share one horizontal row")
	var row_children := row.get_children() if row != null else []
	check(row_children.size() == 10, "status row keeps three padded dividers and action divider")

	var separators := chip.find_children("*", "VSeparator", true, false)
	check(separators.size() == 4, "chip has three status dividers plus the action divider")

	for child_index in [1, 3, 5]:
		var padded_divider: MarginContainer = null
		if row_children.size() > child_index:
			padded_divider = row_children[child_index] as MarginContainer
		check(padded_divider != null, "status divider %d uses a MarginContainer" % child_index)
		if padded_divider == null:
			continue
		check(padded_divider.get_child_count() == 1 and padded_divider.get_child(0) is VSeparator,
			"status divider %d contains one VSeparator" % child_index)
		check(padded_divider.get_theme_constant("margin_left") == 16,
			"status divider %d has 16 px left padding" % child_index)
		check(padded_divider.get_theme_constant("margin_right") == 16,
			"status divider %d has 16 px right padding" % child_index)

	check(row_children.size() > 8 and row_children[8] is VSeparator,
		"existing divider remains before the workspace action")
	check(row_children.size() > 9 and row_children[9] == action,
		"workspace action remains the final row child")
```

The current implementation has only one `VSeparator` and seven row children, so this test must fail before the layout change.

- [ ] **Step 2: Run the focused test and confirm the expected failure**

Run:

```powershell
rtk powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\run_test.ps1 test_status_chip
```

Expected: the existing label/state checks pass, while the new row-size and separator-count checks fail.

- [ ] **Step 3: Commit the failing contract test**

```powershell
rtk git add tests/test_status_chip.gd
rtk git commit -m "test: specify status HUD divider layout"
```

---

### Task 2: Implement padded native status dividers

**Files:**
- Modify: `scenes/ui/status_chip.gd:7-47`

**Interfaces:**
- Consumes: The existing `HBoxContainer` row and four status labels.
- Produces: Three `MarginContainer` wrappers containing `VSeparator` controls, each with 16 px left/right theme margins, inserted between the labels.

- [ ] **Step 1: Add the divider margin constant and helper**

Add the constant beside the existing color constant:

```gdscript
const STATUS_DIVIDER_MARGIN := 16
```

Add this helper after `_build_children()`:

```gdscript
func _add_status_divider(row: HBoxContainer) -> void:
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", STATUS_DIVIDER_MARGIN)
	margin.add_theme_constant_override("margin_right", STATUS_DIVIDER_MARGIN)
	var divider := VSeparator.new()
	margin.add_child(divider)
	row.add_child(margin)
```

The wrapper owns only horizontal spacing and the native separator. Ignoring mouse input keeps the new non-interactive controls from changing existing action behavior.

- [ ] **Step 2: Insert the three wrappers without moving the action boundary**

Replace the contiguous status-label additions:

```gdscript
	row.add_child(_credits_label)
	row.add_child(_district_label)
	row.add_child(_day_label)
	row.add_child(_time_label)
```

with:

```gdscript
	row.add_child(_credits_label)
	_add_status_divider(row)
	row.add_child(_district_label)
	_add_status_divider(row)
	row.add_child(_day_label)
	_add_status_divider(row)
	row.add_child(_time_label)
```

Leave the following expanding spacer, existing direct `VSeparator`, and `WorkspaceAction` creation unchanged. This yields the row sequence `Label, MarginContainer, Label, MarginContainer, Label, MarginContainer, Label, Control, VSeparator, Button`.

- [ ] **Step 3: Run the focused test and confirm it passes**

Run:

```powershell
rtk powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\run_test.ps1 test_status_chip
```

Expected: `RESULT: ALL PASSED`, including four total separators, three padded status separators, and the preserved action divider.

- [ ] **Step 4: Commit the implementation**

```powershell
rtk git add scenes/ui/status_chip.gd tests/test_status_chip.gd
rtk git commit -m "feat: space status HUD fields"
```

---

### Task 3: Run regression checks and visual smoke test

**Files:**
- Verify: `scenes/ui/status_chip.gd`
- Verify: `tests/test_status_chip.gd`
- Verify: `scenes/main/main.gd`

**Interfaces:**
- Consumes: The completed `StatusChip` row layout.
- Produces: Evidence that HUD state updates, workspace collapse behavior, overall centering, and unrelated modules remain intact.

- [ ] **Step 1: Run the full existing headless suite**

Run:

```powershell
rtk powershell -NoProfile -Command "$tests = 'test_smoke','test_game_state','test_module_registry','test_theme','test_placeholder_data','test_status_chip','test_icon_rail','test_ticker_bar','test_panels_basic','test_contracts','test_main'; foreach ($test in $tests) { & .\tests\run_test.ps1 $test; if (`$LASTEXITCODE -ne 0) { exit `$LASTEXITCODE } }"
```

Expected: every test prints `RESULT: ALL PASSED` and the command exits successfully.

- [ ] **Step 2: Launch the actual Godot project for a HUD smoke check**

Run the project with the repository's Godot 4.7.1 executable:

```powershell
rtk powershell -NoProfile -Command "& 'C:\Users\merli\Documents\Godot Projects\Godot_v4.7.1-stable_win64_console.exe' --path ."
```

At the reference viewport, verify the visible top HUD has readable gaps around the three status dividers, retains the large gap before `COLLAPSE`, remains centered, and does not grow wider. Activate `COLLAPSE` and `EXPAND` once to confirm the existing action state still works.

- [ ] **Step 3: Check the final diff and commit only the intended files**

Run:

```powershell
rtk git diff --check
rtk git status --short
```

Expected: no whitespace errors; only the implementation/test changes remain beyond the already committed design and plan documents.
