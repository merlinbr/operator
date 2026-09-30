# Operator Dossier Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an unlocked, read-only Dossier module showing derived work signature, current exposure and relationships, and past operations.

**Architecture:** GameState builds a detached snapshot from validated contract state and existing contact/Heat data. A standard module panel renders that snapshot inside a vertical scroll container; Main supplies and refreshes it through existing signals and restores saved module selection without invoking toggle behavior.

**Tech Stack:** Godot 4.7 project, GDScript, existing PanelContainer/scene conventions, existing SceneTree test harness and PowerShell runners. No new dependencies.

**Approved spec:** `docs/superpowers/specs/2026-09-30-operator-dossier-design.md`.

## Global Constraints

- The panel has four sections: `WORK SIGNATURE`, `EXPOSURE`, `RELATIONSHIPS`, and `OPERATIONS RECORD`.
- Profile version remains 5: no new persisted gameplay fields, counters, timestamps, classification tags, or migration.
- Community overlaps either route category.
- Aborts, active jobs, and missed deadlines do not contribute.
- No completion timestamp or chronological claim: the current save does not retain completion order, so rows use catalog order.
- No changes to existing choice rewards, unlocks, standing, favors, preparation, deadlines, Heat effects, or housing behavior.
- Every status remains readable in text; color is supplementary.
- No inventory, achievements, contact arcs, timed aftermath, editable identity, starting statistics, or narrative milestone engine.

## File map and implementation order

| File | Responsibility |
|---|---|
| `autoload/game_state.gd` | Add `dossier_snapshot() -> Dictionary`; reuse `_choice()`, `contact_snapshot()`, and `HEAT_WARNING_BANDS`. |
| `tests/test_dossier.gd` (new) | One behavioral suite for classification, history boundaries, snapshot isolation, and save/load. |
| `scenes/modules/dossier/dossier_panel.gd` (new) | Read-only rendering and scrollable layout. |
| `scenes/modules/dossier/dossier_panel.tscn` (new) | Standard script-backed PanelContainer scene. |
| `resources/module_registry.tres` | Unlocked normal-size core Dossier after Contracts. |
| `scenes/main/main.gd` | Module preload/setup, live refresh, and saved-module restoration. |
| `tests/test_main.gd` | Actual saved selection restoration, context closure, and close/reopen behavior. |
| `tests/test_module_registry.gd` | Update behavior-level rail order/group expectations; remove incidental copy/default assertions rather than re-pin them. |
| `next-features.md` | Mark the dossier implemented only after runtime verification. |

Two dependent implementation tasks. Keep them inline: the rendering/integration task consumes the snapshot contract, and spawning workers for this small shared flow adds coordination without independent work. Do not refactor GameState or build a generic profile system.

## Current seams and pitfalls

- `contact_snapshot()` is at GameState lines 244–262. `contracts` are rebuilt from `ContractCatalog.all()` on load, then only saved state fields are restored; the in-memory choice array is authoritative authored data. `_choice()` at lines 760–764 can look up an outcome without applying present-day gates.
- Main's `MODULE_SCENES` currently contains Home, Comms, and Contracts. `_build_primary_module()` closes context and dispatches `setup()`. `_on_contracts_changed()` currently returns unless Contracts is open; dossier refresh must occur before that guard. `_on_contacts_changed()` refreshes Comms only.
- `_build_shell()` currently calls `select_module(&"home")` unconditionally at line 128. `select_module()` toggles an already-selected open module closed, so it must not be used to restore saved state.
- Main layout uses a panel's combined minimum size. A large content VBox directly under PanelContainer would force the host to grow. Put the VBox inside ScrollContainer and wrap all content labels.
- `project.godot` has a 1920×1080 viewport and no configured minimum window size. Verify 1920×1080 and 1280×720; the latter is a layout test target, not a promise of a previously defined minimum.
- Tests run through `tests/run_test.ps1` and `tests/run_all.ps1`. The full runner discovers `tests/test_*.gd`, including the existing base script. Existing gameplay/persistence suites write and delete user saves. Close the running game and protect the three profile candidates before any verification.
- Line numbers are discovery anchors, not patch coordinates. Re-read the exact ranges before editing; check references for exported symbols with available language-server tooling.

## Verification safety wrapper

Use this PowerShell wrapper for commands that touch profiles, including the full suite and rendered smoke. It preserves the current user's primary, temporary, and backup candidates and restores absence as well as bytes. Do not run another game against the profile while the wrapper is active.

```powershell
$profileDir = Join-Path $env:APPDATA 'Godot\app_userdata\Operator'
$names = @('operator_save.json', 'operator_save.json.tmp', 'operator_save.json.bak')
$originals = @{}
foreach ($name in $names) {
    $path = Join-Path $profileDir $name
    $originals[$name] = $null
    if (Test-Path $path) {
        $originals[$name] = [IO.File]::ReadAllBytes($path)
    }
}
try {
    & .\tests\run_test.ps1 test_dossier
    if ($LASTEXITCODE -ne 0) { throw 'Dossier suite failed' }
} finally {
    [IO.Directory]::CreateDirectory($profileDir) | Out-Null
    foreach ($name in $names) {
        $path = Join-Path $profileDir $name
        if ($null -eq $originals[$name]) {
            if (Test-Path $path) { Remove-Item -LiteralPath $path }
        } else {
            [IO.File]::WriteAllBytes($path, [byte[]]$originals[$name])
        }
    }
}
```

Run from the project root with the existing configured Godot binary. For the smoke, keep this wrapper active until the launched game has exited. Tests alone are not UI proof.

---

### Task 1: Derive a truthful, detached dossier snapshot

**Files:** Modify `autoload/game_state.gd` near `contact_snapshot()`; create `tests/test_dossier.gd`.

**Interfaces:**
- Consumes `contracts: Array[Dictionary]`, `heat: int`, `contact_snapshot() -> Array[Dictionary]`, `_choice(choices: Array, choice_id: StringName) -> Dictionary`, `HEAT_WARNING_BANDS`.
- Produces `dossier_snapshot() -> Dictionary` with keys `signature` (`clean`, `aggressive`, `community`: integers), `heat` (integer), `heat_band` (String), `contacts` (existing contact snapshot), `operations` (Array[Dictionary]), `expired_offers` (Array[Dictionary]).
- Operation rows contain `id`, `code`, `title`, `status`, and `outcome`. `outcome` is the authored selected choice label or `DEADLINE MISSED`. Expired rows contain `id`, `code`, and `title`. All rows are new dictionaries; no choices or authoritative records are returned.

- [x] **Step 1: Add the focused behavioral test suite.** Use the existing base class and public gameplay flow. The core suite below gives concrete scenarios; no per-function framework or copy assertions. The wrapper above protects profile writes made by these public APIs.

```gdscript
extends "res://tests/test_base.gd"

const GameStateScript := preload("res://autoload/game_state.gd")

func _resolve(gs: Node, id: StringName, choice: StringName) -> void:
    check(gs.accept_contract(id), "scenario accepts %s" % id)
    check(gs.proceed_contract(id), "scenario proceeds %s" % id)
    check(gs.resolve_contract(id, choice), "scenario resolves %s" % id)

func _run() -> void:
    var gs := GameStateScript.new()
    var fresh: Dictionary = gs.dossier_snapshot()
    check(fresh.signature == {"clean": 0, "aggressive": 0, "community": 0}
        and fresh.operations.is_empty() and fresh.expired_offers.is_empty(),
        "fresh profile has no historical work")
    _resolve(gs, &"cold_chain_delivery", &"pay_fee")
    _resolve(gs, &"data_retrieval", &"spoof_credentials")
    _resolve(gs, &"dead_drop_audit", &"trace_tag")
    _resolve(gs, &"silent_partner", &"call_in_mara_favor")
    _resolve(gs, &"clinic_asset_recovery", &"maintenance_bypass")
    check(gs.mara_favor_balance == 0, "favor route consumed credit")
    gs.heat = 9
    var populated: Dictionary = gs.dossier_snapshot()
    check(populated.signature == {"clean": 4, "aggressive": 1, "community": 1},
        "clinic completion overlaps aggressive work; historic clean routes remain")
    check(populated.operations.map(func(row: Dictionary): return row.id)
        == [&"cold_chain_delivery", &"data_retrieval", &"dead_drop_audit",
            &"silent_partner", &"clinic_asset_recovery"],
        "history uses catalog order, not completion order")
    check(populated.operations[1].outcome
        == gs._choice(gs.contracts[1].complication.choices, &"spoof_credentials").label
        and populated.operations[3].outcome
        == gs._choice(gs.contracts[3].complication.choices, &"call_in_mara_favor").label,
        "current Heat and spent favor do not hide historical actions")
    check(gs.go_to_ground(), "history scenario can lower Heat")
    check(gs.dossier_snapshot().signature == populated.signature,
        "lowering current Heat does not rewrite work signature")
    for scenario: Dictionary in [
        {"heat": 2, "band": "BELOW WARNING THRESHOLD"},
        {"heat": 3, "band": "ELEVATED"},
        {"heat": 5, "band": "ELEVATED"},
        {"heat": 6, "band": "WATCHED"},
        {"heat": 8, "band": "WATCHED"},
        {"heat": 9, "band": "CRITICAL"},
    ]:
        gs.heat = scenario.heat
        var exposure: Dictionary = gs.dossier_snapshot()
        check(exposure.heat == scenario.heat and exposure.heat_band == scenario.band,
            "exposure follows existing threshold boundary")
    gs.mara_favor_balance = -1
    gs.contact_standing[&"vesper_clinic"] = 2
    var before: Dictionary = gs._profile_payload()
    var detached: Dictionary = gs.dossier_snapshot()
    check(detached.contacts[0].favor_label == "YOU OWE MARA"
        and detached.contacts[1].standing == 2,
        "snapshot reflects current debt and clinic standing")
    detached.contacts[0].standing = 0
    detached.operations[0].status = &"failed"
    detached.expired_offers.clear()
    detached.signature.clean = 99
    check(gs._profile_payload() == before,
        "reading and editing a returned snapshot cannot mutate gameplay")
    gs.active_module = &"dossier"
    gs.module_open = true
    check(gs.save_profile(), "dossier scenario saves")
    var restored := GameStateScript.new()
    check(restored.load_profile(), "dossier scenario reloads")
    check(restored.active_module == &"dossier" and restored.module_open
        and restored.dossier_snapshot() == gs.dossier_snapshot(),
        "selection, historical actions, and derived dossier survive reload")
    var file := FileAccess.open(gs.PROFILE_PATH, FileAccess.READ)
    var payload: Dictionary = JSON.parse_string(file.get_as_text())
    file.close()
    check(int(payload.version) == 5 and not payload.has("signature")
        and not payload.has("dossier"), "derived dossier adds no save schema")
    restored.free()
    gs.free()

    var aborted := GameStateScript.new()
    _resolve(aborted, &"cold_chain_delivery", &"abort")
    check(aborted.dossier_snapshot().operations[0].status == &"failed"
        and aborted.dossier_snapshot().signature
            == {"clean": 0, "aggressive": 0, "community": 0},
        "abort is recorded but never counted as clean work")
    check(aborted.accept_contract(&"data_retrieval"), "accept deadline scenario")
    var active_cutoff: int = aborted.get_contract(&"data_retrieval").deadline_at_minute
    check(not aborted.dossier_snapshot().operations.any(
        func(row: Dictionary): return row.id == &"data_retrieval"),
        "active work is absent from historical records")
    aborted.advance_minutes(active_cutoff - aborted.current_minute())
    var missed: Dictionary = aborted.dossier_snapshot()
    var failed_job: Array = missed.operations.filter(
        func(row: Dictionary): return row.id == &"data_retrieval")
    check(failed_job.size() == 1 and failed_job[0].status == &"failed"
        and failed_job[0].outcome == "DEADLINE MISSED"
        and missed.signature == {"clean": 0, "aggressive": 0, "community": 0},
        "active-job deadline failure is recorded without route credit")
    aborted.free()

    var expired := GameStateScript.new()
    var cutoff: int = expired.get_contract(&"cold_chain_delivery").deadline_at_minute
    expired.advance_minutes(cutoff - expired.current_minute())
    var offers: Dictionary = expired.dossier_snapshot()
    check(offers.operations.is_empty()
        and offers.expired_offers.any(func(row: Dictionary):
            return row.id == &"cold_chain_delivery")
        and offers.signature == {"clean": 0, "aggressive": 0, "community": 0},
        "unaccepted expiry is separate from undertaken work")
    expired.free()
```

- [x] **Step 2: Run the new suite once before implementation.** Inside the profile safety wrapper:

```powershell
& .\tests\run_test.ps1 test_dossier
```

Expected: failure because `dossier_snapshot()` does not exist. Do not rerun to reconfirm an observed failure.

- [x] **Step 3: Add the snapshot method near `contact_snapshot()`.** Iterate the authoritative in-memory contracts directly; they already contain current authored choices after validated loading. Do not call `_available_choices()`, save, emit signals, or duplicate full catalogs on each render.

```gdscript
func dossier_snapshot() -> Dictionary:
    var signature := {"clean": 0, "aggressive": 0, "community": 0}
    var operations: Array[Dictionary] = []
    var expired_offers: Array[Dictionary] = []
    var heat_band := "BELOW WARNING THRESHOLD"
    for band: Dictionary in HEAT_WARNING_BANDS:
        if heat >= int(band.threshold):
            heat_band = String(band.name)
    for contract: Dictionary in contracts:
        if contract.status == &"expired":
            expired_offers.append({
                "id": contract.id, "code": contract.code, "title": contract.title,
            })
            continue
        if contract.status != &"completed" and contract.status != &"failed":
            continue
        var outcome := "DEADLINE MISSED"
        if contract.resolution_id != &"deadline_missed":
            var choice := _choice(contract.complication.choices,
                StringName(str(contract.resolution_id)))
            outcome = String(choice.label)
            if contract.status == &"completed":
                if int(choice.heat_delta) == 0:
                    signature.clean += 1
                elif int(choice.heat_delta) > 0:
                    signature.aggressive += 1
                if contract.contact_id == &"vesper_clinic":
                    signature.community += 1
        operations.append({
            "id": contract.id, "code": contract.code, "title": contract.title,
            "status": contract.status, "outcome": outcome,
        })
    return {
        "signature": signature, "heat": heat, "heat_band": heat_band,
        "contacts": contact_snapshot(), "operations": operations,
        "expired_offers": expired_offers,
    }
```

Unknown saved resolution IDs are already rejected by `_validate_contracts()`; do not conceal corruption with a fake outcome. No new historical classification metadata is needed.

- [x] **Step 4: Run the focused suite and observe the snapshot behavior.** Use the same command as Step 2 inside the safety wrapper. Expected: `RESULT: ALL PASSED`, exit 0. Defer full-suite execution until Task 2 is integrated. The rendered path still needs Task 2's smoke.
- [x] **Step 5: Commit only this task's files after its focused check.**

```powershell
git add -- autoload/game_state.gd tests/test_dossier.gd
git commit -m "feat: derive operator dossier from saved outcomes"
```

### Task 2: Integrate and verify the rendered Dossier module

**Files:** Create `scenes/modules/dossier/dossier_panel.gd` and `.tscn`; modify `resources/module_registry.tres`, `scenes/main/main.gd`, `tests/test_main.gd`, `tests/test_module_registry.gd`; update `next-features.md` after smoke.

**Interfaces:**
- Consumes Task 1's exact `dossier_snapshot()` dictionary.
- Produces `DossierPanel.setup(_gs: Node, data: Variant = null) -> void` and Main `_refresh_dossier() -> void` (only refresh an open, existing Dossier panel).
- Main connects existing `heat_changed(int)` to `_refresh_dossier()`, calls it at the beginning of `_on_contracts_changed()` and `_on_contacts_changed()`, and supplies a snapshot when opening the module.

- [x] **Step 1: Add a saved-selection regression to `tests/test_main.gd`.** In `_run()`, immediately after constructing/naming GameState and before adding it to root, set `active_module = &"dossier"`, `module_open = true`, and `workspace_collapsed = false`. Immediately after Main is added, assert that it restores Dossier open and leaves state unchanged. Then explicitly select Home so the existing Home scenarios remain valid. This fails against the unconditional Home startup.

```gdscript
# Before root.add_child(gs):
gs.active_module = &"dossier"
gs.module_open = true
gs.workspace_collapsed = false

# After root.add_child(main), before the existing Home assertions:
check(gs.active_module == &"dossier" and gs.module_open
    and main.primary_host.visible,
    "startup restores saved Dossier without toggling it closed")
main.select_module(&"home")
```

Near the existing module-switching scenarios, add a behavioral context/close/reopen check, not a preload or copied-string check:

```gdscript
main.select_module(&"contracts")
main._on_contract_selected(&"cold_chain_delivery")
check(main.context_host.visible, "contract context opens for switch scenario")
main.select_module(&"dossier")
check(gs.active_module == &"dossier" and gs.module_open
    and main.primary_host.visible and not main.context_host.visible
    and main.context_host.get_child_count() == 0,
    "Dossier switch closes the previous contract context")
main.close_topmost()
check(not gs.module_open and not main.primary_host.visible,
    "close hides Dossier without changing its selected module")
main.select_module(&"dossier")
check(gs.module_open and main.primary_host.visible,
    "Dossier reopens through ordinary module selection")
main.select_module(&"home")
```

Also extend the startup check to collapsed and closed saved modules with fresh injected GameState/Main pairs before `_main` is assigned, or in the deferred end of the suite after freeing the existing pair. Use the same `GameState` node name, remove old instances before adding new ones, and do not let `_ready()` load an unrelated disk profile during the synchronous harness phase. Expected closed Dossier: selected ID remains `dossier`, `module_open == false`; expected collapsed open Dossier: collapsed remains true, module remains open, host hidden. Unknown or scene-less saved IDs must fall back to open Home. These boundary scenarios may use this helper in the existing synchronous `_run()`:

```gdscript
func _check_restored_workspace(id: StringName, open: bool, collapsed: bool,
        expected_id: StringName, expected_open: bool) -> void:
    var state := GameStateScript.new()
    state.name = "GameState"
    state.active_module = id
    state.module_open = open
    state.workspace_collapsed = collapsed
    root.add_child(state)
    var shell := MainScene.instantiate()
    root.add_child(shell)
    check(state.active_module == expected_id and state.module_open == expected_open
        and state.workspace_collapsed == collapsed
        and shell.primary_host.visible == (expected_open and not collapsed),
        "startup preserves workspace flags or falls back for %s" % id)
    root.remove_child(shell)
    shell.free()
    root.remove_child(state)
    state.free()

# Call before creating the suite's long-lived gs/main pair:
_check_restored_workspace(&"dossier", false, false, &"dossier", false)
_check_restored_workspace(&"dossier", true, true, &"dossier", true)
_check_restored_workspace(&"missing", false, false, &"home", true)
_check_restored_workspace(&"crew", false, false, &"home", true)
```

Run once inside the safety wrapper:

```powershell
& .\tests\run_test.ps1 test_main
```

Expected before implementation: saved Dossier selection regression fails. Keep failures visible; do not suppress missing module behavior.

- [x] **Step 2: Create the script-backed scene and panel.** Use the same scene structure as `comms_panel.tscn`:

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scenes/modules/dossier/dossier_panel.gd" id="1_dossier"]

[node name="DossierPanel" type="PanelContainer"]
script = ExtResource("1_dossier")
```

Complete panel implementation (the helper creates local labels only; no reusable widget layer):

```gdscript
extends PanelContainer

const COLOR_AMBER := Color(1.0, 0.82353, 0.47843)
const COLOR_DIM := Color(0.43529, 0.5451, 0.60392, 1)

var _content: VBoxContainer

func _ready() -> void:
    _build_children()

func _build_children() -> void:
    if _content != null:
        return
    var scroll := ScrollContainer.new()
    scroll.name = "DossierScroll"
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    scroll.follow_focus = true
    scroll.focus_mode = Control.FOCUS_ALL
    scroll.get_v_scroll_bar().focus_mode = Control.FOCUS_ALL
    add_child(scroll)
    _content = VBoxContainer.new()
    _content.name = "DossierContent"
    _content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _content.add_theme_constant_override("separation", 8)
    scroll.add_child(_content)

func _add_label(text: String, heading: bool = false) -> void:
    var label := Label.new()
    label.text = text
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    if heading:
        label.add_theme_color_override("font_color", COLOR_AMBER)
    _content.add_child(label)

func setup(_gs: Node, data: Variant = null) -> void:
    _build_children()
    for child in _content.get_children():
        _content.remove_child(child)
        child.queue_free()
    var snapshot: Dictionary = data if data is Dictionary else _gs.dossier_snapshot()
    _add_label("DOSSIER", true)
    var title := _content.get_child(0) as Label
    title.add_theme_font_override("font", load("res://assets/fonts/JetBrainsMono-Bold.ttf"))
    title.add_theme_font_size_override("font_size", 17)
    _add_label("WORK SIGNATURE", true)
    var signature: Dictionary = snapshot.signature
    _add_label("CLEAN %d // AGGRESSIVE %d // COMMUNITY %d" % [
        signature.clean, signature.aggressive, signature.community])
    _add_label("Clean: no added Heat. Aggressive: Heat-generating route. "
        + "Community: completed clinic work; overlaps either route.")
    var explanation := _content.get_child(_content.get_child_count() - 1) as Label
    explanation.add_theme_color_override("font_color", COLOR_DIM)
    if int(signature.clean) + int(signature.aggressive) == 0:
        _add_label("NO COMPLETED OPERATIONS YET")
    _add_label("EXPOSURE", true)
    _add_label("HEAT %d // %s" % [snapshot.heat, snapshot.heat_band])
    _add_label("RELATIONSHIPS", true)
    for contact: Dictionary in snapshot.contacts:
        var text := "%s // %s" % [contact.display_name, contact.standing_label]
        if contact.has("favor_label"):
            text += " // " + String(contact.favor_label)
        _add_label(text)
    _add_label("OPERATIONS RECORD", true)
    if snapshot.operations.is_empty():
        _add_label("NO RESOLVED OPERATIONS YET")
    for operation: Dictionary in snapshot.operations:
        _add_label("%s // %s // %s\n%s" % [operation.code, operation.title,
            String(operation.status).to_upper(), operation.outcome])
    if not snapshot.expired_offers.is_empty():
        _add_label("EXPIRED OFFERS", true)
        for offer: Dictionary in snapshot.expired_offers:
            _add_label("%s // %s" % [offer.code, offer.title])
```

Wrapping and the scroll container, not a hard-coded minimum height, must bound the panel. Keyboard users can Tab to the native vertical scrollbar and use its native key controls; no custom scrolling controller is needed. Verify reaching the final record with native keyboard scrolling, and leave Escape to Main. Do not claim `focus_mode` alone proves keyboard usability; exercise it.

- [x] **Step 3: Register and integrate Dossier.** Increment registry `load_steps` from 9 to 10 and add this subresource before Crew:

```ini
[sub_resource type="Resource" id="def_dossier"]
script = ExtResource("2_def")
id = &"dossier"
display_name = "DOSSIER"
glyph = "▤"
group = &"core"
size_class = &"normal"
unlocked = true
```

Insert `SubResource("def_dossier")` immediately after Contracts in the resource's `modules` array. In Main add the following entries/code at the named seams:

```gdscript
# MODULE_SCENES:
&"dossier": preload("res://scenes/modules/dossier/dossier_panel.tscn"),

# _build_primary_module(), after the Comms branch:
elif id == &"dossier":
    panel.setup(gs, gs.dossier_snapshot())

# _build_shell(), beside the existing state signal connections:
gs.heat_changed.connect(func(_heat: int) -> void: _refresh_dossier())

func _refresh_dossier() -> void:
    if gs.active_module == &"dossier" and gs.module_open \
            and primary_host.get_child_count() > 0:
        primary_host.get_child(0).setup(gs, gs.dossier_snapshot())
        _apply_layout()

# First statement of both _on_contracts_changed() and _on_contacts_changed():
_refresh_dossier()
```

Replace the unconditional startup `select_module(&"home")` with direct restoration. Valid saved modules keep their open/collapsed flags; scene-less/unknown selections fall back to Home. Do not call `select_module()` here:

```gdscript
var initial_module: StringName = gs.active_module
if not MODULE_SCENES.has(initial_module):
    initial_module = &"home"
    gs.set_active_module(initial_module)
    gs.set_module_open(true)
_build_primary_module(initial_module)
```

Keep existing `_apply_layout()` and resize hookup after restoration. There is no GameState validation migration to change: `_apply_profile()` already restores any string module ID except legacy Alerts, and Main controls scene availability. Updates triggered during `resolve_contract()` may briefly rebuild before `contracts_changed`; the final signal sees committed outcome and refreshes it. No event queue or debounce is necessary for the seven-record catalog.

- [x] **Step 4: Migrate affected existing expectations.** In `tests/test_module_registry.gd`, update the exact behavior-level rail order to Home, Comms, Contracts, Dossier, Crew, Market, Map and operational group indices to 4 and 6. Retain assertions for unlocked core/locked operational behavior and absence of Alerts. Remove the incidental glyph assertion at line 9 and incidental size-class/default assertions at lines 24–28; do not re-pin those copies. Do not add a new test just to echo Dossier's registry fields. In `test_main.gd`, use existing flow checks for rendered module state and restoration, not source-text assertions.

- [x] **Step 5: Run the focused checks, then the full suite after integration.** Execute inside the safety wrapper. Expected after fixes: every executed suite exits 0; full runner prints `ALL SUITES PASSED`. Record actual suite count rather than assuming the previous count.

```powershell
& .\tests\run_test.ps1 test_dossier
if ($LASTEXITCODE -ne 0) { throw 'Dossier suite failed' }
& .\tests\run_test.ps1 test_main
if ($LASTEXITCODE -ne 0) { throw 'Main suite failed' }
& .\tests\run_test.ps1 test_module_registry
if ($LASTEXITCODE -ne 0) { throw 'Registry suite failed' }
& .\tests\run_test.ps1 test_persistence
if ($LASTEXITCODE -ne 0) { throw 'Persistence suite failed' }
& .\tests\run_all.ps1
if ($LASTEXITCODE -ne 0) { throw 'Full suite failed' }
```

- [x] **Step 6: Smoke the rendered project and inspect it.** Keep the safety wrapper active. Launch the existing boot/main flow with the actual configured binary:

```powershell
& 'C:\Users\merli\Documents\Godot Projects\Godot_v4.7.1-stable_win64_console.exe' --path . --resolution 1920x1080
```

Use a disposable profile under the protected save location. For populated smoke data, execute Task 1's public resolution scenario through a temporary SceneTree script or the debugger, save, exit the helper, then launch the project; never replace gameplay APIs with fake production responses. Do not leave the helper in the repo. Specific observed acceptance checks:

1. Enter operations, open Dossier from the rail using mouse and keyboard. Fresh counts are zero; exposure and relationships reflect the existing profile. Labels remain textual, not color-only.
2. Play/seed the mixed Task 1 route, including a completed clinic job and a failed job. Dossier shows overlapping counts, exact selected actions, and catalog ordering. Make an unaccepted offer expire; it appears only in the separate expired-offers subsection.
3. Change current Heat to 3, 6, and 9 through the debugger or real actions while Dossier is open; the band updates. Change Mara debt/credit and clinic standing and emit the corresponding existing signal; relationship rows update. Repeat refreshes: rows do not duplicate. Snapshot/rendering does not alter Credits, time, outcomes, standings, messages, or favors.
4. Go to Ground from Home, reopen Dossier, and verify lower current Heat with unchanged historical signature.
5. Open a contract detail, switch to Dossier, confirm old context is gone. Escape closes Dossier; reopen works. Collapse and expand preserve selection. Exit with Dossier selected, relaunch through boot, and confirm its saved open/closed state is restored.
6. Inspect at 1920×1080 and resize to 1280×720. Scroll all the way to the last populated record with mouse and keyboard. Every long title/action wraps, no horizontal scrollbar is required, and the primary panel stays within the workspace. Include a screenshot or concrete observed visual evidence; report any unavailable visual capability rather than calling headless checks visual proof.
7. Exit the game before restoring original profile candidates and removing temporary scripts. Inspect captured debug output for script/runtime errors on the exercised paths.

- [x] **Step 7: Update existing documentation after smoke proof and commit.** In `next-features.md`, add a verified-state bullet and implemented recommendation for Operator Dossier; describe derived overlapping counts, existing contact/favor labels and Heat bands, resolved catalog-order history, and separate expired offers. Preserve the deferred inventory/crew/market/map decisions and avoid suggesting an unimplemented narrative identity engine. Add only exercised verification evidence. No extra documentation file is needed.

```powershell
git add -- scenes/modules/dossier/dossier_panel.gd scenes/modules/dossier/dossier_panel.tscn resources/module_registry.tres scenes/main/main.gd tests/test_main.gd tests/test_module_registry.gd next-features.md
git commit -m "feat: add read-only operator dossier module"
```

## Plan self-review checklist

- [x] Snapshot schema matches every producer/consumer key above; outcomes come from unfiltered authored choices.
- [x] Counts exclude failures/expiry and overlap community correctly; lowering Heat never rewrites history.
- [x] Read-only state and detached return values are checked; no persisted dossier state or version change.
- [x] Startup restoration covers open, closed, collapsed, invalid, and scene-less selections without toggling.
- [x] Scroll/wrapping, keyboard access, live refresh, context closure, and save/relaunch are exercised on the actual surface.
- [x] Profile candidates are protected for all writing tests/smokes; temporary scaffolding is removed.
- [x] Existing incidental tests are removed, affected behavioral contracts migrated, final full suite passes after integration, and backlog is updated only after proof.

## Execution record

Completed inline. Task 1 is committed as `20d46e1`; Task 2 includes the panel, navigation, regression migration, and feature documentation.

- The reload regression exposed a StringName-to-String status change across JSON loading. `dossier_snapshot()` normalizes operation status to StringName; a focused runtime probe proved the type boundary before the fix.
- The rendered smoke exposed `FOCUS_NONE` in the shared rail. `scenes/ui/icon_rail.gd` now enables native focus for unlocked modules while leaving locked buttons out of the tab order. The full suite exposed an obsolete six-button count in `tests/test_icon_rail.gd`; that incidental assertion was removed, not re-pinned.
- Final `tests/run_all.ps1`: all 18 runner entries passed, exit 0, no script errors. Existing audio/anchor/teardown harness diagnostics and deliberately exercised invalid-save diagnostics remain.
- Actual D3D12/Forward+ boot-to-main smoke: fresh and mixed clean/aggressive/community records, failed jobs and expired offers, live Heat/favor changes, read-only refresh without duplicate rows, Go to Ground, contract-context closure, keyboard/mouse rail access and scrolling, Escape, collapse/expand, and bounds at 1920×1080 and 1280×720. Screenshots were inspected; a separate process relaunch restored the selected Dossier and derived history. Both final smoke runs reported zero failures.
- Temporary runtime drivers were removed. The user's original primary profile was restored byte-for-byte; original temporary/backup absence was restored.
