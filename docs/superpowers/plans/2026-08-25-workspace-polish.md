# Workspace Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the "floating UI over environment" concept hold by fixing the module navigation/interaction model, constraining panel proportions so the environment stays visible, and refining the rain into subtle depth layers.

**Architecture:** All state for the workspace interaction lives in the existing `GameState` autoload (two new change-guarded fields + signals). `main.gd` remains the single owner of module switching, visibility, and layout; it gains one Esc entry point and a labeled Collapse button. `icon_rail`'s `set_active` gains a `lit` flag so main drives the highlight. Panel sizes become class-driven (a `size_class` on `ModuleDef`) via a fraction table in `main.gd`, replacing the `CONTEXT_SPLIT` ratio. Rain is a single rewrite of `rain.gdshader` into three summed O(1) layer evaluations.

**Tech Stack:** Godot 4.7.1 (GDScript, typed), Control-based UI, code-built UI trees inside minimal `.tscn` files, headless script tests via `godot --headless --script` (no addons).

**Spec:** `docs/superpowers/specs/2026-08-25-workspace-polish-design.md`

## Global Constraints

- Engine: Godot 4.7.1. Console executable on this machine:
  `$godot = "C:\Users\merli\Documents\Godot Projects\Godot_v4.7.1-stable_win64_console.exe"`
  Project root: `"C:\Users\merli\Documents\Godot Projects\operator"`
- GDScript: Godot 4.x syntax, statically typed where practical. No addons, no plugins, no new autoloads beyond `GameState`.
- **Component pattern (existing):** `.tscn` files contain only a root node + script; children are built in `_ready()`. Components expose `setup(...)` MUST be called after the node is in the tree. Components never reference the `GameState` autoload identifier — they receive the state node via `setup()`.
- **State pattern:** `GameState` setters emit their signal **only on change**, guarded exactly like `set_workspace_collapsed()` (not the unconditional property setters used by credits/heat).
- **Two distinct states (verbatim from spec):** per-module close (`module_open`) is separate from global collapse (`workspace_collapsed`). Toggling a module closed does **not** change `workspace_collapsed`; collapse preserves `module_open`.
- **Size classes** — fraction of the inset content region, defined once as a const table in `main.gd`: `compact` 0.34×0.46 · `narrow` 0.44×0.68 · `normal` 0.60×0.72 · `wide` 0.78×0.82 · `context` 0.31 (height mirrors primary). Assignments: home→`compact`, comms→`normal`, contracts→`narrow`. `alerts` has no scene this slice → no size class.
- **`CONTEXT_SPLIT` is removed.** The "primary shrinks when context opens" rule is deferred (no `wide` module exists); dropping it is part of the clean cutover.
- **Rain:** rewrite `rain.gdshader` to three summed O(1) layer evaluations (Near/Mid/Far), not a drop loop. Slant kept broadly consistent across layers; depth from speed/thickness/length/density/alpha. Layers **sum**, not max.
- Display: 1920×1080 reference, `canvas_items` stretch, `expand` aspect. Must remain clean at 1280×720. No responsive work below 1280×720.
- Placeholder game content lives ONLY in `res://data/placeholder/`.
- Testing: TDD with headless script tests. Test scripts extend `res://tests/test_base.gd`. Run one test:
  `.\tests\run_test.ps1 <test_name>` (runs `res://tests/<test_name>.gd`). Expected final line: `RESULT: ALL PASSED`, exit code 0.
- Commit after every task with the exact message given in the task.
- Visual-only deliverables (rain) are verified by running the project:
  `& $godot --path "C:\Users\merli\Documents\Godot Projects\operator"` (opens a window; close it manually).

---

## File Structure

- `autoload/game_state.gd` — add `active_module`, `module_open`, `set_active_module()`, `set_module_open()`, and two signals. State source of truth.
- `scenes/main/main.gd` — the single owner of switching, visibility, Esc, the labeled collapse button, and the class-driven layout. Two sequential edits (nav in Task 4, sizing in Task 5).
- `scenes/ui/icon_rail.gd` — `set_active(id, lit)`.
- `scripts/module_def.gd` — add `size_class`.
- `resources/module_registry.tres` — set `size_class` on home/comms/contracts defs.
- `scenes/main/rain.gdshader` — three-layer summed rain.
- Tests: `test_game_state.gd`, `test_module_registry.gd`, `test_icon_rail.gd`, `test_main.gd`.

---

### Task 1: GameState module-open state

**Files:**
- Modify: `autoload/game_state.gd` (after `workspace_collapsed`, add signals + fields + setters)
- Test: `tests/test_game_state.gd`

**Interfaces:**
- Consumes: nothing new (existing `workspace_collapsed`, `set_workspace_collapsed`).
- Produces: `active_module: StringName`, `module_open: bool`, `signal active_module_changed(id: StringName)`, `signal module_open_changed(open: bool)`, `func set_active_module(id: StringName) -> void`, `func set_module_open(open: bool) -> void`. Both setters are change-guarded (no-op + no emit if value unchanged).

- [ ] **Step 1: Write the failing test** — append to `tests/test_game_state.gd` before the final `gs.free()`:

```gdscript
	var active_seen := [&""]
	gs.active_module_changed.connect(func(id: StringName) -> void: active_seen[0] = id)
	gs.set_active_module(&"comms")
	check(gs.active_module == &"comms", "set_active_module sets active")
	check(active_seen[0] == &"comms", "active_module_changed emitted")
	gs.set_active_module(&"comms")
	check(active_seen[0] == &"comms", "no duplicate emit for same active module")

	var open_seen := [false]
	gs.module_open_changed.connect(func(o: bool) -> void: open_seen[0] = o)
	gs.set_module_open(true)
	check(gs.module_open and open_seen[0], "set_module_open(true) emits")
	gs.set_module_open(true)
	check(open_seen[0], "no duplicate emit for same open state")
	gs.set_module_open(false)
	check(gs.module_open == false and open_seen[0] == false, "set_module_open(false) closes")
```

- [ ] **Step 2: Run it to verify it fails**

Run: `.\tests\run_test.ps1 test_game_state`
Expected: FAIL lines for the new checks (setters don't exist yet → error) and not `RESULT: ALL PASSED`.

- [ ] **Step 3: Implement** — add to `autoload/game_state.gd`, following the existing `workspace_collapsed`/`set_workspace_collapsed` pattern:

```gdscript
signal active_module_changed(id: StringName)
signal module_open_changed(open: bool)

var active_module: StringName = &""
var module_open := false

func set_active_module(id: StringName) -> void:
	if active_module == id:
		return
	active_module = id
	active_module_changed.emit(id)

func set_module_open(open: bool) -> void:
	if module_open == open:
		return
	module_open = open
	module_open_changed.emit(open)
```

- [ ] **Step 4: Run it to verify it passes**

Run: `.\tests\run_test.ps1 test_game_state`
Expected: `RESULT: ALL PASSED`, exit code 0.

- [ ] **Step 5: Commit**

```bash
git add autoload/game_state.gd tests/test_game_state.gd
git commit -m "feat: add active_module/module_open state to GameState"
```

---

### Task 2: ModuleDef `size_class`

**Files:**
- Modify: `scripts/module_def.gd`
- Modify: `resources/module_registry.tres`
- Test: `tests/test_module_registry.gd`

**Interfaces:**
- Consumes: nothing.
- Produces: `ModuleDef.size_class: StringName` (default `&"normal"`), and registry defs for `home`=`&"compact"`, `comms`=`&"normal"`, `contracts`=`&"narrow"`. `alerts` and locked modules keep the default (no explicit value). `contract_detail` is not a `ModuleDef` and is not in the registry.

- [ ] **Step 1: Write the failing test** — append to `tests/test_module_registry.gd` before the end of `_run()`:

```gdscript
	var home2 := reg.get_module(&"home")
	check(home2.size_class == &"compact", "home is compact")
	check(reg.get_module(&"comms").size_class == &"normal", "comms is normal")
	check(reg.get_module(&"contracts").size_class == &"narrow", "contracts is narrow")
	check(reg.get_module(&"crew").size_class == &"normal", "locked module defaults to normal")
```

- [ ] **Step 2: Run it to verify it fails**

Run: `.\tests\run_test.ps1 test_module_registry`
Expected: FAIL (size_class property doesn't exist / defaults).

- [ ] **Step 3: Implement** — add to `scripts/module_def.gd`:

```gdscript
@export var size_class: StringName = &"normal" # compact | narrow | normal | wide | context
```

Then in `resources/module_registry.tres`, add `size_class = &"compact"` inside `def_home`, `size_class = &"normal"` inside `def_comms`, and `size_class = &"narrow"` inside `def_contracts`.

- [ ] **Step 4: Run it to verify it passes**

Run: `.\tests\run_test.ps1 test_module_registry`
Expected: `RESULT: ALL PASSED`, exit code 0.

- [ ] **Step 5: Commit**

```bash
git add scripts/module_def.gd resources/module_registry.tres tests/test_module_registry.gd
git commit -m "feat: add size_class to module definitions"
```

---

### Task 3: `icon_rail.set_active(id, lit)`

**Files:**
- Modify: `scenes/ui/icon_rail.gd`
- Test: `tests/test_icon_rail.gd`

**Interfaces:**
- Consumes: nothing new.
- Produces: `func set_active(id: StringName, lit: bool = true) -> void`. `lit == true` highlights the active (non-locked) button cyan; `lit == false` leaves it in its normal (white / locked-dim) state. `_active` is still tracked so a later `set_active` on the same id re-highlights it. Locked buttons stay dimmed regardless.
- Backwards-compatible default `lit = true` so the existing `main.gd` call site (`icon_rail.set_active(id)`) keeps working until Task 4.

- [ ] **Step 1: Write the failing test** — update `tests/test_icon_rail.gd` lines 31-35 (replace the `set_active` calls):

```gdscript
	rail.set_active(&"comms", true)
	var comms_btn: Button = rail.get_button(&"comms")
	check(comms_btn.modulate == Color(0.22353, 0.81569, 1.0), "active+lit module highlighted cyan")
	check(home_btn.modulate == Color.WHITE, "previous unlocked module unhighlighted")
	check(crew_btn.modulate == Color(1.0, 1.0, 1.0, 0.4), "locked module stays dimmed")

	rail.set_active(&"comms", false)
	check(comms_btn.modulate == Color.WHITE, "active but unlit module not highlighted")
```

- [ ] **Step 2: Run it to verify it fails**

Run: `.\tests\run_test.ps1 test_icon_rail`
Expected: FAIL (second arg `lit` not accepted by `set_active`).

- [ ] **Step 3: Implement** — change `set_active` in `scenes/ui/icon_rail.gd`:

```gdscript
func set_active(id: StringName, lit: bool = true) -> void:
	_active = id
	for btn_id: StringName in _buttons:
		var btn: Button = _buttons[btn_id]
		if btn_id == _active and lit:
			btn.modulate = COLOR_ACCENT
		elif btn.disabled:
			btn.modulate = COLOR_LOCKED_DIM
		else:
			btn.modulate = Color.WHITE
```

- [ ] **Step 4: Run it to verify it passes**

Run: `.\tests\run_test.ps1 test_icon_rail`
Expected: `RESULT: ALL PASSED`, exit code 0.

- [ ] **Step 5: Commit**

```bash
git add scenes/ui/icon_rail.gd tests/test_icon_rail.gd
git commit -m "feat: icon_rail.set_active takes a lit flag"
```

---

### Task 4: Navigation + visibility + Esc + labeled collapse button

**Files:**
- Modify: `scenes/main/main.gd`
- Test: `tests/test_main.gd`

**Interfaces:**
- Consumes: `gs.module_open`, `gs.active_module`, `gs.set_active_module(id)`, `gs.set_module_open(open)` (Task 1); `icon_rail.set_active(id, lit)` (Task 3).
- Produces: `func select_module(id: StringName) -> void` (rail click entry point; toggles/opens), `func close_topmost() -> void`, `func open_context(content: Control) -> void`, `func close_context() -> void`. `primary_host.visible = !collapsed && module_open`, `context_host.visible = !collapsed && module_open && context_host.child_count > 0`. The collapse button is labeled `"Collapse Workspace"` / `"Expand Workspace"`.

> This task keeps the existing `_apply_layout` (size logic unchanged); sizing is Task 5. `select_module` is fully rewritten here; the old `icon_rail.set_active(id)` call it contained is replaced by `set_active(id, lit)`.

- [ ] **Step 1: Write the failing test** — replace the body of `_run()` in `tests/test_main.gd`:

```gdscript
func _run() -> void:
	var gs := GameStateScript.new()
	gs.name = "GameState"
	root.add_child(gs)

	var main := MainScene.instantiate()
	root.add_child(main)

	var workspace: Control = main.get_node("Workspace")
	var primary: Control = workspace.get_node("PrimaryHost")
	var context: Control = workspace.get_node("ContextHost")

	check(main.theme != null, "theme applied at Main root")
	check(primary.get_child_count() == 1, "home panel active on start")
	check(primary.visible, "home panel visible on start")
	check(gs.active_module == &"home", "active module is home")
	check(gs.module_open, "module starts open")

	# active icon toggles its module closed
	main.select_module(&"home")
	check(not primary.visible, "active icon toggles panel closed")
	check(gs.module_open == false, "module_open false after toggle")
	check(gs.workspace_collapsed == false, "toggle-close does not collapse workspace")
	check(gs.active_module == &"home", "active_module stays set while closed")

	# clicking the same (closed) active reopens it
	main.select_module(&"home")
	check(primary.visible and gs.module_open, "clicking closed active reopens it")

	# different icon switches modules
	main.select_module(&"contracts")
	check(primary.get_child(0).name == "ContractsPanel", "module switching swaps panel")
	check(gs.active_module == &"contracts", "active module is contracts")

	# context opens alongside primary
	main.open_context(load("res://scenes/modules/contracts/contract_detail.tscn").instantiate())
	check(context.visible and context.get_child_count() == 1, "context opens with content")

	# Esc closes context first
	main.close_topmost()
	check(not context.visible, "Esc closes context first")

	# Esc closes primary next
	main.close_topmost()
	check(not primary.visible and gs.module_open == false, "Esc closes primary next")

	# Esc does nothing when nothing is open
	main.close_topmost()
	check(not primary.visible, "Esc does nothing when nothing is open")

	# global collapse hides all panels; chrome survives
	gs.set_workspace_collapsed(true)
	check(not primary.visible, "collapse hides primary panel")
	check(not context.visible, "collapse hides context panel")
	check(workspace.get_node("StatusChip").visible, "chip survives collapse")
	check(workspace.get_node("IconRail").visible, "rail survives collapse")
	check(workspace.get_node("TickerBar").visible, "ticker survives collapse")

	# expand preserves module_open state
	gs.set_workspace_collapsed(false)
	check(not primary.visible, "expand does not reopen a closed module")
	check(gs.module_open == false, "expand preserves module_open")

	# selecting a module while collapsed un-collapses and opens that module
	main.select_module(&"comms")
	check(not gs.workspace_collapsed, "selecting a module un-collapses")
	check(primary.visible and primary.get_child(0).name == "CommsPanel", "comms open after un-collapse")
	check(gs.module_open, "module open after un-collapse")

	# collapse button is a labeled button
	var collapse_btn: Button = workspace.get_node("CollapseToggle")
	check(collapse_btn.text == "Collapse Workspace", "collapse button labeled")

	main.queue_free()
	gs.queue_free()
```

- [ ] **Step 2: Run it to verify it fails**

Run: `.\tests\run_test.ps1 test_main`
Expected: FAIL (toggle/visibility/Esc not implemented; `select_module` still always opens).

- [ ] **Step 3: Implement** — rewrite the relevant parts of `scenes/main/main.gd`:

Replace `select_module` (and add helpers):

```gdscript
func select_module(id: StringName) -> void:
	if not MODULE_SCENES.has(id):
		return # scene-less module (e.g. alerts): no-op
	var was_collapsed := gs.workspace_collapsed
	if was_collapsed:
		gs.set_workspace_collapsed(false)
	if not was_collapsed and gs.active_module == id and gs.module_open:
		gs.set_module_open(false) # toggle closed — active_module stays set
		close_context()
		return
	gs.set_active_module(id)
	gs.set_module_open(true)
	_build_primary_module(id)

func _build_primary_module(id: StringName) -> void:
	close_context()
	for child in primary_host.get_children():
		primary_host.remove_child(child)
		child.queue_free()
	var panel: Control = MODULE_SCENES[id].instantiate()
	primary_host.add_child(panel)
	if id == &"contracts":
		panel.contract_selected.connect(_on_contract_selected)
		panel.setup(gs, PlaceholderContracts.all())
	else:
		panel.setup(gs, PlaceholderMessages.all() if id == &"comms" else null)
	_apply_visibility()

func close_topmost() -> void:
	if gs.workspace_collapsed:
		return # nothing visible to close
	if context_host.visible and context_host.get_child_count() > 0:
		close_context()
	elif gs.module_open:
		gs.set_module_open(false)
		_apply_visibility()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		close_topmost()
		get_viewport().set_input_as_handled()
```

Change `open_context` / `close_context` to route visibility through `_apply_visibility`:

```gdscript
func open_context(content: Control) -> void:
	for child in context_host.get_children():
		context_host.remove_child(child)
		child.queue_free()
	context_host.add_child(content)
	_apply_visibility()

func close_context() -> void:
	for child in context_host.get_children():
		context_host.remove_child(child)
		child.queue_free()
	_apply_visibility()
```

Replace `_apply_workspace_visibility` with a unified `_apply_visibility`, and update `_on_collapsed_changed`:

```gdscript
func _on_collapsed_changed(collapsed: bool) -> void:
	_apply_visibility()
	if collapsed:
		return
	if not is_inside_tree():
		return # headless: no SceneTree to tween against
	var tween := create_tween()
	primary_host.modulate.a = 0.0
	tween.tween_property(primary_host, "modulate:a", 1.0, 0.15)

func _apply_visibility() -> void:
	var collapsed: bool = gs.workspace_collapsed
	primary_host.visible = not collapsed and gs.module_open
	context_host.visible = not collapsed and gs.module_open and context_host.get_child_count() > 0
	collapse_button.text = "Expand Workspace" if collapsed else "Collapse Workspace"
	collapse_button.tooltip_text = "Expand workspace" if collapsed else "Collapse workspace"
	if icon_rail.has_method("set_active"):
		icon_rail.set_active(gs.active_module, gs.module_open and not collapsed)
	_apply_layout()
```

Update `_build_collapse_button` to start labeled and remove `_apply_workspace_visibility` (deleted):

```gdscript
func _build_collapse_button() -> void:
	collapse_button = Button.new()
	collapse_button.name = "CollapseToggle"
	collapse_button.text = "Collapse Workspace"
	collapse_button.tooltip_text = "Collapse workspace"
	collapse_button.focus_mode = Control.FOCUS_NONE
	collapse_button.custom_minimum_size = Vector2(32, 32)
	workspace.add_child(collapse_button)
```

Update the connections in `_build_shell` (add the two new signal connections; `select_module` stays connected to `module_selected`):

```gdscript
	gs.workspace_collapsed_changed.connect(_on_collapsed_changed)
	gs.active_module_changed.connect(func(_id: StringName) -> void: _apply_visibility())
	gs.module_open_changed.connect(func(_open: bool) -> void: _apply_visibility())
	gs.ticker_message.connect(func(text: String, highlight: bool) -> void: ticker.push_message(text, highlight))
	icon_rail.module_selected.connect(select_module)
	collapse_button.pressed.connect(func() -> void: gs.toggle_workspace())
```

In `_build_shell`, the final calls become:

```gdscript
	select_module(&"home")
	_apply_layout()
	workspace.resized.connect(_apply_layout)
```

(`select_module(&"home")` now emits the module signals which call `_apply_visibility`; the explicit `_apply_layout` here ensures the panel is sized once, and the old second `_apply_layout()` call is removed.)

- [ ] **Step 4: Run it to verify it passes**

Run: `.\tests\run_test.ps1 test_main`
Expected: `RESULT: ALL PASSED`, exit code 0.

- [ ] **Step 5: Commit**

```bash
git add scenes/main/main.gd tests/test_main.gd
git commit -m "feat: module toggle, Esc, visibility and labeled collapse button"
```

---

### Task 5: Class-driven panel sizing (remove CONTEXT_SPLIT)

**Files:**
- Modify: `scenes/main/main.gd` (constants + `_apply_layout`)
- Test: `tests/test_main.gd`

**Interfaces:**
- Consumes: `gs.active_module` and the `ModuleDef.size_class` values (Task 2) via the registry. `ModuleDef` instances are read from `load("res://resources/module_registry.tres")`.
- Produces: `const SIZE_CLASSES := {...}` table, `const PANEL_INSET := 18.0`. Primary panel sized to its module's class; context panel at `context` width (~0.31), height mirroring the primary. `CONTEXT_SPLIT` is deleted.

- [ ] **Step 1: Write the failing test** — make two precise edits to `tests/test_main.gd`.

**Edit A** — right after the `check(gs.module_open, "module starts open")` line in the Task 4 test (home is still the active module here), insert:

```gdscript
	var ws: Vector2 = workspace.size if workspace.size.x > 0 else Vector2(1920, 1080)
	check(primary.size.x < ws.x * 0.5, "home width is compact")
	check(primary.size.y < ws.y * 0.6, "home height is compact")
```

**Edit B** — replace the "context opens alongside primary" block in the Task 4 test with:

```gdscript
	# context opens alongside primary (primary keeps its class width)
	var primary_w: float = primary.size.x
	main.open_context(load("res://scenes/modules/contracts/contract_detail.tscn").instantiate())
	check(context.visible and context.get_child_count() == 1, "context opens with content")
	check(absf(primary.size.x - primary_w) < 1.0, "primary keeps class width when context opens")
	check(primary.position.x + primary.size.x + context.size.x < workspace.size.x,
		"environment remains visible to the right of panels")
```

- [ ] **Step 2: Run it to verify it fails**

Run: `.\tests\run_test.ps1 test_main`
Expected: FAIL (home still fills region; primary still shrinks via CONTEXT_SPLIT).

- [ ] **Step 3: Implement** — in `scenes/main/main.gd`, add the size-class table near the other constants:

```gdscript
const SIZE_CLASSES := {
	&"compact": Vector2(0.34, 0.46),
	&"narrow": Vector2(0.44, 0.68),
	&"normal": Vector2(0.60, 0.72),
	&"wide": Vector2(0.78, 0.82),
	&"context": Vector2(0.31, 0.0), # height mirrors the primary
}
const PANEL_INSET := 18.0
```

Add a `_size_class(id)` helper and rewrite `_apply_layout` (replacing the `CONTEXT_SPLIT` branch and the old primary/context sizing):

```gdscript
func _size_class(id: StringName) -> Vector2:
	var reg := load("res://resources/module_registry.tres") as ModuleRegistry
	var def := reg.get_module(id) if reg != null else null
	var cls: StringName = def.size_class if def != null else &"normal"
	return SIZE_CLASSES.get(cls, SIZE_CLASSES[&"normal"])

func _apply_layout() -> void:
	var ws_size: Vector2 = workspace.size if workspace.size.x > 0.0 else Vector2(1920, 1080)
	var chip_min: Vector2 = status_chip.get_combined_minimum_size()
	status_chip.position = Vector2((ws_size.x - chip_min.x) * 0.5, CHIP_TOP)
	status_chip.size = chip_min
	collapse_button.position = Vector2(ws_size.x - MARGIN - collapse_button.custom_minimum_size.x, CHIP_TOP)
	var content_top: float = CHIP_TOP + status_chip.size.y + CHIP_GAP
	var content_bottom: float = ws_size.y - TICKER_HEIGHT - MARGIN
	icon_rail.position = Vector2(MARGIN, content_top)
	icon_rail.size = Vector2(RAIL_WIDTH, content_bottom - content_top)
	ticker.position = Vector2(0.0, ws_size.y - TICKER_HEIGHT)
	ticker.size = Vector2(ws_size.x, TICKER_HEIGHT)

	var r_left: float = MARGIN + RAIL_WIDTH + RAIL_GAP + PANEL_INSET
	var r_top: float = content_top + PANEL_INSET
	var r_right: float = ws_size.x - MARGIN - PANEL_INSET
	var r_bottom: float = content_bottom - PANEL_INSET
	var r_w: float = r_right - r_left
	var r_h: float = r_bottom - r_top

	var p_class: Vector2 = _size_class(gs.active_module)
	var p_w: float = r_w * p_class.x
	var p_h: float = r_h * p_class.y
	primary_host.position = Vector2(r_left, r_top)
	primary_host.size = Vector2(maxf(p_w, 0.0), maxf(p_h, 0.0))

	var ctx_open: bool = context_host.visible and context_host.get_child_count() > 0
	if ctx_open:
		var c_class: Vector2 = SIZE_CLASSES[&"context"]
		var c_w: float = r_w * c_class.x
		context_host.position = Vector2(r_left + primary_host.size.x + CONTEXT_GAP, r_top)
		context_host.size = Vector2(c_w, primary_host.size.y) # height mirrors primary

	for panel in primary_host.get_children():
		panel.size = primary_host.size
	for panel in context_host.get_children():
		panel.size = context_host.size
```

Delete the `CONTEXT_SPLIT` constant (line ~27).

- [ ] **Step 4: Run it to verify it passes**

Run: `.\tests\run_test.ps1 test_main`
Expected: `RESULT: ALL PASSED`, exit code 0.

- [ ] **Step 5: Commit**

```bash
git add scenes/main/main.gd tests/test_main.gd
git commit -m "feat: class-driven panel sizing; remove CONTEXT_SPLIT"
```

---

### Task 6: Three-layer rain shader

**Files:**
- Modify: `scenes/main/rain.gdshader`
- Verify: run the project (visual only — no logic test; deliberate simplification)

**Interfaces:**
- Consumes: `environment.gd` already attaches this shader to a full-rect `ColorRect` and applies no parameters; the `intensity` uniform stays the master knob.
- Produces: an unchanged `uniform float intensity` (default 0.5), and a full-screen rain composed of three summed O(1) layer evaluations drawn in `fragment()`.

- [ ] **Step 1: Replace the shader** — write `scenes/main/rain.gdshader`:

```glsl
shader_type canvas_item;

uniform float intensity : hint_range(0.0, 1.0) = 0.5;

float hash1(float x) {
	return fract(sin(x) * 43758.5453);
}

// One O(1) rain layer: grid of columns (not loops over drops).
// Returns an alpha contribution 0..1.
float rain_layer(vec2 uv, float density, float slant, float speed_base,
		float speed_var, float len_base, float len_var, float width_frac,
		float alpha, float seed) {
	vec2 p = vec2(uv.x - uv.y * slant, uv.y);
	float cell = 1.0 / density;
	float remainder = mod(p.x, cell);
	float cell_x = p.x - remainder;
	float rn = hash1(cell_x * density + seed);
	float speed = speed_base + speed_var * rn;
	float length = len_base + len_var * rn;
	float y = fract(p.y + rn);
	float trail = smoothstep(1.0 - length, 1.0, fract(y - TIME * speed));
	float thickness = step(remainder * density, width_frac);
	return trail * thickness * alpha;
}

void fragment() {
	vec2 uv = UV;
	float a = 0.0;
	a += rain_layer(uv, 140.0, 0.05, 2.2, 0.8, 0.08, 0.04, 0.15, 0.10, 1.0);  // near
	a += rain_layer(uv, 220.0, 0.045, 1.4, 0.8, 0.055, 0.03, 0.10, 0.06, 7.0); // mid
	a += rain_layer(uv, 320.0, 0.04, 0.8, 0.8, 0.035, 0.02, 0.06, 0.035, 13.0); // far
	COLOR = vec4(0.706, 0.863, 1.0, a * intensity);
}
```

- [ ] **Step 2: Verify it compiles and looks right** — run the project:

```bash
& "C:\Users\merli\Documents\Godot Projects\Godot_v4.7.1-stable_win64_console.exe" --path "C:\Users\merli\Documents\Godot Projects\operator"
```

Open a window; check the console for shader compile errors. Confirm the rain is thin, short, numerous, faint, angled, varied, and depth-layered. Tune the per-layer constants (density, alpha, length, width_frac, slant) if needed — they are deliberately collected in the three `rain_layer` calls. (`Intensity`, alpha and width are set low on purpose; increase from there if it's too subtle.)

- [ ] **Step 3: Commit**

```bash
git add scenes/main/rain.gdshader
git commit -m "polish: three-layer depth rain shader"
```

---

## Self-Review

**Spec coverage (map each spec requirement to a task):**
- GameState `active_module`/`module_open` + change-guarded setters + signals → Task 1.
- `size_class` on `ModuleDef` + registry assignments → Task 2.
- Per-module toggle / switch / Esc topmost / collapse separation / `active_module` stays set invariant / scene-less `alerts` no-op → Task 4.
- icon_rail `set_active(id, lit)` highlight rule + test contract → Task 3.
- Labeled collapse button → Task 4.
- Visibility rules (`primary_host.visible`, `context_host.visible`) → Task 4.
- Class-driven sizing table, PANEL_INSET, context ~31% mirroring primary height, environment stays visible → Task 5.
- `CONTEXT_SPLIT` removed + shrink rule deferred → Task 5.
- Rain: three-layer, O(1), slant consistent, sum compositing → Task 6.

**Placeholder scan:** No TBD/TODO; every code step has concrete GDScript/GLSL and every test has concrete assertions.

**Type consistency:** `set_active_module(id: StringName)`, `set_module_open(open: bool)` used in Task 4 match Task 1. `set_active(id, lit)` used in Task 4 matches Task 3. `SIZE_CLASSES`, `PANEL_INSET`, `_size_class(id)` defined in Task 5, used only there. `close_topmost`, `open_context`, `close_context` all defined in Task 4. `contract_detail` size handled via the `_size_class` special case in Task 5.

**Known simplification:** Rain is verified by eye (deliberate; no logic test). The `_size_class` helper loads the registry each call — acceptable for a layout pass; note it as `ponytail:`-worthy if it ever becomes a hot path (it isn't; layout runs on resize only).
