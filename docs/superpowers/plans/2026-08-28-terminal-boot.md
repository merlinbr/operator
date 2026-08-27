# Terminal Boot Sequence Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a brief, immediately skippable terminal boot scene that reveals opening diagnostics and routes into the unchanged operations workspace.

**Architecture:** A new full-viewport `Boot` Control owns all local timer, input, reveal, and fade state; its `enter_requested` signal connects to its own scene-routing callback. `project.godot` starts Boot, which preloads and transitions to the existing Main scene. Boot does not access, construct, or modify GameState or workspace code.

**Tech Stack:** Godot 4.7.1, GDScript, existing native `Control` nodes and `Tween`, existing operator theme and JetBrains Mono, existing headless `SceneTree` test harness, PowerShell.

## Global Constraints

- Project entry scene becomes `res://scenes/boot/boot.tscn`; successful entry routes to unchanged `res://scenes/main/main.tscn`.
- Render this exact title and diagnostic copy in order: `OPERATOR // LOCAL TERMINAL`; `NODE       LOWER VESPER`; `UPLINK     SECURE`; `LOCAL TIME DAY 14 // 23:41`; `WORK QUEUE 01 AVAILABLE`; `MESSAGE    MARA // UNREAD`.
- The five diagnostics begin hidden and reveal in order at exactly 0.9-second intervals. `ENTER OPERATIONS` is visible and enabled from the first frame.
- Button press, primary background click, `ui_accept`, `ui_cancel`, or any non-echo pressed key call the same entry path.
- First entry reveals all diagnostics, stops the timer, emits `enter_requested`, fades the panel over exactly 0.2 seconds, and changes scene. Later entry inputs do nothing.
- Use `res://resources/operator_theme.tres`, existing JetBrains Mono fonts, native Controls, and a near-black background `Color(0.012, 0.020, 0.031, 1.0)`.
- Boot has no save/profile/settings/options/audio/new art/shader/gameplay initialization or GameState access.
- Do not modify Main, GameState, contracts, environment, HUD, rail, ticker, Comms, theme, or workspace layout.
- Prefix every shell command with `rtk`.

---

## File Map

| File | Responsibility after this plan |
|---|---|
| `scenes/boot/boot.tscn` | Full-viewport Boot scene root, with `boot.gd` attached. |
| `scenes/boot/boot.gd` | Programmatic terminal layout, diagnostic timer, immediate skip/input routing, duplicate guard, fade, and Main scene transition. |
| `project.godot` | Changes `run/main_scene` to Boot. |
| `tests/test_boot.gd` | Headless rendering, ordered reveal, input/skip, duplicate-entry, and signal-intent tests without scene routing. |
| `tests/test_smoke.gd` | Loads and initializes Boot so the configured entry scene has a smoke contract. |
| `README.md` | Correctly identifies Boot as the entry scene and Main as the operations workspace scene. |

## Runtime Interfaces

```gdscript
# Boot
signal enter_requested

func _reveal_next_line() -> void
func _enter_operations() -> void
func _on_enter_requested() -> void
func _on_unhandled_input(event: InputEvent) -> void
```

Tests disconnect the private production connection below before triggering entry:

```gdscript
if boot.enter_requested.is_connected(boot._on_enter_requested):
    boot.enter_requested.disconnect(boot._on_enter_requested)
```

This leaves the production scene self-routing while preventing headless tests from replacing the test harness scene tree.

---

### Task 1: Build and test the self-contained Boot scene

**Files:**
- Create: `scenes/boot/boot.tscn`
- Create: `scenes/boot/boot.gd`
- Create: `tests/test_boot.gd`

**Interfaces:**
- Consumes: existing `operator_theme.tres`, JetBrains Mono fonts, and `main.tscn` as the sole transition target.
- Produces: the `Boot` scene signal/method interface above. It is independently testable without loading Main.

- [ ] **Step 1: Write the failing Boot test**

Create `tests/test_boot.gd`:

```gdscript
extends "res://tests/test_base.gd"

const BootScene := preload("res://scenes/boot/boot.tscn")

func _run() -> void:
    var boot: Control = BootScene.instantiate()
    root.add_child(boot)
    _suppress_routing(boot)

    var title: Label = boot.get_node("Center/BootPanel/Content/Title")
    var diagnostics: VBoxContainer = boot.get_node("Center/BootPanel/Content/Diagnostics")
    var enter: Button = boot.get_node("Center/BootPanel/Content/EnterOperations")
    var timer: Timer = boot.get_node("DiagnosticTimer")
    check(title.text == "OPERATOR // LOCAL TERMINAL", "boot title is exact")
    check(diagnostics.get_child_count() == 5, "boot has five diagnostics")
    check(enter.text == "ENTER OPERATIONS" and not enter.disabled and enter.visible,
        "entry action is immediate and enabled")
    check(timer.wait_time == 0.9 and not timer.one_shot and not timer.is_stopped(),
        "diagnostic timer starts at the authored cadence")

    var expected := [
        "NODE       LOWER VESPER",
        "UPLINK     SECURE",
        "LOCAL TIME DAY 14 // 23:41",
        "WORK QUEUE 01 AVAILABLE",
        "MESSAGE    MARA // UNREAD",
    ]
    for index in diagnostics.get_child_count():
        var line := diagnostics.get_child(index) as Label
        check(line.text == expected[index] and not line.visible,
            "diagnostic %d starts hidden with exact copy" % index)

    for index in diagnostics.get_child_count():
        boot._reveal_next_line()
        for line_index in diagnostics.get_child_count():
            var line := diagnostics.get_child(line_index) as Label
            check(line.visible == (line_index <= index),
                "reveal %d shows only the expected prefix" % index)
    boot._reveal_next_line()
    check(timer.is_stopped(), "extra reveal is a safe no-op after completion")

    var enter_count := [0]
    boot.enter_requested.connect(func() -> void: enter_count[0] += 1)
    boot._enter_operations()
    check(boot._entering and timer.is_stopped() and enter_count[0] == 1,
        "entry marks the boot as entering, stops timer, and emits once")
    for line in diagnostics.get_children():
        check((line as Label).visible, "entry reveals every remaining diagnostic")
    boot._enter_operations()
    check(enter_count[0] == 1, "second entry attempt is ignored")
    boot.queue_free()

    var key_boot: Control = BootScene.instantiate()
    root.add_child(key_boot)
    _suppress_routing(key_boot)
    var key_count := [0]
    key_boot.enter_requested.connect(func() -> void: key_count[0] += 1)
    var key := InputEventKey.new()
    key.pressed = true
    key.keycode = KEY_A
    key_boot._on_unhandled_input(key)
    check(key_boot._entering and key_count[0] == 1,
        "non-echo pressed key routes through entry")
    key_boot.queue_free()

    var action_boot: Control = BootScene.instantiate()
    root.add_child(action_boot)
    _suppress_routing(action_boot)
    var action_count := [0]
    action_boot.enter_requested.connect(func() -> void: action_count[0] += 1)
    var action := InputEventAction.new()
    action.action = &"ui_accept"
    action.pressed = true
    action_boot._on_unhandled_input(action)
    check(action_boot._entering and action_count[0] == 1,
        "ui_accept routes through entry")
    action_boot.queue_free()

func _suppress_routing(boot: Control) -> void:
    if boot.enter_requested.is_connected(boot._on_enter_requested):
        boot.enter_requested.disconnect(boot._on_enter_requested)
```

- [ ] **Step 2: Run the Boot test and confirm it fails before the scene exists**

Run:

```powershell
rtk powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\run_test.ps1 test_boot
```

Expected: Godot fails to preload `res://scenes/boot/boot.tscn` because Boot has not been created.

- [ ] **Step 3: Create the Boot scene host**

Create `scenes/boot/boot.tscn`:

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scenes/boot/boot.gd" id="1_boot"]

[node name="Boot" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
script = ExtResource("1_boot")
```

- [ ] **Step 4: Implement Boot’s native Control layout and diagnostic state**

Create `scenes/boot/boot.gd`:

```gdscript
extends Control

signal enter_requested

const MainScene := preload("res://scenes/main/main.tscn")
const REVEAL_SECONDS := 0.9
const FADE_SECONDS := 0.2
const DIAGNOSTICS := [
    "NODE       LOWER VESPER",
    "UPLINK     SECURE",
    "LOCAL TIME DAY 14 // 23:41",
    "WORK QUEUE 01 AVAILABLE",
    "MESSAGE    MARA // UNREAD",
]

var _panel: PanelContainer
var _diagnostics: Array[Label] = []
var _timer: Timer
var _entering := false
var _revealed := 0
var _fade_tween: Tween

func _ready() -> void:
    theme = load("res://resources/operator_theme.tres")
    mouse_filter = Control.MOUSE_FILTER_STOP
    _build_children()
    enter_requested.connect(_on_enter_requested)
    _timer.start()

func _build_children() -> void:
    var background := ColorRect.new()
    background.name = "Background"
    background.color = Color(0.012, 0.020, 0.031, 1.0)
    background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    background.set_anchors_preset(Control.PRESET_FULL_RECT)
    add_child(background)

    var center := CenterContainer.new()
    center.name = "Center"
    center.set_anchors_preset(Control.PRESET_FULL_RECT)
    add_child(center)

    _panel = PanelContainer.new()
    _panel.name = "BootPanel"
    _panel.custom_minimum_size.x = 480.0
    center.add_child(_panel)

    var content := VBoxContainer.new()
    content.name = "Content"
    content.add_theme_constant_override("separation", 10)
    _panel.add_child(content)

    var title := Label.new()
    title.name = "Title"
    title.text = "OPERATOR // LOCAL TERMINAL"
    title.add_theme_font_override("font", load("res://assets/fonts/JetBrainsMono-Bold.ttf"))
    title.add_theme_font_size_override("font_size", 18)
    content.add_child(title)

    var divider := HSeparator.new()
    content.add_child(divider)

    var diagnostics := VBoxContainer.new()
    diagnostics.name = "Diagnostics"
    diagnostics.add_theme_constant_override("separation", 4)
    content.add_child(diagnostics)
    for text: String in DIAGNOSTICS:
        var line := Label.new()
        line.text = text
        line.visible = false
        diagnostics.add_child(line)
        _diagnostics.append(line)

    var enter := Button.new()
    enter.name = "EnterOperations"
    enter.text = "ENTER OPERATIONS"
    enter.focus_mode = Control.FOCUS_ALL
    enter.pressed.connect(_enter_operations)
    content.add_child(enter)

    _timer = Timer.new()
    _timer.name = "DiagnosticTimer"
    _timer.wait_time = REVEAL_SECONDS
    _timer.timeout.connect(_reveal_next_line)
    add_child(_timer)
```

- [ ] **Step 5: Implement reveal, all input paths, duplicate guard, and self-routing**

Append to `boot.gd`:

```gdscript
func _reveal_next_line() -> void:
    if _revealed >= _diagnostics.size():
        _timer.stop()
        return
    _diagnostics[_revealed].visible = true
    _revealed += 1
    if _revealed == _diagnostics.size():
        _timer.stop()

func _enter_operations() -> void:
    if _entering:
        return
    _entering = true
    _timer.stop()
    for line in _diagnostics:
        line.visible = true
    _revealed = _diagnostics.size()
    enter_requested.emit()

func _on_enter_requested() -> void:
    _fade_tween = create_tween()
    _fade_tween.tween_property(_panel, "modulate:a", 0.0, FADE_SECONDS)
    _fade_tween.tween_callback(func() -> void:
        get_tree().change_scene_to_packed(MainScene))

func _on_unhandled_input(event: InputEvent) -> void:
    if _entering:
        return
    if event.is_action_pressed(&"ui_accept") or event.is_action_pressed(&"ui_cancel"):
        _enter_operations()
        get_viewport().set_input_as_handled()
        return
    if event is InputEventKey and event.pressed and not event.echo:
        _enter_operations()
        get_viewport().set_input_as_handled()

func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        _enter_operations()
```

Do not add click handling to the background node: root `Control` owns background clicks, while its child Button handles its own press and routes to the same guarded method.

- [ ] **Step 6: Run the Boot test and verify it passes**

Run:

```powershell
rtk powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\run_test.ps1 test_boot
```

Expected: `RESULT: ALL PASSED`, proving exact content, immediate entry action, ordered reveal, safe timer completion, key/action skip inputs, full reveal on entry, and one emitted intent.

- [ ] **Step 7: Commit the Boot scene and focused test**

```powershell
rtk git add scenes/boot/boot.tscn scenes/boot/boot.gd tests/test_boot.gd
git commit -m "feat: add terminal boot sequence"
```

---

### Task 2: Make Boot the project entry and protect startup routing

**Files:**
- Modify: `project.godot`
- Modify: `tests/test_smoke.gd`

**Interfaces:**
- Consumes: Task 1’s `BootScene` and its independently tested immediate initialization.
- Produces: Boot as project main scene and a smoke assertion that the configured entry scene creates its initial visible controls.

- [ ] **Step 1: Replace the trivial smoke assertion with an entry-scene smoke test**

Replace `tests/test_smoke.gd` with:

```gdscript
extends "res://tests/test_base.gd"

const BootScene := preload("res://scenes/boot/boot.tscn")

func _run() -> void:
    var boot: Control = BootScene.instantiate()
    root.add_child(boot)
    check(boot.get_node_or_null("Center/BootPanel/Content/EnterOperations") is Button,
        "configured boot scene builds its immediate entry action")
    check(boot.get_node_or_null("DiagnosticTimer") is Timer,
        "configured boot scene starts its diagnostic timer")
    boot.queue_free()
```

- [ ] **Step 2: Run the smoke test and confirm it passes against the Boot implementation**

Run:

```powershell
rtk powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\run_test.ps1 test_smoke
```

Expected: `RESULT: ALL PASSED`; Boot instantiates headlessly with its first-frame controls.

- [ ] **Step 3: Point the project main scene at Boot**

In `project.godot`, replace:

```ini
run/main_scene="res://scenes/main/main.tscn"
```

with:

```ini
run/main_scene="res://scenes/boot/boot.tscn"
```

Do not alter the existing autoload, display, rendering, or physics configuration.

- [ ] **Step 4: Run the smoke test and headless project import check**

Run:

```powershell
rtk powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\run_test.ps1 test_smoke
rtk powershell -NoProfile -Command "& 'C:\Users\merli\Documents\Godot Projects\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --editor --quit"
```

Expected: `test_smoke` prints `RESULT: ALL PASSED`; the editor import pass exits without scene/script parser errors.

- [ ] **Step 5: Commit Boot entry configuration and smoke coverage**

```powershell
rtk git add project.godot tests/test_smoke.gd
git commit -m "feat: launch through terminal boot"
```

---

### Task 3: Update entry documentation and verify the real surface

**Files:**
- Modify: `README.md`
- Verify: `scenes/boot/boot.tscn`
- Verify: `scenes/boot/boot.gd`
- Verify: `project.godot`
- Verify: `tests/test_boot.gd`
- Verify: `tests/test_smoke.gd`

**Interfaces:**
- Consumes: completed Boot entry scene and project configuration.
- Produces: accurate opening instructions, complete headless proof, and an observed click/key route into the unchanged operations workspace.

- [ ] **Step 1: Correct README’s entry-scene instruction**

In `README.md`, replace the sentence:

```markdown
Open the project folder in the Godot editor and run — the main scene is `res://scenes/main/main.tscn`.
```

with:

```markdown
Open the project folder in the Godot editor and run — `res://scenes/boot/boot.tscn` is the entry scene and routes to the operations workspace at `res://scenes/main/main.tscn`.
```

In the Testing paragraph, add `test_boot` to the listed test files after `test_smoke`.

- [ ] **Step 2: Run focused Boot and startup tests**

Run:

```powershell
rtk powershell -NoProfile -Command "\$tests = 'test_boot','test_smoke'; foreach (\$test in \$tests) { & .\tests\run_test.ps1 \$test; if (\$LASTEXITCODE -ne 0) { exit \$LASTEXITCODE } }"
```

Expected: both tests print `RESULT: ALL PASSED`.

- [ ] **Step 3: Run the complete headless suite, including Boot**

Run:

```powershell
rtk powershell -NoProfile -Command "\$tests = 'test_boot','test_smoke','test_game_state','test_module_registry','test_theme','test_contract_catalog','test_status_chip','test_icon_rail','test_ticker_bar','test_panels_basic','test_contracts','test_main','test_environment'; foreach (\$test in \$tests) { & .\tests\run_test.ps1 \$test; if (\$LASTEXITCODE -ne 0) { exit \$LASTEXITCODE } }"
```

Expected: every test prints `RESULT: ALL PASSED`.

- [ ] **Step 4: Launch and exercise the actual boot route**

Run:

```powershell
rtk powershell -NoProfile -Command "& 'C:\Users\merli\Documents\Godot Projects\Godot_v4.7.1-stable_win64_console.exe' --path ."
```

Verify on fresh launches:

1. Title and immediate `ENTER OPERATIONS` button appear at first frame while diagnostics reveal one line about every 0.9 seconds.
2. Button click transitions into the existing Home workspace after a short 0.2-second panel fade.
3. Enter, Escape, a letter key, and primary background click each skip the diagnostic and route into the same workspace.
4. Repeated input during the fade does not open multiple scenes or produce errors.
5. Existing status HUD, rail, Home panel, Contract Network, apartment environment, and ticker appear unchanged after entry.

- [ ] **Step 5: Commit entry documentation**

```powershell
rtk git add README.md
git commit -m "docs: describe terminal boot entry"
```

## Plan Self-Review

- **Spec coverage:** Task 1 implements exact copy, immediate button, 0.9-second ordered reveal, all required entry inputs, duplicate guard, 0.2-second fade, self-routing signal boundary, visual structure, and focused behavioral tests. Task 2 makes Boot the sole project entry and verifies it imports. Task 3 updates user-facing entry documentation, runs focused/full suites, and manually exercises every visible input route.
- **Placeholder scan:** No unfilled work markers, deferred implementation language, unspecified tests, or unspecified error handling remains.
- **Type consistency:** `enter_requested`, `_reveal_next_line`, `_enter_operations`, `_on_enter_requested`, and `_on_unhandled_input` have one consistent shape from tests through implementation. The node paths asserted in `test_boot.gd` match the programmatic names `Center/BootPanel/Content/{Title,Diagnostics,EnterOperations}` and root `DiagnosticTimer`.
