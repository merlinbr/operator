# Terminal Shell (Slice 0) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the operations terminal shell — an environment-first, collapsible workspace UI that all future game modules plug into.

**Architecture:** One `Main` scene owns an `EnvironmentLayer` (layered illustrated backdrop with restrained effects) and a `Workspace` layer (status chip, icon rail, primary panel + optional context panel, ticker). A single `GameState` autoload holds state and emits signals; all components receive it via `setup()` injection, never via the autoload global. Module panels are independent scenes registered in a data-driven `ModuleRegistry`.

**Tech Stack:** Godot 4.7.1 (GDScript, typed), Control-based UI, code-built UI trees inside minimal `.tscn` files, headless script tests via `godot --headless --script` (no addons).

**Spec:** `docs/superpowers/specs/2026-08-24-terminal-shell-design.md`

## Global Constraints

- Engine: Godot 4.7.1. Console executable on this machine:
  `$godot = "C:\Users\merli\Documents\Godot Projects\Godot_v4.7.1-stable_win64_console.exe"`
  Project root: `"C:\Users\merli\Documents\Godot Projects\operator"`
- GDScript: Godot 4.x syntax, statically typed where practical. No addons, no plugins, no new autoloads beyond `GameState`.
- **Component pattern (used in every UI task):** `.tscn` files contain only a root node + script. Children are built in `_ready()`. Components expose `setup(...)` which MUST be called after the node is in the tree (after `add_child`). Components never reference the `GameState` autoload global identifier — they receive the state node via `setup()` and store it.
- **Palette (verbatim from spec):** panel bg `Color(0.03137, 0.04706, 0.06667, 0.82353)` (rgba 8,12,17,0.82) · border `#2c404c` → `Color(0.17255, 0.25098, 0.29804, 1)` · cyan accent `#39d0ff` → `Color(0.22353, 0.81569, 1, 1)` · amber credits/warnings `#ffd27a` → `Color(1, 0.82353, 0.47843, 1)` · red alerts `#ff5a78` → `Color(1, 0.35294, 0.47059, 1)` · body text `#8fa8b5` → `Color(0.56078, 0.65882, 0.7098, 1)` · dim text `#6f8b98` → `Color(0.43529, 0.5451, 0.60392, 1)`.
- Display: 1920×1080 reference, `canvas_items` stretch, `expand` aspect. Must remain clean at 1280×720. No responsive work below 1280×720.
- No panel dragging. One primary panel + one optional context panel, auto-arranged.
- Placeholder game content lives ONLY in `res://data/placeholder/`.
- Testing: logic is TDD'd with headless script tests. Test scripts extend `res://tests/test_base.gd` (Task 1). Run one test:
  `.\tests\run_test.ps1 <test_name>` (runs `res://tests/<test_name>.gd`). Expected final line: `RESULT: ALL PASSED`, exit code 0.
- After any task that adds imported assets (fonts, shaders), run once:
  `& $godot --headless --path "C:\Users\merli\Documents\Godot Projects\operator" --import`
- Commit after every task with the exact message given in the task.
- Visual-only deliverables (environment, final look) are verified by running the project:
  `& $godot --path "C:\Users\merli\Documents\Godot Projects\operator"` (opens a window; close it manually) — or via the godot-mcp `run_project` tool.

---

### Task 1: Test harness + project settings

**Files:**
- Create: `tests/test_base.gd`
- Create: `tests/run_test.ps1`
- Modify: `project.godot` (display section only)

**Interfaces:**
- Consumes: nothing
- Produces: `test_base.gd` — SceneTree base class with `check(cond: bool, msg: String)` and `finish() -> void`; subclasses extend it by path (`extends "res://tests/test_base.gd"`), override `_run()`, and `_init()` calls `_run()` then `finish()`. `run_test.ps1 <name>` runs `res://tests/<name>.gd` and propagates the exit code.

- [ ] **Step 1: Create `tests/test_base.gd`**

```gdscript
extends SceneTree
## Minimal headless test base. Subclass:
##   extends "res://tests/test_base.gd"
##   func _run() -> void:
##       check(1 + 1 == 2, "math works")
## Run: .\tests\run_test.ps1 <script_name_without_extension>

var _failures := 0

func _init() -> void:
	_run()
	finish()

func _run() -> void:
	pass

func check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: " + msg)
	else:
		_failures += 1
		printerr("  FAIL: " + msg)

func finish() -> void:
	if _failures == 0:
		print("RESULT: ALL PASSED")
		quit(0)
	else:
		printerr("RESULT: %d FAILURE(S)" % _failures)
		quit(1)
```

- [ ] **Step 2: Create `tests/run_test.ps1`**

```powershell
param(
	[Parameter(Mandatory = $true)][string]$Test
)
$godot = "C:\Users\merli\Documents\Godot Projects\Godot_v4.7.1-stable_win64_console.exe"
$project = "C:\Users\merli\Documents\Godot Projects\operator"
& $godot --headless --path $project --script "res://tests/$Test.gd"
exit $LASTEXITCODE
```

- [ ] **Step 3: Write the first test `tests/test_smoke.gd`**

```gdscript
extends "res://tests/test_base.gd"

func _run() -> void:
	check(true, "smoke test runs")
```

- [ ] **Step 4: Run it**

Run: `.\tests\run_test.ps1 test_smoke`
Expected: `PASS: smoke test runs` then `RESULT: ALL PASSED`, exit code 0.

- [ ] **Step 5: Set display settings in `project.godot`**

Replace the existing `[display]` section with:

```ini
[display]

window/size/viewport_width=1920
window/size/viewport_height=1080
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"
```

- [ ] **Step 6: Commit**

```bash
git add tests/ project.godot
git commit -m "feat: headless test harness and 1080p display settings"
```

---

### Task 2: GameState autoload

**Files:**
- Create: `autoload/game_state.gd`
- Modify: `project.godot` (add `[autoload]` section)
- Test: `tests/test_game_state.gd`

**Interfaces:**
- Consumes: nothing
- Produces (later tasks inject instances of this script):
  - Signals: `credits_changed(new_credits: int)`, `clock_changed(day: int, minute_of_day: int)`, `district_changed(new_district: String)`, `heat_changed(new_heat: int)`, `alerts_changed(new_alerts: int)`, `workspace_collapsed_changed(collapsed: bool)`, `ticker_message(text: String, highlight: bool)`
  - Fields: `credits: int`, `district: String`, `day: int`, `minute_of_day: int`, `heat: int`, `alerts: int`, `workspace_collapsed: bool`
  - Methods: `add_credits(delta: int) -> void`, `advance_minutes(minutes: int) -> void`, `set_workspace_collapsed(collapsed: bool) -> void`, `toggle_workspace() -> void`, `push_ticker(text: String, highlight: bool = false) -> void`, `clock_text() -> String`
  - Static: `format_credits(amount: int) -> String` (thousands separators, e.g. `12480` → `"12,480"`)
  - Start values: credits `12480`, district `"LOWER VESPER"`, day `14`, minute_of_day `23*60+41`, heat `2`, alerts `2`, workspace_collapsed `false`
  - NOTE: this script deliberately has NO `class_name` (the autoload singleton is named `GameState`; a matching class_name would shadow it). Other scripts reference it via `const GameStateScript := preload("res://autoload/game_state.gd")`.

- [ ] **Step 1: Write the failing test `tests/test_game_state.gd`**

```gdscript
extends "res://tests/test_base.gd"

const GameStateScript := preload("res://autoload/game_state.gd")

func _run() -> void:
	var gs := GameStateScript.new()

	check(gs.credits == 12480, "starts with 12480 credits")
	check(gs.district == "LOWER VESPER", "starts in LOWER VESPER")
	check(gs.workspace_collapsed == false, "workspace starts expanded")

	var got_credits := [0]
	gs.credits_changed.connect(func(v: int) -> void: got_credits[0] = v)
	gs.add_credits(520)
	check(gs.credits == 13000, "add_credits adds")
	check(got_credits[0] == 13000, "credits_changed emitted with new value")
	gs.add_credits(-99999)
	check(gs.credits == 0, "credits clamp at zero")

	check(gs.clock_text() == "23:41", "initial clock text")
	gs.advance_minutes(30)
	check(gs.clock_text() == "00:11", "clock rolls over midnight")
	check(gs.day == 15, "day increments on midnight rollover")

	var collapsed_seen := [true]
	gs.workspace_collapsed_changed.connect(func(c: bool) -> void: collapsed_seen[0] = c)
	gs.set_workspace_collapsed(true)
	check(gs.workspace_collapsed and collapsed_seen[0], "set_workspace_collapsed emits")
	gs.set_workspace_collapsed(true)
	check(collapsed_seen[0], "no duplicate emit for same state")
	gs.toggle_workspace()
	check(gs.workspace_collapsed == false, "toggle_workspace flips state")

	var ticker_seen := ["", true]
	gs.ticker_message.connect(func(text: String, highlight: bool) -> void:
		ticker_seen[0] = text
		ticker_seen[1] = highlight)
	gs.push_ticker("test message", true)
	check(ticker_seen[0] == "test message" and ticker_seen[1] == true, "push_ticker emits")

	check(GameStateScript.format_credits(12480) == "12,480", "format_credits thousands")
	check(GameStateScript.format_credits(999) == "999", "format_credits below 1000")
	check(GameStateScript.format_credits(0) == "0", "format_credits zero")

	gs.free()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `.\tests\run_test.ps1 test_game_state`
Expected: FAIL — parse error "Could not find type ... res://autoload/game_state.gd" (file missing).

- [ ] **Step 3: Write `autoload/game_state.gd`**

```gdscript
extends Node
## Central game state singleton (registered as autoload "GameState").
## Components receive this node via setup() injection — they never access
## the autoload global by name. No class_name on purpose (autoload name wins).

signal credits_changed(new_credits: int)
signal clock_changed(day: int, minute_of_day: int)
signal district_changed(new_district: String)
signal heat_changed(new_heat: int)
signal alerts_changed(new_alerts: int)
signal workspace_collapsed_changed(collapsed: bool)
signal ticker_message(text: String, highlight: bool)

const START_CREDITS := 12480
const START_DISTRICT := "LOWER VESPER"
const START_DAY := 14
const START_MINUTE := 23 * 60 + 41

var credits: int = START_CREDITS:
	set(value):
		credits = maxi(value, 0)
		credits_changed.emit(credits)
var district: String = START_DISTRICT:
	set(value):
		district = value
		district_changed.emit(district)
var day: int = START_DAY
var minute_of_day: int = START_MINUTE
var heat: int = 2:
	set(value):
		heat = value
		heat_changed.emit(heat)
var alerts: int = 2:
	set(value):
		alerts = value
		alerts_changed.emit(alerts)
var workspace_collapsed := false

func add_credits(delta_credits: int) -> void:
	credits += delta_credits

func advance_minutes(minutes: int) -> void:
	minute_of_day += minutes
	while minute_of_day >= 1440:
		minute_of_day -= 1440
		day += 1
	clock_changed.emit(day, minute_of_day)

func set_workspace_collapsed(collapsed: bool) -> void:
	if workspace_collapsed == collapsed:
		return
	workspace_collapsed = collapsed
	workspace_collapsed_changed.emit(collapsed)

func toggle_workspace() -> void:
	set_workspace_collapsed(not workspace_collapsed)

func push_ticker(text: String, highlight: bool = false) -> void:
	ticker_message.emit(text, highlight)

func clock_text() -> String:
	return "%02d:%02d" % [floori(minute_of_day / 60.0), minute_of_day % 60]

static func format_credits(amount: int) -> String:
	var digits := str(amount)
	var out := ""
	while digits.length() > 3:
		out = "," + digits.substr(digits.length() - 3) + out
		digits = digits.substr(0, digits.length() - 3)
	return digits + out
```

- [ ] **Step 4: Register the autoload in `project.godot`**

Add this section (e.g. after `[application]`):

```ini
[autoload]

GameState="*res://autoload/game_state.gd"
```

- [ ] **Step 5: Run test to verify it passes**

Run: `.\tests\run_test.ps1 test_game_state`
Expected: all PASS, `RESULT: ALL PASSED`, exit code 0.

- [ ] **Step 6: Commit**

```bash
git add autoload/game_state.gd project.godot tests/test_game_state.gd
git commit -m "feat: GameState autoload with signals, clock, credits, collapse state"
```

---

### Task 3: ModuleDef + ModuleRegistry + registry resource

**Files:**
- Create: `scripts/module_def.gd`
- Create: `scripts/module_registry.gd`
- Create: `resources/module_registry.tres`
- Test: `tests/test_module_registry.gd`

**Interfaces:**
- Consumes: nothing
- Produces:
  - `ModuleDef` (class_name): Resource with `id: StringName`, `display_name: String`, `glyph: String`, `group: StringName` (`&"core"` | `&"operational"` | `&"utility"`), `unlocked: bool`
  - `ModuleRegistry` (class_name): Resource with `modules: Array` (of ModuleDef); methods `get_module(id: StringName) -> ModuleDef` (null if absent), `rail_order() -> Array` (modules sorted core → operational → utility, stable within group)
  - `res://resources/module_registry.tres` — instance of ModuleRegistry containing exactly: home(◈, core, unlocked), comms(✉, core, unlocked), contracts(▣, core, unlocked), crew(≋, operational, LOCKED), market(◇, operational, LOCKED), map(⌖, operational, LOCKED), alerts(!, utility, unlocked). (Assets & later systems are absent = hidden, per spec.)

- [ ] **Step 1: Write the failing test `tests/test_module_registry.gd`**

```gdscript
extends "res://tests/test_base.gd"

func _run() -> void:
	var reg: ModuleRegistry = load("res://resources/module_registry.tres")
	check(reg != null, "registry loads")

	var home := reg.get_module(&"home")
	check(home != null and home.unlocked, "home exists and is unlocked")
	check(home.glyph == "◈", "home glyph")
	check(reg.get_module(&"assets") == null, "assets is absent (hidden by absence)")

	var crew := reg.get_module(&"crew")
	check(crew != null and not crew.unlocked, "crew exists and is locked")
	check(reg.get_module(&"market") != null and not reg.get_module(&"market").unlocked, "market locked")
	check(reg.get_module(&"map") != null and not reg.get_module(&"map").unlocked, "map locked")

	var order := reg.rail_order()
	var ids: Array = order.map(func(m: ModuleDef) -> StringName: return m.id)
	check(ids == [&"home", &"comms", &"contracts", &"crew", &"market", &"map", &"alerts"] as Array,
		"rail order is core, operational, utility — got %s" % [ids])
	check(order[0].group == &"core" and order[6].group == &"utility", "groups ordered core→utility")
	check(reg.get_module(&"alerts").group == &"utility", "alerts is utility group")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `.\tests\run_test.ps1 test_module_registry`
Expected: FAIL — cannot load `res://resources/module_registry.tres` / unknown identifier ModuleRegistry.

- [ ] **Step 3: Write `scripts/module_def.gd`**

```gdscript
class_name ModuleDef
extends Resource
## One rail module definition. Data only.

@export var id: StringName = &""
@export var display_name: String = ""
@export var glyph: String = "?"
@export var group: StringName = &"core" # core | operational | utility
@export var unlocked := false
```

- [ ] **Step 4: Write `scripts/module_registry.gd`**

```gdscript
class_name ModuleRegistry
extends Resource
## Data-driven list of terminal modules. The icon rail renders from this.
## Adding a module = adding a ModuleDef here (+ a scene + one entry in
## main.gd MODULE_SCENES). Hidden late-game systems are simply absent.

const GROUP_ORDER := {&"core": 0, &"operational": 1, &"utility": 2}

@export var modules: Array = [] # of ModuleDef

func get_module(id: StringName) -> ModuleDef:
	for m: ModuleDef in modules:
		if m.id == id:
			return m
	return null

func rail_order() -> Array:
	var sorted := modules.duplicate()
	sorted.sort_custom(func(a: ModuleDef, b: ModuleDef) -> bool:
		return int(GROUP_ORDER.get(a.group, 9)) < int(GROUP_ORDER.get(b.group, 9)))
	return sorted
```

- [ ] **Step 5: Write `resources/module_registry.tres`**

```ini
[gd_resource type="Resource" script_class="ModuleRegistry" load_steps=10 format=3]

[ext_resource type="Script" path="res://scripts/module_registry.gd" id="1_reg"]
[ext_resource type="Script" path="res://scripts/module_def.gd" id="2_def"]

[sub_resource type="Resource" id="def_home"]
script = ExtResource("2_def")
id = &"home"
display_name = "HOME"
glyph = "◈"
group = &"core"
unlocked = true

[sub_resource type="Resource" id="def_comms"]
script = ExtResource("2_def")
id = &"comms"
display_name = "COMMS"
glyph = "✉"
group = &"core"
unlocked = true

[sub_resource type="Resource" id="def_contracts"]
script = ExtResource("2_def")
id = &"contracts"
display_name = "CONTRACTS"
glyph = "▣"
group = &"core"
unlocked = true

[sub_resource type="Resource" id="def_crew"]
script = ExtResource("2_def")
id = &"crew"
display_name = "CREW"
glyph = "≋"
group = &"operational"
unlocked = false

[sub_resource type="Resource" id="def_market"]
script = ExtResource("2_def")
id = &"market"
display_name = "MARKET"
glyph = "◇"
group = &"operational"
unlocked = false

[sub_resource type="Resource" id="def_map"]
script = ExtResource("2_def")
id = &"map"
display_name = "MAP"
glyph = "⌖"
group = &"operational"
unlocked = false

[sub_resource type="Resource" id="def_alerts"]
script = ExtResource("2_def")
id = &"alerts"
display_name = "ALERTS"
glyph = "!"
group = &"utility"
unlocked = true

[resource]
script = ExtResource("1_reg")
modules = [SubResource("def_home"), SubResource("def_comms"), SubResource("def_contracts"), SubResource("def_crew"), SubResource("def_market"), SubResource("def_map"), SubResource("def_alerts")]
```

- [ ] **Step 6: Run test to verify it passes**

Run: `.\tests\run_test.ps1 test_module_registry`
Expected: all PASS, exit code 0.

- [ ] **Step 7: Commit**

```bash
git add scripts/module_def.gd scripts/module_registry.gd resources/module_registry.tres tests/test_module_registry.gd
git commit -m "feat: data-driven module registry with unlock states"
```

---

### Task 4: JetBrains Mono + theme resource

**Files:**
- Create: `assets/fonts/JetBrainsMono-Regular.ttf` (downloaded)
- Create: `assets/fonts/JetBrainsMono-Bold.ttf` (downloaded)
- Create: `resources/operator_theme.tres`
- Test: `tests/test_theme.gd`

**Interfaces:**
- Consumes: nothing
- Produces: `res://resources/operator_theme.tres` — Theme with `default_font` = JetBrains Mono Regular (size 15), Panel/PanelContainer floating stylebox, Button styles (normal/hover/pressed/disabled), font colors per palette. Main applies it via `theme = load("res://resources/operator_theme.tres")`.

- [ ] **Step 1: Download the fonts**

```powershell
New-Item -ItemType Directory -Force -Path "assets/fonts" | Out-Null
Invoke-WebRequest -Uri "https://github.com/JetBrains/JetBrainsMono/raw/v2.304/fonts/ttf/JetBrainsMono-Regular.ttf" -OutFile "assets/fonts/JetBrainsMono-Regular.ttf"
Invoke-WebRequest -Uri "https://github.com/JetBrains/JetBrainsMono/raw/v2.304/fonts/ttf/JetBrainsMono-Bold.ttf" -OutFile "assets/fonts/JetBrainsMono-Bold.ttf"
Get-ChildItem "assets/fonts"
```

Expected: two .ttf files, each > 100 KB. If the download fails (network blocked), stop and tell the user — do not substitute silently.

- [ ] **Step 2: Import assets once**

Run: `& "C:\Users\merli\Documents\Godot Projects\Godot_v4.7.1-stable_win64_console.exe" --headless --path "C:\Users\merli\Documents\Godot Projects\operator" --import`
Expected: exits 0, `.godot/imported/` now contains font imports.

- [ ] **Step 3: Write the failing test `tests/test_theme.gd`**

```gdscript
extends "res://tests/test_base.gd"

func _run() -> void:
	var theme: Theme = load("res://resources/operator_theme.tres")
	check(theme != null, "theme loads")
	check(theme.default_font != null, "default font is set")
	check(theme.default_font_size == 15, "default font size 15")
	check(theme.has_stylebox("panel", "PanelContainer"), "PanelContainer floating stylebox")
	check(theme.has_color("font_color", "Button"), "Button font color")
	check(theme.has_stylebox("normal", "Button"), "Button normal stylebox")
	check(theme.has_stylebox("disabled", "Button"), "Button disabled stylebox")
	check(theme.has_color("font_color", "Label"), "Label font color")
```

- [ ] **Step 4: Run test to verify it fails**

Run: `.\tests\run_test.ps1 test_theme`
Expected: FAIL — cannot load theme resource.

- [ ] **Step 5: Write `resources/operator_theme.tres`**

```ini
[gd_resource type="Theme" load_steps=9 format=3]

[ext_resource type="FontFile" path="res://assets/fonts/JetBrainsMono-Regular.ttf" id="1_font"]
[ext_resource type="FontFile" path="res://assets/fonts/JetBrainsMono-Bold.ttf" id="2_fontbold"]

[sub_resource type="StyleBoxFlat" id="sbf_panel"]
content_margin_left = 12.0
content_margin_top = 10.0
content_margin_right = 12.0
content_margin_bottom = 10.0
bg_color = Color(0.03137, 0.04706, 0.06667, 0.82353)
border_width_left = 1
border_width_top = 1
border_width_right = 1
border_width_bottom = 1
border_color = Color(0.17255, 0.25098, 0.29804, 1)
corner_radius_top_left = 4
corner_radius_top_right = 4
corner_radius_bottom_right = 4
corner_radius_bottom_left = 4

[sub_resource type="StyleBoxFlat" id="sbf_btn_normal"]
content_margin_left = 10.0
content_margin_top = 6.0
content_margin_right = 10.0
content_margin_bottom = 6.0
bg_color = Color(0.04314, 0.06275, 0.08627, 0.6)
border_width_left = 1
border_width_top = 1
border_width_right = 1
border_width_bottom = 1
border_color = Color(0.12941, 0.19216, 0.23137, 1)
corner_radius_top_left = 3
corner_radius_top_right = 3
corner_radius_bottom_right = 3
corner_radius_bottom_left = 3

[sub_resource type="StyleBoxFlat" id="sbf_btn_hover"]
content_margin_left = 10.0
content_margin_top = 6.0
content_margin_right = 10.0
content_margin_bottom = 6.0
bg_color = Color(0.06275, 0.10196, 0.13333, 0.85)
border_width_left = 1
border_width_top = 1
border_width_right = 1
border_width_bottom = 1
border_color = Color(0.22353, 0.81569, 1, 1)
corner_radius_top_left = 3
corner_radius_top_right = 3
corner_radius_bottom_right = 3
corner_radius_bottom_left = 3

[sub_resource type="StyleBoxFlat" id="sbf_btn_pressed"]
content_margin_left = 10.0
content_margin_top = 6.0
content_margin_right = 10.0
content_margin_bottom = 6.0
bg_color = Color(0.10196, 0.16078, 0.20784, 0.9)
border_width_left = 1
border_width_top = 1
border_width_right = 1
border_width_bottom = 1
border_color = Color(0.22353, 0.81569, 1, 1)
corner_radius_top_left = 3
corner_radius_top_right = 3
corner_radius_bottom_right = 3
corner_radius_bottom_left = 3

[sub_resource type="StyleBoxFlat" id="sbf_btn_disabled"]
content_margin_left = 10.0
content_margin_top = 6.0
content_margin_right = 10.0
content_margin_bottom = 6.0
bg_color = Color(0.04314, 0.06275, 0.08627, 0.4)
border_width_left = 1
border_width_top = 1
border_width_right = 1
border_width_bottom = 1
border_color = Color(0.12941, 0.19216, 0.23137, 0.5)
corner_radius_top_left = 3
corner_radius_top_right = 3
corner_radius_bottom_right = 3
corner_radius_bottom_left = 3

[sub_resource type="StyleBoxFlat" id="sbf_chip"]
content_margin_left = 16.0
content_margin_top = 6.0
content_margin_right = 16.0
content_margin_bottom = 6.0
bg_color = Color(0.02745, 0.03922, 0.0549, 0.72)
border_width_left = 1
border_width_top = 1
border_width_right = 1
border_width_bottom = 1
border_color = Color(0.17255, 0.25098, 0.29804, 1)
corner_radius_top_left = 3
corner_radius_top_right = 3
corner_radius_bottom_right = 3
corner_radius_bottom_left = 3

[resource]
default_font = ExtResource("1_font")
default_font_size = 15
Button/colors/font_color = Color(0.43529, 0.5451, 0.60392, 1)
Button/colors/font_disabled_color = Color(0.43529, 0.5451, 0.60392, 0.45)
Button/colors/font_hover_color = Color(0.22353, 0.81569, 1, 1)
Button/colors/font_pressed_color = Color(0.22353, 0.81569, 1, 1)
Button/styles/disabled = SubResource("sbf_btn_disabled")
Button/styles/hover = SubResource("sbf_btn_hover")
Button/styles/normal = SubResource("sbf_btn_normal")
Button/styles/pressed = SubResource("sbf_btn_pressed")
Label/colors/font_color = Color(0.56078, 0.65882, 0.7098, 1)
Panel/styles/panel = SubResource("sbf_panel")
PanelContainer/styles/panel = SubResource("sbf_panel")
```

Note: the `sbf_chip` and `2_fontbold` resources are defined for upcoming tasks (chip variant stylebox, bold title font). The theme test does not assert them; leaving unused sub_resources in a Theme .tres is valid. To keep the resource clean, also add these two lines under `[resource]` so nothing is orphaned:

```ini
StatusChip/styles/panel = SubResource("sbf_chip")
```

(The `StatusChip` custom type entry is legal in a Theme — components pick it up via `add_theme_stylebox_override` is NOT needed; instead Task 6's StatusChip root node sets `theme_type_variation = "StatusChip"`. If the editor/headless load warns about the unknown type, it is harmless.)

- [ ] **Step 6: Run test to verify it passes**

Run: `.\tests\run_test.ps1 test_theme`
Expected: all PASS, exit code 0. (If load fails due to font ExtResource type, re-run the `--import` step.)

- [ ] **Step 7: Commit**

```bash
git add assets/fonts/ resources/operator_theme.tres tests/test_theme.gd
git commit -m "feat: JetBrains Mono and operator terminal theme"
```

---

### Task 5: Placeholder data

**Files:**
- Create: `data/placeholder/placeholder_contracts.gd`
- Create: `data/placeholder/placeholder_messages.gd`
- Test: `tests/test_placeholder_data.gd`

**Interfaces:**
- Consumes: `GameStateScript.format_credits` is NOT used here (raw ints only).
- Produces:
  - `PlaceholderContracts.all() -> Array[Dictionary]` — keys: `id: StringName`, `title: String`, `client: String`, `reward_credits: int`, `risk: String`, `district: String`, `encrypted: bool`. Exactly 3 entries: freight_transfer (1400 CR), data_retrieval (4200 CR), encrypted_offer (encrypted=true, reward 0).
  - `PlaceholderMessages.all() -> Array[Dictionary]` — keys: `id: StringName`, `sender: String`, `preview: String`, `unread: bool`. Exactly 3 entries; MARA unread first.

- [ ] **Step 1: Write the failing test `tests/test_placeholder_data.gd`**

```gdscript
extends "res://tests/test_base.gd"

const Contracts := preload("res://data/placeholder/placeholder_contracts.gd")
const Messages := preload("res://data/placeholder/placeholder_messages.gd")

func _run() -> void:
	var contracts := Contracts.all()
	check(contracts.size() == 3, "3 placeholder contracts")
	check(contracts[0].id == &"freight_transfer" and contracts[0].reward_credits == 1400, "freight transfer 1400")
	check(contracts[1].reward_credits == 4200, "data retrieval 4200")
	check(contracts[2].encrypted == true, "third contract is encrypted")
	for c: Dictionary in contracts:
		check(c.has_all(["id", "title", "client", "reward_credits", "risk", "district", "encrypted"]),
			"contract %s has all keys" % [c.id])

	var messages := Messages.all()
	check(messages.size() == 3, "3 placeholder messages")
	check(messages[0].sender == "MARA" and messages[0].unread, "MARA unread first")
	var unread_count := 0
	for m: Dictionary in messages:
		if m.unread:
			unread_count += 1
	check(unread_count == 2, "two unread messages")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `.\tests\run_test.ps1 test_placeholder_data`
Expected: FAIL — scripts missing.

- [ ] **Step 3: Write `data/placeholder/placeholder_contracts.gd`**

```gdscript
class_name PlaceholderContracts
extends RefCounted
## DUMMY contract data for the shell slice. Isolated here by design —
## replaced wholesale by the real contract data model later.

static func all() -> Array[Dictionary]:
	return [
		{
			"id": &"freight_transfer",
			"title": "Freight Transfer",
			"client": "Maas Freight Co.",
			"reward_credits": 1400,
			"risk": "LOW",
			"district": "DOCKS",
			"encrypted": false,
		},
		{
			"id": &"data_retrieval",
			"title": "Data Retrieval",
			"client": "[REDACTED]",
			"reward_credits": 4200,
			"risk": "ELEVATED",
			"district": "SECTOR 9",
			"encrypted": false,
		},
		{
			"id": &"encrypted_offer",
			"title": "[ENCRYPTED OFFER]",
			"client": "UNKNOWN",
			"reward_credits": 0,
			"risk": "UNKNOWN",
			"district": "UNKNOWN",
			"encrypted": true,
		},
	]
```

- [ ] **Step 4: Write `data/placeholder/placeholder_messages.gd`**

```gdscript
class_name PlaceholderMessages
extends RefCounted
## DUMMY comms data for the shell slice. Isolated here by design.

static func all() -> Array[Dictionary]:
	return [
		{
			"id": &"msg_mara_crate",
			"sender": "MARA",
			"preview": "that crate better not exist, operator",
			"unread": true,
		},
		{
			"id": &"msg_system_sweep",
			"sender": "SYSTEM",
			"preview": "corp sweep expected in Sector 9 tonight",
			"unread": true,
		},
		{
			"id": &"msg_vasquez_docks",
			"sender": "VASQUEZ",
			"preview": "docks shift change is at 04:00, not 03:00",
			"unread": false,
		},
	]
```

- [ ] **Step 5: Run test to verify it passes**

Run: `.\tests\run_test.ps1 test_placeholder_data`
Expected: all PASS, exit code 0.

- [ ] **Step 6: Commit**

```bash
git add data/placeholder/ tests/test_placeholder_data.gd
git commit -m "feat: isolated placeholder contracts and messages"
```

---

### Task 6: Environment layer

**Files:**
- Create: `scenes/main/environment.tscn`
- Create: `scenes/main/environment.gd`
- Create: `scenes/main/rain.gdshader`

**Interfaces:**
- Consumes: nothing
- Produces: `environment.tscn` — full-rect Control (root name `EnvironmentLayer`), `mouse_filter = IGNORE`, containing: sky gradient, two parallax skyline Polygon2D layers, two flickering neon rects, rain shader rect. No public API required by other tasks (Main just instances it). Visual deliverable — verified by running the project, no unit test.

- [ ] **Step 1: Write `scenes/main/rain.gdshader`**

```glsl
shader_type canvas_item;

uniform float intensity : hint_range(0.0, 1.0) = 0.5;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	float cols = 90.0;
	float x = floor(UV.x * cols);
	float speed = 1.4 + hash(vec2(x, 1.0)) * 1.8;
	float y = fract(UV.y * 0.35 + TIME * speed + hash(vec2(x, 7.0)));
	float streak = smoothstep(0.0, 0.08, y) * smoothstep(0.35, 0.08, y);
	float gate = step(0.55, hash(vec2(x, 3.0)));
	COLOR = vec4(0.706, 0.863, 1.0, streak * gate * intensity * 0.35);
}
```

- [ ] **Step 2: Write `scenes/main/environment.gd`**

```gdscript
extends Control
## Environment placeholder: sky gradient, two parallax skyline layers,
## neon flicker signs, rain. Structured as swappable layers so real art
## can replace each part without code changes. Restrained on purpose.

const PARALLAX_STRENGTH := 8.0
const NEON_CYAN := Color(0.22353, 0.81569, 1.0)
const NEON_PINK := Color(1.0, 0.35294, 0.47059)

var _skyline_far: Polygon2D
var _skyline_near: Polygon2D
var _neon_rects: Array[ColorRect] = []
var _flicker_t: Array[float] = []
var _parallax := Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	resized.connect(_on_resized)
	_build_sky()
	_skyline_far = _make_skyline(Color("0d141c"), 0.42, 9172731)
	_skyline_near = _make_skyline(Color("080d13"), 0.58, 52341987)
	_build_neon()
	_build_rain()
	# First layout: _ready may run before the parent assigns our final size.
	await get_tree().process_frame
	_on_resized()

func _build_sky() -> void:
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	grad.colors = PackedColorArray([Color("050608"), Color("0a0f16"), Color("101820")])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	var sky := TextureRect.new()
	sky.texture = tex
	sky.stretch_mode = TextureRect.STRETCH_SCALE
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sky)

func _make_skyline(color: Color, height_frac: float, seed_value: int) -> Polygon2D:
	var poly := Polygon2D.new()
	poly.color = color
	poly.mouse_filter = Control.MOUSE_FILTER_IGNORE
	poly.set_meta("height_frac", height_frac)
	poly.set_meta("seed", seed_value)
	add_child(poly)
	_rebuild_skyline(poly)
	return poly

func _rebuild_skyline(poly: Polygon2D) -> void:
	var height_frac: float = poly.get_meta("height_frac")
	var rng := RandomNumberGenerator.new()
	rng.seed = poly.get_meta("seed")
	var points := PackedVector2Array()
	var base_y := size.y
	var max_drop := size.y * height_frac
	points.append(Vector2(0.0, base_y))
	var x := 0.0
	while x < size.x:
		var bw := rng.randf_range(60.0, 160.0)
		var bh := rng.randf_range(0.35, 1.0) * max_drop
		points.append(Vector2(x, base_y - bh))
		points.append(Vector2(minf(x + bw, size.x), base_y - bh))
		x += bw
	points.append(Vector2(size.x, base_y))
	poly.polygon = points
	poly.position = Vector2.ZERO

func _build_neon() -> void:
	var specs := [
		[NEON_CYAN, Vector2(0.18, 0.62), Vector2(120, 12)],
		[NEON_PINK, Vector2(0.68, 0.48), Vector2(80, 10)],
	]
	for spec: Array in specs:
		var rect := ColorRect.new()
		rect.color = spec[0]
		rect.size = spec[2]
		rect.position = Vector2(size.x * spec[1].x, size.y * spec[1].y)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(rect)
		_neon_rects.append(rect)
		_flicker_t.append(randf() * 2.0)

func _build_rain() -> void:
	var rain := ColorRect.new()
	rain.set_anchors_preset(Control.PRESET_FULL_RECT)
	rain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = FileAccess.get_file_as_string("res://scenes/main/rain.gdshader")
	var mat := ShaderMaterial.new()
	mat.shader = shader
	rain.material = mat
	add_child(rain)

func _on_resized() -> void:
	_rebuild_skyline(_skyline_far)
	_rebuild_skyline(_skyline_near)

func _process(delta: float) -> void:
	for i in _neon_rects.size():
		_flicker_t[i] += delta
		var t := _flicker_t[i]
		var flicker := (0.8 + 0.2 * sin(t * 9.0)) if sin(t * 1.7) > -0.85 else 0.25
		_neon_rects[i].modulate.a = flicker
	_update_parallax(delta)

func _update_parallax(delta: float) -> void:
	if size == Vector2.ZERO:
		return
	var mp := get_viewport().get_mouse_position()
	var center := size * 0.5
	var target := ((mp - center) / center).limit_length(1.0) * PARALLAX_STRENGTH
	_parallax = _parallax.lerp(target, minf(1.0, delta * 3.0))
	_skyline_far.position = Vector2(_parallax.x * 0.35, _parallax.y * 0.2)
	_skyline_near.position = Vector2(_parallax.x * 0.7, _parallax.y * 0.4)
```

- [ ] **Step 3: Write `scenes/main/environment.tscn`**

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scenes/main/environment.gd" id="1_env"]

[node name="EnvironmentLayer" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2
script = ExtResource("1_env")
```

- [ ] **Step 4: Import and verify headless load**

Run: `& "C:\Users\merli\Documents\Godot Projects\Godot_v4.7.1-stable_win64_console.exe" --headless --path "C:\Users\merli\Documents\Godot Projects\operator" --import`
Expected: exit 0, no script parse errors in output.

- [ ] **Step 5: Visual check**

Run the project via the godot-mcp `run_project` tool (or `& $godot --path "C:\Users\merli\Documents\Godot Projects\operator"`). Expected: a dark gradient sky, two silhouette skyline layers, two neon bars flickering occasionally, subtle rain streaks; skyline shifts slightly with mouse movement. (Godot's default project has no main scene yet — if prompted, temporarily run with `--scene` is not available; instead right-click `environment.tscn` in the editor is NOT possible headless — simplest: run via godot-mcp `run_project` with `scene: "res://scenes/main/environment.tscn"`.) Close the window.

- [ ] **Step 6: Commit**

```bash
git add scenes/main/environment.gd scenes/main/environment.tscn scenes/main/rain.gdshader
git commit -m "feat: layered environment placeholder with rain, neon, parallax"
```

---

### Task 7: Status chip

**Files:**
- Create: `scenes/ui/status_chip.tscn`
- Create: `scenes/ui/status_chip.gd`
- Test: `tests/test_status_chip.gd`

**Interfaces:**
- Consumes: GameState instance (Task 2 API: `credits`, `district`, `clock_text()`, signals `credits_changed`, `clock_changed`, `district_changed`; static `format_credits`).
- Produces: `status_chip.tscn` — PanelContainer root (name `StatusChip`, `theme_type_variation = "StatusChip"`) with two centered labels: credits (amber) and `DISTRICT // HH:MM` (dim). `setup(gs: Node) -> void` — call after `add_child`. Updates live on signals.

- [ ] **Step 1: Write the failing test `tests/test_status_chip.gd`**

```gdscript
extends "res://tests/test_base.gd"

const GameStateScript := preload("res://autoload/game_state.gd")
const StatusChipScene := preload("res://scenes/ui/status_chip.tscn")

func _run() -> void:
	var gs := GameStateScript.new()
	gs.name = "GameState"
	root.add_child(gs)

	var chip := StatusChipScene.instantiate()
	root.add_child(chip)
	chip.setup(gs)

	var labels: Array[Label] = []
	for label in chip.find_children("*", "Label", true, false):
		labels.append(label)
	check(labels.size() == 2, "chip has two labels")
	check(labels[0].text == "12,480 CR", "credits label formatted — got '%s'" % labels[0].text)
	check(labels[1].text.begins_with("LOWER VESPER // "), "district/clock label")

	gs.add_credits(20)
	check(labels[0].text == "13,000 CR", "credits label updates on signal")
	gs.advance_minutes(19)
	check(labels[1].text == "LOWER VESPER // 00:00", "clock label updates — got '%s'" % labels[1].text)

	chip.queue_free()
	gs.queue_free()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `.\tests\run_test.ps1 test_status_chip`
Expected: FAIL — scene missing.

- [ ] **Step 3: Write `scenes/ui/status_chip.gd`**

```gdscript
extends PanelContainer
## Compact always-visible status chip: credits over district/clock.

const GameStateScript := preload("res://autoload/game_state.gd")
const COLOR_AMBER := Color(1.0, 0.82353, 0.47843)

var _gs: Node
var _credits_label: Label
var _loc_label: Label

func _ready() -> void:
	theme_type_variation = &"StatusChip"
	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vbox)
	_credits_label = Label.new()
	_credits_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_credits_label.add_theme_color_override("font_color", COLOR_AMBER)
	_loc_label = Label.new()
	_loc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_credits_label)
	vbox.add_child(_loc_label)

func setup(gs: Node) -> void:
	_gs = gs
	_gs.credits_changed.connect(_on_credits)
	_gs.clock_changed.connect(_on_clock)
	_gs.district_changed.connect(_on_district)
	_on_credits(_gs.credits)
	_on_clock(_gs.day, _gs.minute_of_day)
	_on_district(_gs.district)

func _on_credits(value: int) -> void:
	_credits_label.text = GameStateScript.format_credits(value) + " CR"

func _on_clock(day: int, minute_of_day: int) -> void:
	_loc_label.text = "%s // %s" % [_gs.district, _gs.clock_text()]
	_loc_label.tooltip_text = "DAY %d" % day

func _on_district(new_district: String) -> void:
	_on_clock(_gs.day, _gs.minute_of_day)
```

- [ ] **Step 4: Write `scenes/ui/status_chip.tscn`**

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scenes/ui/status_chip.gd" id="1_chip"]

[node name="StatusChip" type="PanelContainer"]
offset_right = 240.0
offset_bottom = 64.0
script = ExtResource("1_chip")
```

- [ ] **Step 5: Run test to verify it passes**

Run: `.\tests\run_test.ps1 test_status_chip`
Expected: all PASS, exit code 0.

- [ ] **Step 6: Commit**

```bash
git add scenes/ui/status_chip.gd scenes/ui/status_chip.tscn tests/test_status_chip.gd
git commit -m "feat: status chip with live credits and district clock"
```

---

### Task 8: Icon rail

**Files:**
- Create: `scenes/ui/icon_rail.tscn`
- Create: `scenes/ui/icon_rail.gd`
- Test: `tests/test_icon_rail.gd`

**Interfaces:**
- Consumes: `ModuleRegistry` / `ModuleDef` (Task 3), `res://resources/module_registry.tres`.
- Produces: `icon_rail.tscn` — VBoxContainer root (name `IconRail`). `setup(registry: ModuleRegistry) -> void` (call after `add_child`). Signal `module_selected(id: StringName)`. Unlocked modules are enabled buttons; locked modules are disabled + dimmed with "(LOCKED)" tooltip; an `HSeparator` sits before each group change. Also `set_active(id: StringName) -> void` highlights the active module button (cyan modulate).

- [ ] **Step 1: Write the failing test `tests/test_icon_rail.gd`**

```gdscript
extends "res://tests/test_base.gd"

const IconRailScene := preload("res://scenes/ui/icon_rail.tscn")

func _run() -> void:
	var reg: ModuleRegistry = load("res://resources/module_registry.tres")
	var rail := IconRailScene.instantiate()
	root.add_child(rail)

	var seen := [&""]
	rail.module_selected.connect(func(id: StringName) -> void: seen[0] = id)
	rail.setup(reg)

	var buttons: Array[Button] = []
	for child in rail.find_children("*", "Button", true, false):
		buttons.append(child)
	check(buttons.size() == 7, "seven module buttons — got %d" % buttons.size())

	var home_btn: Button = rail.get_button(&"home")
	check(home_btn != null and not home_btn.disabled, "home enabled")
	var crew_btn: Button = rail.get_button(&"crew")
	check(crew_btn != null and crew_btn.disabled, "crew disabled (locked)")
	check(crew_btn.tooltip_text.contains("LOCKED"), "locked tooltip")

	var seps := rail.find_children("*", "HSeparator", true, false)
	check(seps.size() == 2, "separators before operational and utility groups")

	home_btn.pressed.emit()
	check(seen[0] == &"home", "pressing home emits module_selected(home)")

	rail.set_active(&"comms")
	var comms_btn: Button = rail.get_button(&"comms")
	check(comms_btn.modulate == Color(0.22353, 0.81569, 1.0), "active module highlighted cyan")
	check(home_btn.modulate == Color.WHITE, "previous unlocked module unhighlighted")
	check(crew_btn.modulate == Color(1.0, 1.0, 1.0, 0.4), "locked module stays dimmed")

	rail.queue_free()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `.\tests\run_test.ps1 test_icon_rail`
Expected: FAIL — scene missing.

- [ ] **Step 3: Write `scenes/ui/icon_rail.gd`**

```gdscript
extends VBoxContainer
## Slim floating module rail. Renders from the ModuleRegistry resource.
## Locked modules stay visible (greyed, lock tooltip) so the player sees
## the terminal grow; late-game modules are absent from the registry.

signal module_selected(id: StringName)

const COLOR_ACCENT := Color(0.22353, 0.81569, 1.0)
const COLOR_LOCKED_DIM := Color(1.0, 1.0, 1.0, 0.4)

var _registry: ModuleRegistry
var _buttons := {} # StringName -> Button
var _active: StringName = &""

func _ready() -> void:
	add_theme_constant_override("separation", 8)

func setup(registry: ModuleRegistry) -> void:
	_registry = registry
	_rebuild()

func get_button(id: StringName) -> Button:
	return _buttons.get(id)

func set_active(id: StringName) -> void:
	_active = id
	for btn_id: StringName in _buttons:
		var btn: Button = _buttons[btn_id]
		if btn_id == _active:
			btn.modulate = COLOR_ACCENT
		elif btn.disabled:
			btn.modulate = COLOR_LOCKED_DIM
		else:
			btn.modulate = Color.WHITE

func _rebuild() -> void:
	for child in get_children():
		child.queue_free()
	_buttons.clear()
	var last_group := &""
	for def: ModuleDef in _registry.rail_order():
		if last_group != &"" and def.group != last_group:
			add_child(HSeparator.new())
		last_group = def.group
		var btn := Button.new()
		btn.text = def.glyph
		btn.tooltip_text = def.display_name if def.unlocked else def.display_name + " (LOCKED)"
		btn.disabled = not def.unlocked
		btn.focus_mode = Control.FOCUS_NONE
		btn.custom_minimum_size = Vector2(44, 40)
		btn.add_theme_font_size_override("font_size", 18)
		if not def.unlocked:
			btn.modulate = COLOR_LOCKED_DIM
		btn.pressed.connect(_on_pressed.bind(def.id))
		add_child(btn)
		_buttons[def.id] = btn

func _on_pressed(id: StringName) -> void:
	module_selected.emit(id)
```

- [ ] **Step 4: Write `scenes/ui/icon_rail.tscn`**

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scenes/ui/icon_rail.gd" id="1_rail"]

[node name="IconRail" type="VBoxContainer"]
script = ExtResource("1_rail")
```

- [ ] **Step 5: Run test to verify it passes**

Run: `.\tests\run_test.ps1 test_icon_rail`
Expected: all PASS, exit code 0.

- [ ] **Step 6: Commit**

```bash
git add scenes/ui/icon_rail.gd scenes/ui/icon_rail.tscn tests/test_icon_rail.gd
git commit -m "feat: icon rail rendering from module registry with lock states"
```

---

### Task 9: Ticker bar

**Files:**
- Create: `scenes/ui/ticker_bar.tscn`
- Create: `scenes/ui/ticker_bar.gd`
- Test: `tests/test_ticker_bar.gd`

**Interfaces:**
- Consumes: nothing (optionally fed by GameState.push_ticker in Main via signal connect).
- Produces: `ticker_bar.tscn` — PanelContainer root (name `TickerBar`) with a single Label. `push_message(text: String, highlight: bool = false) -> void` appends and shows immediately if it's the first; messages rotate every 6 seconds (Timer). Highlighted messages render cyan, normal dim.

- [ ] **Step 1: Write the failing test `tests/test_ticker_bar.gd`**

```gdscript
extends "res://tests/test_base.gd"

const TickerBarScene := preload("res://scenes/ui/ticker_bar.tscn")

func _run() -> void:
	var ticker := TickerBarScene.instantiate()
	root.add_child(ticker)

	var label: Label = ticker.find_children("*", "Label", true, false)[0]
	check(label.text == "", "empty on start")

	ticker.push_message("first")
	check(label.text == ">> first", "shows first message")
	ticker.push_message("second", true)
	ticker.push_message("third")
	check(label.text == ">> first", "still shows first after pushes")

	ticker._advance()
	check(label.text == ">> second", "advances to second")
	check(label.get_theme_color("font_color") == Color(0.22353, 0.81569, 1.0),
		"highlight color cyan") # may need get_theme_color override check instead
	ticker._advance()
	ticker._advance()
	check(label.text == ">> first", "wraps around")

	ticker.queue_free()
```

Note on the color assertion: `Label.get_theme_color("font_color")` returns the *effective* color; since we set it via `add_theme_color_override`, the check works. If it proves flaky, instead expose `ticker.current_is_highlight() -> bool` and assert on that — implement whichever you test.

- [ ] **Step 2: Run test to verify it fails**

Run: `.\tests\run_test.ps1 test_ticker_bar`
Expected: FAIL — scene missing.

- [ ] **Step 3: Write `scenes/ui/ticker_bar.gd`**

```gdscript
extends PanelContainer
## Bottom ticker strip: contextual messages and world events, rotating.

const COLOR_ACCENT := Color(0.22353, 0.81569, 1.0)
const COLOR_DIM := Color(0.43529, 0.5451, 0.60392, 1)
const ROTATE_SECONDS := 6.0

var _messages: Array[Dictionary] = [] # {text: String, highlight: bool}
var _index := 0
var _label: Label

func _ready() -> void:
	_label = Label.new()
	_label.text = ""
	add_child(_label)
	var timer := Timer.new()
	timer.wait_time = ROTATE_SECONDS
	timer.timeout.connect(_advance)
	add_child(timer)
	timer.start()

func push_message(text: String, highlight: bool = false) -> void:
	_messages.append({"text": text, "highlight": highlight})
	if _messages.size() == 1:
		_index = 0
		_show_current()

func current_is_highlight() -> bool:
	return not _messages.is_empty() and _messages[_index].highlight

func _advance() -> void:
	if _messages.is_empty():
		return
	_index = (_index + 1) % _messages.size()
	_show_current()

func _show_current() -> void:
	var m: Dictionary = _messages[_index]
	_label.text = ">> " + m.text
	_label.add_theme_color_override("font_color", COLOR_ACCENT if m.highlight else COLOR_DIM)
```

- [ ] **Step 4: Write `scenes/ui/ticker_bar.tscn`**

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scenes/ui/ticker_bar.gd" id="1_ticker"]

[node name="TickerBar" type="PanelContainer"]
offset_right = 800.0
offset_bottom = 30.0
script = ExtResource("1_ticker")
```

- [ ] **Step 5: Run test to verify it passes**

Run: `.\tests\run_test.ps1 test_ticker_bar`
Expected: all PASS, exit code 0. (Adjust the color assertion per the note above if needed — but keep the test and implementation in sync.)

- [ ] **Step 6: Commit**

```bash
git add scenes/ui/ticker_bar.gd scenes/ui/ticker_bar.tscn tests/test_ticker_bar.gd
git commit -m "feat: rotating ticker bar with highlight messages"
```

---

### Task 10: Home and Comms panels

**Files:**
- Create: `scenes/modules/home/home_panel.tscn`, `scenes/modules/home/home_panel.gd`
- Create: `scenes/modules/comms/comms_panel.tscn`, `scenes/modules/comms/comms_panel.gd`
- Test: `tests/test_panels_basic.gd`

**Interfaces:**
- Consumes: GameState (Task 2), `PlaceholderMessages.all()` (Task 5).
- Produces — **standard module panel contract used by Main (Task 12):** every module panel root is a `PanelContainer` and exposes `setup(gs: Node, data: Variant = null) -> void` (call after `add_child`).
  - `home_panel.tscn` (root `HomePanel`): title "OPERATIONS TERMINAL v0.1" + summary block (CREDITS / DISTRICT / DAY+clock / HEAT / ALERTS), refreshed on GameState signals.
  - `comms_panel.tscn` (root `CommsPanel`): title "COMMS" + one row per message (sender cyan+`●` when unread, dim preview). `data` = Array[Dictionary] from PlaceholderMessages.

- [ ] **Step 1: Write the failing test `tests/test_panels_basic.gd`**

```gdscript
extends "res://tests/test_base.gd"

const GameStateScript := preload("res://autoload/game_state.gd")
const HomePanel := preload("res://scenes/modules/home/home_panel.tscn")
const CommsPanel := preload("res://scenes/modules/comms/comms_panel.tscn")
const PlaceholderMessages := preload("res://data/placeholder/placeholder_messages.gd")

func _run() -> void:
	var gs := GameStateScript.new()
	gs.name = "GameState"
	root.add_child(gs)

	var home := HomePanel.instantiate()
	root.add_child(home)
	home.setup(gs)
	var home_text := ""
	for label in home.find_children("*", "Label", true, false):
		home_text += label.text + "\n"
	check(home_text.contains("OPERATIONS TERMINAL v0.1"), "home title")
	check(home_text.contains("12,480 CR"), "home shows credits")
	check(home_text.contains("LOWER VESPER"), "home shows district")
	gs.add_credits(1000)
	check(home_text.contains("13,480 CR"), "home refreshes on credits change")
	home.queue_free()

	var comms := CommsPanel.instantiate()
	root.add_child(comms)
	comms.setup(gs, PlaceholderMessages.all())
	var rows := comms.find_children("Row*", "HBoxContainer", true, false)
	check(rows.size() == 3, "three message rows — got %d" % rows.size())
	var first_row_text := ""
	for label in rows[0].find_children("*", "Label", true, false):
		first_row_text += label.text + " "
	check(first_row_text.contains("●") and first_row_text.contains("MARA"), "unread marker and sender")
	comms.queue_free()
	gs.queue_free()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `.\tests\run_test.ps1 test_panels_basic`
Expected: FAIL — scenes missing.

- [ ] **Step 3: Write `scenes/modules/home/home_panel.gd`**

```gdscript
extends PanelContainer
## Home module: operator status summary.

const GameStateScript := preload("res://autoload/game_state.gd")
const COLOR_AMBER := Color(1.0, 0.82353, 0.47843)
const COLOR_DIM := Color(0.43529, 0.5451, 0.60392, 1)

var _gs: Node
var _summary: Label

func _ready() -> void:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	add_child(vbox)
	var title := Label.new()
	title.text = "OPERATIONS TERMINAL v0.1"
	title.add_theme_font_override("font", load("res://assets/fonts/JetBrainsMono-Bold.ttf"))
	title.add_theme_font_size_override("font_size", 17)
	vbox.add_child(title)
	_summary = Label.new()
	vbox.add_child(_summary)

func setup(gs: Node, data: Variant = null) -> void:
	_gs = gs
	_gs.credits_changed.connect(_refresh)
	_gs.clock_changed.connect(_refresh)
	_gs.district_changed.connect(_refresh)
	_gs.heat_changed.connect(_refresh)
	_gs.alerts_changed.connect(_refresh)
	_refresh()

func _refresh() -> void:
	_summary.add_theme_color_override("font_color", COLOR_DIM)
	_summary.text = "\n".join([
		"CREDITS    " + GameStateScript.format_credits(_gs.credits) + " CR",
		"DISTRICT   " + _gs.district,
		"TIME       DAY %d  %s" % [_gs.day, _gs.clock_text()],
		"HEAT       " + "▲".repeat(int(_gs.heat)),
		"ALERTS     %d" % _gs.alerts,
		"",
		"> select CONTRACTS on the rail to view work",
	])
```

- [ ] **Step 4: Write `scenes/modules/home/home_panel.tscn`**

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scenes/modules/home/home_panel.gd" id="1_home"]

[node name="HomePanel" type="PanelContainer"]
offset_right = 400.0
offset_bottom = 300.0
script = ExtResource("1_home")
```

- [ ] **Step 5: Write `scenes/modules/comms/comms_panel.gd`**

```gdscript
extends PanelContainer
## Comms module: message list.

const COLOR_ACCENT := Color(0.22353, 0.81569, 1.0)
const COLOR_DIM := Color(0.43529, 0.5451, 0.60392, 1)

var _rows_box: VBoxContainer

func _ready() -> void:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	add_child(vbox)
	var title := Label.new()
	title.text = "COMMS"
	title.add_theme_font_override("font", load("res://assets/fonts/JetBrainsMono-Bold.ttf"))
	title.add_theme_font_size_override("font_size", 17)
	vbox.add_child(title)
	_rows_box = VBoxContainer.new()
	_rows_box.add_theme_constant_override("separation", 4)
	vbox.add_child(_rows_box)

func setup(_gs: Node, data: Variant = null) -> void:
	var messages: Array = data if data is Array else []
	for child in _rows_box.get_children():
		child.queue_free()
	for i in messages.size():
		_rows_box.add_child(_make_row(messages[i], i))

func _make_row(message: Dictionary, index: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "Row%d" % index
	row.add_theme_constant_override("separation", 12)
	var sender := Label.new()
	sender.custom_minimum_size.x = 110.0
	sender.text = ("● " if message.unread else "") + message.sender
	if message.unread:
		sender.add_theme_color_override("font_color", COLOR_ACCENT)
	var preview := Label.new()
	preview.text = message.preview
	preview.add_theme_color_override("font_color", COLOR_DIM)
	preview.clip_text = true
	preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sender)
	row.add_child(preview)
	return row
```

- [ ] **Step 6: Write `scenes/modules/comms/comms_panel.tscn`**

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scenes/modules/comms/comms_panel.gd" id="1_comms"]

[node name="CommsPanel" type="PanelContainer"]
offset_right = 400.0
offset_bottom = 300.0
script = ExtResource("1_comms")
```

- [ ] **Step 7: Run test to verify it passes**

Run: `.\tests\run_test.ps1 test_panels_basic`
Expected: all PASS, exit code 0.

- [ ] **Step 8: Commit**

```bash
git add scenes/modules/home/ scenes/modules/comms/ tests/test_panels_basic.gd
git commit -m "feat: home and comms module panels"
```

---

### Task 11: Contracts panel + contract detail (context content)

**Files:**
- Create: `scenes/modules/contracts/contracts_panel.tscn`, `scenes/modules/contracts/contracts_panel.gd`
- Create: `scenes/modules/contracts/contract_detail.tscn`, `scenes/modules/contracts/contract_detail.gd`
- Test: `tests/test_contracts.gd`

**Interfaces:**
- Consumes: `PlaceholderContracts.all()` (Task 5), module panel contract (`setup(gs, data)`).
- Produces:
  - `contracts_panel.tscn` (root `ContractsPanel`): PanelContainer, title "CONTRACT NETWORK", one Button per contract (`"<title>  —  <reward>"`, encrypted shows `"?????"` in red). Signal `contract_selected(contract: Dictionary)`.
  - `contract_detail.tscn` (root `ContractDetail`): PanelContainer used as context-panel content. `setup(gs, data)` fills title + body; encrypted contracts render `?????` fields and a decrypt hint.

- [ ] **Step 1: Write the failing test `tests/test_contracts.gd`**

```gdscript
extends "res://tests/test_base.gd"

const GameStateScript := preload("res://autoload/game_state.gd")
const ContractsPanel := preload("res://scenes/modules/contracts/contracts_panel.tscn")
const ContractDetail := preload("res://scenes/modules/contracts/contract_detail.tscn")
const PlaceholderContracts := preload("res://data/placeholder/placeholder_contracts.gd")

func _run() -> void:
	var gs := GameStateScript.new()
	gs.name = "GameState"
	root.add_child(gs)

	var panel := ContractsPanel.instantiate()
	root.add_child(panel)

	var seen := [{}]
	panel.contract_selected.connect(func(c: Dictionary) -> void: seen[0] = c)
	panel.setup(gs, PlaceholderContracts.all())

	var buttons: Array[Button] = []
	for child in panel.find_children("*", "Button", true, false):
		buttons.append(child)
	check(buttons.size() == 3, "three contract rows")
	check(buttons[0].text.contains("Freight Transfer") and buttons[0].text.contains("1,400 CR"),
		"row text with formatted reward")
	check(buttons[2].text.contains("[ENCRYPTED OFFER]") and buttons[2].text.contains("?????"),
		"encrypted row hides reward")

	buttons[1].pressed.emit()
	check(seen[0].get("id", &"") == &"data_retrieval", "selecting row emits contract")
	buttons[2].pressed.emit()
	check(seen[0].get("id", &"") == &"data_retrieval", "encrypted row does not emit")
	panel.queue_free()

	var detail := ContractDetail.instantiate()
	root.add_child(detail)
	detail.setup(gs, PlaceholderContracts.all()[1])
	var detail_text := ""
	for label in detail.find_children("*", "Label", true, false):
		detail_text += label.text + "\n"
	check(detail_text.contains("Data Retrieval"), "detail title")
	check(detail_text.contains("4,200 CR") and detail_text.contains("SECTOR 9"), "detail body fields")
	detail.setup(gs, PlaceholderContracts.all()[2])
	var enc_text := ""
	for label in detail.find_children("*", "Label", true, false):
		enc_text += label.text + "\n"
	check(enc_text.contains("?????") and enc_text.contains("ENCRYPTED"), "encrypted detail redacted")
	detail.queue_free()
	gs.queue_free()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `.\tests\run_test.ps1 test_contracts`
Expected: FAIL — scenes missing.

- [ ] **Step 3: Write `scenes/modules/contracts/contracts_panel.gd`**

```gdscript
extends PanelContainer
## Contracts module: the contract network list.

signal contract_selected(contract: Dictionary)

const GameStateScript := preload("res://autoload/game_state.gd")
const COLOR_DIM := Color(0.43529, 0.5451, 0.60392, 1)

var _rows_box: VBoxContainer

func _ready() -> void:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	add_child(vbox)
	var title := Label.new()
	title.text = "CONTRACT NETWORK"
	title.add_theme_font_override("font", load("res://assets/fonts/JetBrainsMono-Bold.ttf"))
	title.add_theme_font_size_override("font_size", 17)
	vbox.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Local          Private"
	subtitle.add_theme_color_override("font_color", COLOR_DIM)
	vbox.add_child(subtitle)
	_rows_box = VBoxContainer.new()
	_rows_box.add_theme_constant_override("separation", 4)
	vbox.add_child(_rows_box)

func setup(_gs: Node, data: Variant = null) -> void:
	var contracts: Array = data if data is Array else []
	for child in _rows_box.get_children():
		child.queue_free()
	for contract: Dictionary in contracts:
		var btn := Button.new()
		btn.text = _row_text(contract)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(_on_row.bind(contract))
		_rows_box.add_child(btn)

func _row_text(contract: Dictionary) -> String:
	var reward := "?????" if contract.encrypted else GameStateScript.format_credits(contract.reward_credits) + " CR"
	return "%s   %s" % [contract.title, reward]

func _on_row(contract: Dictionary) -> void:
	if contract.encrypted:
		return # cannot open an encrypted offer yet
	contract_selected.emit(contract)
```

- [ ] **Step 4: Write `scenes/modules/contracts/contracts_panel.tscn`**

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scenes/modules/contracts/contracts_panel.gd" id="1_contracts"]

[node name="ContractsPanel" type="PanelContainer"]
offset_right = 400.0
offset_bottom = 300.0
script = ExtResource("1_contracts")
```

- [ ] **Step 5: Write `scenes/modules/contracts/contract_detail.gd`**

```gdscript
extends PanelContainer
## Contract detail — shown in the context panel next to the list.

const GameStateScript := preload("res://autoload/game_state.gd")
const COLOR_ALERT := Color(1.0, 0.35294, 0.47059)
const COLOR_AMBER := Color(1.0, 0.82353, 0.47843)
const COLOR_DIM := Color(0.43529, 0.5451, 0.60392, 1)

var _title: Label
var _body: Label

func _ready() -> void:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	add_child(vbox)
	_title = Label.new()
	_title.add_theme_font_override("font", load("res://assets/fonts/JetBrainsMono-Bold.ttf"))
	_title.add_theme_font_size_override("font_size", 16)
	vbox.add_child(_title)
	_body = Label.new()
	vbox.add_child(_body)

func setup(_gs: Node, data: Variant = null) -> void:
	var c: Dictionary = data if data is Dictionary else {}
	if c.is_empty():
		_title.text = ""
		_body.text = ""
		return
	_title.text = c.title
	if c.encrypted:
		_body.add_theme_color_override("font_color", COLOR_ALERT)
		_body.text = "\n".join([
			"CLIENT      ?????",
			"REWARD      ?????",
			"RISK        ?????",
			"DISTRICT    ?????",
			"",
			"> OFFER ENCRYPTED — a trusted contact is required to decrypt",
		])
	else:
		_body.add_theme_color_override("font_color", COLOR_DIM)
		_body.text = "\n".join([
			"CLIENT      " + c.client,
			"REWARD      " + GameStateScript.format_credits(c.reward_credits) + " CR",
			"RISK        " + c.risk,
			"DISTRICT    " + c.district,
		])
```

- [ ] **Step 6: Write `scenes/modules/contracts/contract_detail.tscn`**

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scenes/modules/contracts/contract_detail.gd" id="1_detail"]

[node name="ContractDetail" type="PanelContainer"]
offset_right = 360.0
offset_bottom = 260.0
script = ExtResource("1_detail")
```

- [ ] **Step 7: Run test to verify it passes**

Run: `.\tests\run_test.ps1 test_contracts`
Expected: all PASS, exit code 0.

- [ ] **Step 8: Commit**

```bash
git add scenes/modules/contracts/ tests/test_contracts.gd
git commit -m "feat: contracts list panel and detail view for context panel"
```

---

### Task 12: Main assembly — workspace, layout, switching, collapse

**Files:**
- Create: `scenes/main/main.tscn`, `scenes/main/main.gd`
- Modify: `project.godot` (add main scene)
- Test: `tests/test_main.gd`

**Interfaces:**
- Consumes: everything above (GameState, registry, chip, rail, ticker, environment, 3 module panels, detail, placeholder data).
- Produces: `main.tscn` — the game's main scene. Public API on `main.gd`:
  - `select_module(id: StringName) -> void` — swaps primary panel; un-collapses if collapsed; highlights rail
  - `open_context(content: Control) -> void` / `close_context() -> void` — context panel with auto-layout
  - `set_collapsed(collapsed: bool) -> void` — delegates to GameState (single source of truth)
  - Node paths (used by tests): `primary_host`, `context_host`, `icon_rail`, `status_chip`, `ticker`, `collapse_button` — direct children of `Workspace`, which is a direct child of Main.
  - Layout rule: rail at left margin; primary panel fills remaining width (62% when context open, context takes the rest); chip top-center; ticker full-width bottom; all recomputed on resize.

- [ ] **Step 1: Write the failing test `tests/test_main.gd`**

```gdscript
extends "res://tests/test_base.gd"

const GameStateScript := preload("res://autoload/game_state.gd")
const MainScene := preload("res://scenes/main/main.tscn")

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

	main.select_module(&"contracts")
	check(primary.get_child(0).name == "ContractsPanel", "module switching swaps panel")

	var wide: float = primary.size.x
	main.open_context(load("res://scenes/modules/contracts/contract_detail.tscn").instantiate())
	check(context.visible and context.get_child_count() == 1, "context opens with content")
	check(primary.size.x < wide, "primary shrinks when context opens")

	main.close_context()
	check(not context.visible, "context closes")

	gs.set_workspace_collapsed(true)
	check(not primary.visible, "collapse hides primary panel")
	check(not context.visible, "collapse hides context panel")
	check(workspace.get_node("StatusChip").visible, "chip survives collapse")
	check(workspace.get_node("IconRail").visible, "rail survives collapse")
	check(workspace.get_node("TickerBar").visible, "ticker survives collapse")

	main.select_module(&"comms")
	check(not gs.workspace_collapsed, "selecting a module un-collapses")
	check(primary.visible and primary.get_child(0).name == "CommsPanel", "comms open after un-collapse")

	main.queue_free()
	gs.queue_free()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `.\tests\run_test.ps1 test_main`
Expected: FAIL — main scene missing.

- [ ] **Step 3: Write `scenes/main/main.gd`**

```gdscript
extends Control
## Main: owns the environment, the workspace shell, module switching,
## context panel, and collapse behavior. GameState is the single source
## of truth for collapse state.

const GameStateScript := preload("res://autoload/game_state.gd")

const MODULE_SCENES := {
	&"home": preload("res://scenes/modules/home/home_panel.tscn"),
	&"comms": preload("res://scenes/modules/comms/comms_panel.tscn"),
	&"contracts": preload("res://scenes/modules/contracts/contracts_panel.tscn"),
}
const ContractDetailScene := preload("res://scenes/modules/contracts/contract_detail.tscn")
const EnvironmentScene := preload("res://scenes/main/environment.tscn")
const StatusChipScene := preload("res://scenes/ui/status_chip.tscn")
const IconRailScene := preload("res://scenes/ui/icon_rail.tscn")
const TickerBarScene := preload("res://scenes/ui/ticker_bar.tscn")
const PlaceholderContracts := preload("res://data/placeholder/placeholder_contracts.gd")
const PlaceholderMessages := preload("res://data/placeholder/placeholder_messages.gd")

const MARGIN := 16.0
const RAIL_WIDTH := 44.0
const RAIL_GAP := 16.0
const CHIP_TOP := 12.0
const CHIP_GAP := 14.0
const TICKER_HEIGHT := 30.0
const CONTEXT_SPLIT := 0.62
const CONTEXT_GAP := 12.0

var gs: Node
var workspace: Control
var status_chip: Control
var collapse_button: Button
var icon_rail: Control
var primary_host: Control
var context_host: Control
var ticker: Control

func _ready() -> void:
	gs = get_node_or_null("/root/GameState")
	if gs == null:
		push_error("GameState autoload missing — cannot start")
		return
	theme = load("res://resources/operator_theme.tres")

	var environment := EnvironmentScene.instantiate()
	add_child(environment)

	workspace = Control.new()
	workspace.name = "Workspace"
	workspace.set_anchors_preset(Control.PRESET_FULL_RECT)
	workspace.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(workspace)

	_build_status_chip()
	_build_collapse_button()
	_build_rail()
	_build_panel_hosts()
	_build_ticker()

	gs.workspace_collapsed_changed.connect(_on_collapsed_changed)
	gs.ticker_message.connect(func(text: String, highlight: bool) -> void: ticker.push_message(text, highlight))
	icon_rail.module_selected.connect(select_module)
	collapse_button.pressed.connect(func() -> void: gs.toggle_workspace())

	select_module(&"home")
	_apply_layout()
	workspace.resized.connect(_apply_layout)

func _build_status_chip() -> void:
	status_chip = StatusChipScene.instantiate()
	status_chip.name = "StatusChip"
	workspace.add_child(status_chip)
	status_chip.setup(gs)

func _build_collapse_button() -> void:
	collapse_button = Button.new()
	collapse_button.name = "CollapseToggle"
	collapse_button.text = "⧉"
	collapse_button.tooltip_text = "Collapse workspace"
	collapse_button.focus_mode = Control.FOCUS_NONE
	collapse_button.custom_minimum_size = Vector2(32, 32)
	workspace.add_child(collapse_button)

func _build_rail() -> void:
	icon_rail = IconRailScene.instantiate()
	icon_rail.name = "IconRail"
	workspace.add_child(icon_rail)
	icon_rail.setup(load("res://resources/module_registry.tres"))

func _build_panel_hosts() -> void:
	primary_host = Control.new()
	primary_host.name = "PrimaryHost"
	primary_host.clip_contents = true
	primary_host.mouse_filter = Control.MOUSE_FILTER_PASS
	workspace.add_child(primary_host)
	context_host = Control.new()
	context_host.name = "ContextHost"
	context_host.visible = false
	context_host.clip_contents = true
	context_host.mouse_filter = Control.MOUSE_FILTER_PASS
	workspace.add_child(context_host)

func _build_ticker() -> void:
	ticker = TickerBarScene.instantiate()
	ticker.name = "TickerBar"
	workspace.add_child(ticker)
	ticker.push_message("NEW MESSAGE // MARA", true)
	ticker.push_message("contract expiring: cold-chain delivery, Docks")
	ticker.push_message("rumor: corp sweep, Sector 9 tonight")

func select_module(id: StringName) -> void:
	if not MODULE_SCENES.has(id):
		return
	if gs.workspace_collapsed:
		gs.set_workspace_collapsed(false)
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
	if icon_rail.has_method("set_active"):
		icon_rail.set_active(id)
	_apply_layout()

func open_context(content: Control) -> void:
	for child in context_host.get_children():
		context_host.remove_child(child)
		child.queue_free()
	context_host.add_child(content)
	context_host.visible = true
	_apply_layout()

func close_context() -> void:
	for child in context_host.get_children():
		context_host.remove_child(child)
		child.queue_free()
	context_host.visible = false
	_apply_layout()

func set_collapsed(collapsed: bool) -> void:
	gs.set_workspace_collapsed(collapsed)

func _on_contract_selected(contract: Dictionary) -> void:
	var detail: Control = ContractDetailScene.instantiate()
	open_context(detail)
	detail.setup(gs, contract)

func _on_collapsed_changed(collapsed: bool) -> void:
	_apply_workspace_visibility(collapsed)
	_apply_layout()
	if collapsed:
		return
	var tween := create_tween()
	primary_host.modulate.a = 0.0
	tween.tween_property(primary_host, "modulate:a", 1.0, 0.15)

func _apply_workspace_visibility(collapsed: bool) -> void:
	primary_host.visible = not collapsed
	context_host.visible = not collapsed and context_host.get_child_count() > 0
	collapse_button.tooltip_text = "Expand workspace" if collapsed else "Collapse workspace"

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
	var panel_left: float = MARGIN + RAIL_WIDTH + RAIL_GAP
	var available_right: float = ws_size.x - MARGIN
	var context_open: bool = context_host.visible
	var primary_right: float = available_right
	if context_open:
		primary_right = panel_left + (available_right - panel_left) * CONTEXT_SPLIT - CONTEXT_GAP * 0.5
	primary_host.position = Vector2(panel_left, content_top)
	primary_host.size = Vector2(primary_right - panel_left, content_bottom - content_top)
	if context_open:
		context_host.position = Vector2(primary_right + CONTEXT_GAP, content_top)
		context_host.size = Vector2(available_right - primary_right - CONTEXT_GAP, content_bottom - content_top)
	for panel in primary_host.get_children():
		panel.size = primary_host.size
	for panel in context_host.get_children():
		panel.size = context_host.size
```

- [ ] **Step 4: Write `scenes/main/main.tscn`**

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scenes/main/main.gd" id="1_main"]

[node name="Main" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
script = ExtResource("1_main")
```

- [ ] **Step 5: Set the main scene in `project.godot`**

In the `[application]` section, add:

```ini
run/main_scene="res://scenes/main/main.tscn"
```

- [ ] **Step 6: Run test to verify it passes**

Run: `.\tests\run_test.ps1 test_main`
Expected: all PASS, exit code 0. If `primary.size.x` assertions fail because `workspace.size` is zero in the headless test, note that `_apply_layout` falls back to 1920×1080 — verify the fallback line exists and re-run.

- [ ] **Step 7: Run the full test suite**

```powershell
.\tests\run_test.ps1 test_smoke
.\tests\run_test.ps1 test_game_state
.\tests\run_test.ps1 test_module_registry
.\tests\run_test.ps1 test_theme
.\tests\run_test.ps1 test_placeholder_data
.\tests\run_test.ps1 test_status_chip
.\tests\run_test.ps1 test_icon_rail
.\tests\run_test.ps1 test_ticker_bar
.\tests\run_test.ps1 test_panels_basic
.\tests\run_test.ps1 test_contracts
.\tests\run_test.ps1 test_main
```

Expected: every run ends `RESULT: ALL PASSED`.

- [ ] **Step 8: Visual verification (success criteria walkthrough)**

Run the project (godot-mcp `run_project`, no scene argument — uses main scene). Verify each item from the spec's success criteria:

1. Game boots straight into the terminal shell
2. Rail switches Home / Comms / Contracts without flicker
3. Selecting a contract row opens the detail in a context panel beside the list; primary shrinks; closing restores
4. Collapse toggle (⧉, top-right) hides panels; chip + rail + ticker + environment remain; clicking a rail module restores the workspace with that module
5. Crew / Market / Map visible greyed with lock tooltips; no other locked modules shown
6. Resize the window to roughly 1280×720 — layout stays clean (no overlap, ticker and chip intact)
7. Environment shows rain, neon flicker, subtle parallax on mouse move

Fix anything that fails visually, re-run tests, and repeat until all seven pass.

- [ ] **Step 9: Commit**

```bash
git add scenes/main/main.gd scenes/main/main.tscn project.godot tests/test_main.gd
git commit -m "feat: main assembly — workspace shell, module switching, collapse"
```

---

## Final task: wrap-up

- [ ] Run the full test suite one last time (all 11 tests, all pass)
- [ ] `git status` — confirm clean tree (`.godot/` and `.superpowers/` are gitignored)
- [ ] Report to the user with a summary of what was built and how to run it
