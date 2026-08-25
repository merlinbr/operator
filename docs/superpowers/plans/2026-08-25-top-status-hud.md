# Top Status HUD Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the separate top-right collapse button with a thin, centered bracket-frame HUD that presents status fields and the collapse action as one horizontal strip.

**Architecture:** Keep `StatusChip` as the existing scene/class and expand it into the composite HUD. It presents credits, district, day, time, and a right-side action end-cap; it emits `collapse_requested` but never mutates workspace state. `Main` connects that intent to `GameState.toggle_workspace()`, while `GameState` remains the source of truth for collapsed state.

**Tech Stack:** Godot 4.7.1, GDScript, `.tscn` scenes, `.tres` Theme resources, headless `SceneTree` tests.

## Global Constraints

- Keep the existing `StatusChip` scene/class naming; do not rename it to `StatusHud`.
- Preserve the ownership model: `StatusChip` emits `collapse_requested`, `Main` calls `GameState.toggle_workspace()`, and `GameState` owns `workspace_collapsed`.
- Use the horizontal structure `status fields → flexible spacer → divider → action`.
- Use `COLLAPSE ▲` when expanded and `EXPAND ▼` when collapsed.
- Preserve warm amber/yellow credits emphasis; use muted text for normal status fields and cyan primarily for hover, focus, and interactive feedback.
- Keep the approved bracket frame, approximately 620–680 px wide and 36–40 px tall, centered through `Main._apply_layout()`.
- Do not change workspace/side-rail alignment; that is a separate follow-up.
- Do not add responsive breakpoints, a new HUD abstraction, new dependencies, or unrelated refactors.
- Run shell commands through `rtk` where applicable.

---

### Task 1: Make `StatusChip` the composite status/action HUD

**Files:**
- Modify: `scenes/ui/status_chip.gd`
- Test: `tests/test_status_chip.gd`

**Interfaces:**
- Consumes: `GameState` injected through the existing `setup(gs: Node)` method and its `credits_changed`, `clock_changed`, `district_changed`, and `workspace_collapsed_changed` signals.
- Produces: existing `setup(gs: Node)` behavior plus `signal collapse_requested`; a child `Button` named `WorkspaceAction` that exposes the integrated action.

- [ ] **Step 1: Extend the status-chip test with the new observable contract**

Replace the current two-label assumptions in `tests/test_status_chip.gd` with checks for four labels in order: `12,480 CR`, `LOWER VESPER`, `DAY 14`, and `23:41`. Find the action by its stable child name and verify its expanded presentation and intent signal:

```gdscript
var action := chip.find_child("WorkspaceAction", true, false) as Button
check(action != null, "integrated workspace action exists")
check(action.text == "COLLAPSE ▲", "expanded action label")
check(action.tooltip_text == "Collapse workspace", "expanded action tooltip")

var requested := false
chip.collapse_requested.connect(func() -> void: requested = true)
action.pressed.emit()
check(requested, "action emits collapse intent")
```

Add an independent initially-collapsed setup case. Set `initial_gs.workspace_collapsed` to `true` before adding and setting up a second chip, then assert immediately after `setup()`—without emitting another state signal—that the action reads `EXPAND ▼` and “Expand workspace”.

- [ ] **Step 2: Run the focused test and verify it fails for the missing HUD contract**

Run:

```powershell
rtk powershell -NoProfile -Command ".\tests\run_test.ps1 test_status_chip"
```

Expected: FAIL because the current chip has two labels, no `WorkspaceAction`, no `collapse_requested` signal, and no initial collapsed-state presentation.

- [ ] **Step 3: Replace the vertical chip internals with a horizontal composite row**

In `scenes/ui/status_chip.gd`:

1. Declare `signal collapse_requested` and replace `_loc_label` with `_district_label`, `_day_label`, `_time_label`, and `_collapse_button` references.
2. Keep `_build_children()` idempotent by retaining the existing guard and `setup(gs)` injection pattern.
3. Create one `HBoxContainer` as the panel child. Add four labels in order for credits, district, day, and time. Preserve the current warm amber override on credits and use the default muted label color for the other fields.
4. Add an expanding `Control` after the status labels, then a `VSeparator` divider, then a `Button` named `WorkspaceAction`. Set the button to flat/quiet presentation, keep keyboard focus enabled, set its tooltip, and connect `pressed` to `collapse_requested.emit`.
5. In `setup(gs)`, connect all four state signals, initialize all four fields from current state, and call `_on_workspace_collapsed(_gs.workspace_collapsed)` before returning. This immediate call is required when setup starts with a collapsed state.
6. Format clock updates as separate fields: `DAY %d` from the signal’s day argument and `gs.clock_text()` for time. District updates only the district field.
7. Implement `_on_workspace_collapsed(collapsed: bool)` so `true` sets `EXPAND ▼` / “Expand workspace” and `false` sets `COLLAPSE ▲` / “Collapse workspace”.

Do not rename the scene, script, or class. Do not call `GameState` globally.

- [ ] **Step 4: Run the focused test and verify the composite chip passes**

Run:

```powershell
rtk powershell -NoProfile -Command ".\tests\run_test.ps1 test_status_chip"
```

Expected: `RESULT: ALL PASSED`, including four field values, credit/clock updates, action intent, and initial collapsed-state initialization.

- [ ] **Step 5: Commit the self-contained chip change**

```powershell
rtk git add scenes/ui/status_chip.gd tests/test_status_chip.gd
rtk git commit -m "feat: compose status chip with workspace action"
```

---

### Task 2: Wire the integrated action into `Main` and remove the floating button

**Files:**
- Modify: `scenes/main/main.gd`
- Test: `tests/test_main.gd`

**Interfaces:**
- Consumes: `StatusChip.collapse_requested` and the `WorkspaceAction` child created in Task 1.
- Produces: one centered top HUD with unchanged `GameState` collapse semantics and no `CollapseToggle` node.

- [ ] **Step 1: Update the main-scene test for the integrated action**

Replace the existing “collapse button is a labeled button” assertions in `tests/test_main.gd` with checks against `StatusChip`:

```gdscript
var status_chip: Control = workspace.get_node("StatusChip")
check(workspace.get_node_or_null("CollapseToggle") == null, "no separate collapse button")
var action := status_chip.find_child("WorkspaceAction", true, false) as Button
check(action != null and action.text == "COLLAPSE ▲", "integrated action starts expanded")
action.pressed.emit()
check(gs.workspace_collapsed, "integrated action collapses workspace")
check(action.text == "EXPAND ▼", "integrated action shows expand state")
action.pressed.emit()
check(not gs.workspace_collapsed, "integrated action expands workspace")
check(status_chip.size.x > status_chip.size.y, "HUD is wider than tall")
check(absf(status_chip.position.x - (ws.x - status_chip.size.x) * 0.5) < 1.0,
	"HUD remains centered")
```

Keep the existing checks that collapse leaves `StatusChip`, `IconRail`, and `TickerBar` visible, and keep the existing module/Esc behavior checks unchanged.

- [ ] **Step 2: Run the main-scene test and verify it fails against the old floating button**

Run:

```powershell
rtk powershell -NoProfile -Command ".\tests\run_test.ps1 test_main"
```

Expected: FAIL because `Main` still creates `CollapseToggle` and the integrated action is not connected.

- [ ] **Step 3: Remove the standalone button and connect the chip signal**

In `scenes/main/main.gd`:

1. Delete the `collapse_button` member and `_build_collapse_button()` function.
2. Remove `_build_collapse_button()` from `_build_shell()`.
3. Replace the button connection with `status_chip.collapse_requested.connect(func() -> void: gs.toggle_workspace())`.
4. Remove the standalone button’s position/size calculation from `_apply_layout()`. Continue centering `status_chip` using `get_combined_minimum_size()` and the existing `CHIP_TOP` offset.
5. Remove the button text and tooltip updates from `_apply_visibility()`; the chip now owns those presentation updates.
6. Leave panel visibility, module selection, context layout, ticker placement, and collapse tween behavior unchanged.

- [ ] **Step 4: Run the main-scene test and verify integration**

Run:

```powershell
rtk powershell -NoProfile -Command ".\tests\run_test.ps1 test_main"
```

Expected: `RESULT: ALL PASSED`, including no `CollapseToggle`, action-driven collapse/expand, preserved panel visibility semantics, and surviving HUD/rail/ticker.

- [ ] **Step 5: Commit the Main integration**

```powershell
rtk git add scenes/main/main.gd tests/test_main.gd
rtk git commit -m "feat: integrate workspace action into top HUD"
```

---

### Task 3: Apply the bracket-frame sizing and theme treatment

**Files:**
- Modify: `scenes/ui/status_chip.tscn` — set the approved 640×38 custom minimum size.
- Modify: `resources/operator_theme.tres`

**Interfaces:**
- Consumes: the composite row and action behavior from Tasks 1–2.
- Produces: a centered, thin, quiet HUD footprint and bracket-frame visual treatment without changing interaction or state ownership.

- [ ] **Step 1: Set the approved HUD minimum footprint**

In `scenes/ui/status_chip.tscn`, set the root `StatusChip` custom minimum size to `Vector2(640, 38)`. Keep the scene name and script resource unchanged. This places the implementation inside the approved 620–680 px by 36–40 px range while letting `Main._apply_layout()` continue to center it from its combined minimum size.

- [ ] **Step 2: Tune only the existing StatusChip theme style**

In `resources/operator_theme.tres`, adjust the existing `sbf_chip` resource rather than adding a new theme family:

- retain the existing dark panel palette and one-pixel muted border;
- reduce vertical content margins enough to keep the row near 38 px high;
- use square or near-square corners for the bracket-frame read;
- keep normal `Label` text muted;
- leave the existing warm amber `COLOR_AMBER` override in `status_chip.gd` as the credits emphasis;
- keep existing `Button` hover/focus cyan as interactive feedback, while the action’s flat resting state remains quiet.

Do not change unrelated panel, button, ticker, or module styles.

- [ ] **Step 3: Re-run the changed headless tests after visual sizing changes**

Run:

```powershell
rtk powershell -NoProfile -Command ".\tests\run_test.ps1 test_status_chip"
rtk powershell -NoProfile -Command ".\tests\run_test.ps1 test_main"
```

Expected: both print `RESULT: ALL PASSED`; the sizing/theme changes must not alter state transitions or test harness construction.

- [ ] **Step 4: Run the full documented headless suite**

Run each documented test through the existing runner:

```powershell
rtk powershell -NoProfile -Command ".\tests\run_test.ps1 test_smoke"
rtk powershell -NoProfile -Command ".\tests\run_test.ps1 test_game_state"
rtk powershell -NoProfile -Command ".\tests\run_test.ps1 test_module_registry"
rtk powershell -NoProfile -Command ".\tests\run_test.ps1 test_theme"
rtk powershell -NoProfile -Command ".\tests\run_test.ps1 test_placeholder_data"
rtk powershell -NoProfile -Command ".\tests\run_test.ps1 test_status_chip"
rtk powershell -NoProfile -Command ".\tests\run_test.ps1 test_icon_rail"
rtk powershell -NoProfile -Command ".\tests\run_test.ps1 test_ticker_bar"
rtk powershell -NoProfile -Command ".\tests\run_test.ps1 test_panels_basic"
rtk powershell -NoProfile -Command ".\tests\run_test.ps1 test_contracts"
rtk powershell -NoProfile -Command ".\tests\run_test.ps1 test_main"
```

Expected: every command prints `RESULT: ALL PASSED` and exits successfully.

- [ ] **Step 5: Launch the actual project for visual smoke verification**

Run the project with the configured Godot executable:

```powershell
rtk powershell -NoProfile -Command "& 'C:\Users\merli\Documents\Godot Projects\Godot_v4.7.1-stable_win64.exe' --path 'C:\Users\merli\Documents\Godot Projects\operator'"
```

At the 1920×1080 viewport, verify the top HUD is centered, approximately 640×38, visibly wider than tall, framed by a thin square-corner outline, and visually quiet. Verify the left/center fields remain grouped, the flexible space pushes the divider/action to the right end-cap, credits remain warm amber, normal fields are muted, and the action changes between `COLLAPSE ▲` and `EXPAND ▼` when activated.

- [ ] **Step 6: Commit the visual treatment**

```powershell
rtk git add scenes/ui/status_chip.tscn resources/operator_theme.tres
rtk git commit -m "style: flatten top status HUD frame"
```

## Final Review Checklist

- [ ] `StatusChip` remains the scene/script/class name.
- [ ] No `CollapseToggle` node or duplicate collapse behavior remains.
- [ ] `StatusChip` only emits `collapse_requested`; `Main` calls `GameState.toggle_workspace()`.
- [ ] Expanded action is `COLLAPSE ▲`; collapsed action is `EXPAND ▼`.
- [ ] Initial collapsed setup immediately presents `EXPAND ▼` and the expand tooltip.
- [ ] Credits remain warm amber/yellow; cyan is reserved for interactive feedback.
- [ ] Horizontal structure is status fields → flexible spacer → divider → action.
- [ ] Bracket-frame HUD is centered and approximately 640×38 px.
- [ ] Workspace/side-rail alignment remains untouched.
