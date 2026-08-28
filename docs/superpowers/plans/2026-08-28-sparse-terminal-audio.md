# Sparse Terminal Audio Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the existing boot and contract loop a quiet Lower Vesper ambience, meaningful one-shot terminal cues, and session-only volume controls.

**Architecture:** Godot's native `Master`, `Ambience`, and `SFX` buses provide routing and volume control. `boot.gd` and `main.gd` own their own `AudioStreamPlayer` nodes; `GameState` emits semantic contract-transition signals after valid state changes, and Main maps them to local streams. The Home panel owns its three native bus controls; no audio singleton, event bus, persistence store, or settings module is introduced.

**Tech Stack:** Godot 4.7.1, GDScript, `AudioStreamPlayer`, `AudioServer`, OGG Vorbis assets, existing headless `SceneTree` test harness.

## Global Constraints

- The user supplies six final, distributable `.ogg` streams at the exact asset paths in the approved design before source integration begins.
- Use the native Godot buses named exactly `Master`, `Ambience`, and `SFX`; `Ambience` and `SFX` send to `Master`.
- Audio is presentation-only: it MUST NOT alter GameState rules, Credits, Heat, clock, unlocks, contract input, or workspace state.
- Emit audio only for accepted boot entry and accepted contract accept/proceed/resolve transitions; rejected input, hover, focus, ticker rotation, rail selection, and ordinary buttons remain silent.
- Home controls are keyboard-focusable and session-only. They MUST expose Master, Ambience, and SFX values, and Master mute MUST restore the prior Master value.
- Missing streams report their exact path once and leave only that sound silent; boot and valid contracts MUST continue.
- Do not add dependencies, an `AudioManager`, generic audio/event registry, dynamic music, voice work, positional audio, or persistent settings.
- Prefix every shell command with `rtk`.

---

## File Structure

| File | Responsibility |
|---|---|
| `default_bus_layout.tres` | Native three-bus routing: Master, Ambience → Master, SFX → Master. |
| `assets/audio/ambience/lower_vesper_apartment.ogg` | User-supplied looping apartment/city ambience. |
| `assets/audio/ui/*.ogg` | User-supplied boot and contract one-shot streams. |
| `autoload/game_state.gd` | Emits semantic accepted contract events; remains gameplay-state owner. |
| `scenes/boot/boot.gd` | Owns and plays the boot-entry SFX once. |
| `scenes/main/main.gd` | Owns the looping ambience and one-shot contract SFX players. |
| `scenes/modules/home/home_panel.gd` | Renders and operates the compact session-only audio controls. |
| `tests/test_game_state.gd` | Locks semantic-signal acceptance and rejection behavior. |
| `tests/test_boot.gd` | Locks boot-player ownership and single accepted-entry playback. |
| `tests/test_main.gd` | Locks Main audio player ownership and stream routing from contract events. |
| `tests/test_panels_basic.gd` | Locks bus routing and Home control behavior without GameState mutation. |

## Task 1: Stage Audio Assets and Native Bus Routing

**Files:**
- Create: `default_bus_layout.tres`
- Create: `assets/audio/ambience/lower_vesper_apartment.ogg` (user-supplied)
- Create: `assets/audio/ui/terminal_enter.ogg` (user-supplied)
- Create: `assets/audio/ui/contract_accepted.ogg` (user-supplied)
- Create: `assets/audio/ui/contract_proceeded.ogg` (user-supplied)
- Create: `assets/audio/ui/contract_completed.ogg` (user-supplied)
- Create: `assets/audio/ui/contract_failed.ogg` (user-supplied)
- Modify: `tests/test_panels_basic.gd:7-38`

**Interfaces:**
- Consumes: The six OGG streams specified in `docs/superpowers/specs/2026-08-28-sparse-terminal-audio-design.md`.
- Produces: A project-wide `AudioServer` bus layout with `Master`, `Ambience`, and `SFX`; later scene players address the latter two names exactly.

- [ ] **Step 1: Put the supplied audio at the exact paths and configure its import**

Copy the six supplied tracks into the paths above. In Godot's Import dock, enable looping only for `lower_vesper_apartment.ogg`; leave each UI clip non-looping. Verify the ambience is stereo, seamless, contains no voice or melody, and the UI files conform to the approved duration limits.

- [ ] **Step 2: Write the failing routing assertions**

Add this at the start of `test_panels_basic.gd`'s `_run()` before creating `GameState`:

```gdscript
var ambience_bus := AudioServer.get_bus_index(&"Ambience")
var sfx_bus := AudioServer.get_bus_index(&"SFX")
check(ambience_bus >= 0 and AudioServer.get_bus_send(ambience_bus) == &"Master",
	"Ambience bus routes to Master")
check(sfx_bus >= 0 and AudioServer.get_bus_send(sfx_bus) == &"Master",
	"SFX bus routes to Master")
```

- [ ] **Step 3: Run the focused test and verify it fails**

Run:

```powershell
rtk powershell -ExecutionPolicy Bypass -File tests/run_test.ps1 test_panels_basic
```

Expected: `FAIL` because neither `Ambience` nor `SFX` exists yet.

- [ ] **Step 4: Add the native bus layout**

Create `default_bus_layout.tres` with this exact routing, using Godot's generated resource format:

```tres
[gd_resource format=3]

[resource]
bus/0/name = &"Master"
bus/0/solo = false
bus/0/mute = false
bus/0/bypass_fx = false
bus/0/volume_db = -1.9382
bus/0/send = &""
bus/1/name = &"Ambience"
bus/1/solo = false
bus/1/mute = false
bus/1/bypass_fx = false
bus/1/volume_db = 0.0
bus/1/send = &"Master"
bus/2/name = &"SFX"
bus/2/solo = false
bus/2/mute = false
bus/2/bypass_fx = false
bus/2/volume_db = 0.0
bus/2/send = &"Master"
```

Open the project once in the Godot editor so it imports the six streams and loads the default layout from `res://default_bus_layout.tres`.

- [ ] **Step 5: Re-run the focused test and verify it passes**

Run:

```powershell
rtk powershell -ExecutionPolicy Bypass -File tests/run_test.ps1 test_panels_basic
```

Expected: `RESULT: ALL PASSED`, including the two new routing assertions.

- [ ] **Step 6: Commit the asset and bus foundation**

```powershell
rtk git add default_bus_layout.tres assets/audio tests/test_panels_basic.gd
rtk git commit -m "feat: add terminal audio assets and buses"
```

## Task 2: Emit Semantic Contract Transition Signals

**Files:**
- Modify: `autoload/game_state.gd:6-19,110-165`
- Modify: `tests/test_game_state.gd:83-140`

**Interfaces:**
- Consumes: Existing successful `accept_contract(id)`, `proceed_contract(id)`, and `resolve_contract(id, choice_id)` state transitions.
- Produces:
  - `signal contract_accepted(id: StringName)`
  - `signal contract_proceeded(id: StringName)`
  - `signal contract_resolved(id: StringName, status: StringName)`
- Contract: Every signal fires exactly once after its operation has succeeded. Any `false` return fires none.

- [ ] **Step 1: Write failing accepted-event tests**

In `test_game_state.gd`, immediately before the existing `contract_gs.accept_contract()` check, connect and capture the new signals:

```gdscript
var contract_events: Array[Dictionary] = []
contract_gs.contract_accepted.connect(func(id: StringName) -> void:
	contract_events.append({"event": &"accepted", "id": id}))
contract_gs.contract_proceeded.connect(func(id: StringName) -> void:
	contract_events.append({"event": &"proceeded", "id": id}))
contract_gs.contract_resolved.connect(func(id: StringName, status: StringName) -> void:
	contract_events.append({"event": &"resolved", "id": id, "status": status}))
```

After the accepted and proceeded assertions, add:

```gdscript
check(contract_events == [
	{"event": &"accepted", "id": &"cold_chain_delivery"},
	{"event": &"proceeded", "id": &"cold_chain_delivery"},
], "accepted transitions emit ordered semantic events once")
```

After an independent Customs setup resolves `pay_fee`, assert it captures exactly:

```gdscript
check(resolution_events == [{
	"event": &"resolved", "id": &"cold_chain_delivery", "status": &"completed"
}], "completed resolution emits its semantic event once")
```

Create a separate abort setup and assert the sole resolution event has `status == &"failed"`. Extend the existing invalid-resolution case with counters connected to all three signals and assert the counter remains zero after its rejected `resolve_contract()` call.

- [ ] **Step 2: Run the focused test and verify it fails**

Run:

```powershell
rtk powershell -ExecutionPolicy Bypass -File tests/run_test.ps1 test_game_state
```

Expected: parser failure because the three signal members do not exist.

- [ ] **Step 3: Add only the semantic signals and successful emissions**

Declare the three signals beside `contracts_changed` and `messages_changed`. Emit them after the existing accepted state change and feedback work succeeds:

```gdscript
func accept_contract(id: StringName) -> bool:
	# Keep existing validation and mutation unchanged.
	# After push_ticker() and add_message():
	contract_accepted.emit(id)
	return true

func proceed_contract(id: StringName) -> bool:
	# Keep existing validation, time advance, mutation, and feedback unchanged.
	# After push_ticker() and add_message():
	contract_proceeded.emit(id)
	return true

func resolve_contract(id: StringName, choice_id: StringName) -> bool:
	# Keep existing validation, mutation, unlock, and feedback unchanged.
	# After _push_resolution_feedback(choice):
	contract_resolved.emit(id, contract.status)
	return true
```

Do not emit before an operation's validations, do not emit from `contracts_changed`, and do not add audio IDs or stream paths to GameState.

- [ ] **Step 4: Re-run the focused test and verify it passes**

Run:

```powershell
rtk powershell -ExecutionPolicy Bypass -File tests/run_test.ps1 test_game_state
```

Expected: `RESULT: ALL PASSED`; the existing game-state assertions remain unchanged and new event assertions pass.

- [ ] **Step 5: Commit the semantic contract boundary**

```powershell
rtk git add autoload/game_state.gd tests/test_game_state.gd
rtk git commit -m "feat: signal accepted contract transitions"
```

## Task 3: Play Boot, Ambience, and Contract Cues Locally

**Files:**
- Modify: `scenes/boot/boot.gd:5-22,44-100,111-125`
- Modify: `scenes/main/main.gd:37-54,84-99,138-145,225-232`
- Modify: `tests/test_boot.gd:12-58`
- Modify: `tests/test_main.gd:12-19,28-54,111-161`

**Interfaces:**
- Consumes: `GameState.contract_accepted(id)`, `GameState.contract_proceeded(id)`, and `GameState.contract_resolved(id, status)` from Task 2; the six asset paths from Task 1.
- Produces:
  - Boot child `BootSfx: AudioStreamPlayer`, bus `SFX`.
  - Main children `Ambience: AudioStreamPlayer`, bus `Ambience`, and `ContractSfx: AudioStreamPlayer`, bus `SFX`.
  - `main.gd` private callbacks `_on_contract_accepted`, `_on_contract_proceeded`, and `_on_contract_resolved`.
- Contract: Each callback replaces the one-shot player's stream and calls `play()` once. Main never derives sounds from UI refreshes or ticker text.

- [ ] **Step 1: Write the failing boot-player test**

In `test_boot.gd`, after instantiating and adding `boot`, add:

```gdscript
var boot_sfx := boot.get_node_or_null("BootSfx") as AudioStreamPlayer
check(boot_sfx != null and boot_sfx.bus == &"SFX"
	and boot_sfx.stream != null
	and boot_sfx.stream.resource_path == "res://assets/audio/ui/terminal_enter.ogg",
	"boot owns the terminal-entry SFX player")
```

After the first `boot._enter_operations()`, add:

```gdscript
check(boot_sfx.playing, "accepted boot entry starts its cue")
```

- [ ] **Step 2: Write the failing Main-player and stream-mapping tests**

In `test_main.gd`, after locating `environment`, add:

```gdscript
var ambience := main.get_node_or_null("Ambience") as AudioStreamPlayer
var contract_sfx := main.get_node_or_null("ContractSfx") as AudioStreamPlayer
check(ambience != null and ambience.bus == &"Ambience" and ambience.playing,
	"Main owns one playing ambience loop")
check(contract_sfx != null and contract_sfx.bus == &"SFX",
	"Main owns the contract SFX player")
```

After emitting each existing contract button press, assert the current one-shot stream path:

```gdscript
check(contract_sfx.stream.resource_path == "res://assets/audio/ui/contract_accepted.ogg",
	"accept maps to its SFX")
check(contract_sfx.stream.resource_path == "res://assets/audio/ui/contract_proceeded.ogg",
	"proceed maps to its SFX")
check(contract_sfx.stream.resource_path == "res://assets/audio/ui/contract_failed.ogg",
	"failed resolution maps to its SFX")
```

Create a separate `GameStateScript`/`MainScene` pair for the completed C-1042 run so the existing main instance can still exercise its aborted portfolio path; free that pair after asserting `contract_completed.ogg`. After every mapping assertion, call `contract_sfx.stop()`, emit `gs.contracts_changed`, and assert `not contract_sfx.playing` plus the unchanged `stream.resource_path`; a panel refresh must not replace or replay a cue.

- [ ] **Step 3: Run the focused tests and verify they fail**

Run:

```powershell
rtk powershell -ExecutionPolicy Bypass -File tests/run_test.ps1 test_boot
rtk powershell -ExecutionPolicy Bypass -File tests/run_test.ps1 test_main
```

Expected: `FAIL` because none of the three audio-player nodes exists.

- [ ] **Step 4: Add the boot-owned SFX player and missing-stream guard**

In `boot.gd`, declare the path and player:

```gdscript
const ENTRY_SFX_PATH := "res://assets/audio/ui/terminal_enter.ogg"
var _boot_sfx: AudioStreamPlayer
```

At the end of `_build_children()`, construct the player with name `BootSfx`, bus `&"SFX"`, and a dynamically loaded stream. Use this guard rather than `preload`, so a missing file cannot stop the scene from parsing:

```gdscript
func _load_stream(path: String) -> AudioStream:
	var stream := load(path) as AudioStream
	if stream == null:
		push_error("Audio stream unavailable: " + path)
	return stream
```

Only call `_boot_sfx.play()` in `_enter_operations()` after `_entering` becomes true and only when `_boot_sfx.stream != null`. The existing `_entering` guard ensures repeat input does not replay it.

- [ ] **Step 5: Add Main's two local players and semantic signal callbacks**

In `main.gd`, declare exact path constants for ambience and the four contract cues. Add `Ambience` and `ContractSfx` as direct Main children during `_build_shell()` after the environment and before workspace construction. Configure:

```gdscript
ambience.name = "Ambience"
ambience.bus = &"Ambience"
ambience.volume_db = -18.0
contract_sfx.name = "ContractSfx"
contract_sfx.bus = &"SFX"
```

Load the ambience once during `_build_shell()` and assign it to the player. Add this exact one-shot helper in `main.gd`; it reports a missing stream once per path without creating a global registry:

```gdscript
var _missing_audio_paths := {}

func _load_audio_stream(path: String) -> AudioStream:
	var stream := load(path) as AudioStream
	if stream == null and not _missing_audio_paths.has(path):
		_missing_audio_paths[path] = true
		push_error("Audio stream unavailable: " + path)
	return stream

func _play_contract_sfx(path: String) -> void:
	var stream := _load_audio_stream(path)
	if stream == null:
		return
	_contract_sfx.stream = stream
	_contract_sfx.play()
```

In `_ready()`, after `_build_shell()` has completed and only when the ambience stream is non-null, call `play()` once.

Connect the Task 2 semantic signals in `_build_shell()`:

```gdscript
gs.contract_accepted.connect(_on_contract_accepted)
gs.contract_proceeded.connect(_on_contract_proceeded)
gs.contract_resolved.connect(_on_contract_resolved)
```

Map each callback directly:

```gdscript
func _on_contract_accepted(_id: StringName) -> void:
	_play_contract_sfx(CONTRACT_ACCEPTED_SFX_PATH)

func _on_contract_proceeded(_id: StringName) -> void:
	_play_contract_sfx(CONTRACT_PROCEEDED_SFX_PATH)

func _on_contract_resolved(_id: StringName, status: StringName) -> void:
	if status == &"completed":
		_play_contract_sfx(CONTRACT_COMPLETED_SFX_PATH)
	elif status == &"failed":
		_play_contract_sfx(CONTRACT_FAILED_SFX_PATH)
```

Do not connect `contracts_changed` or `ticker_message` to audio. Do not add autoplay in the scene file, and do not add any global audio node.

- [ ] **Step 6: Re-run the focused tests and verify they pass**

Run:

```powershell
rtk powershell -ExecutionPolicy Bypass -File tests/run_test.ps1 test_boot
rtk powershell -ExecutionPolicy Bypass -File tests/run_test.ps1 test_main
```

Expected: `RESULT: ALL PASSED` for each file, including ownership, accepted-event mapping, and no-refresh-replay assertions.

- [ ] **Step 7: Commit local playback**

```powershell
rtk git add scenes/boot/boot.gd scenes/main/main.gd tests/test_boot.gd tests/test_main.gd
rtk git commit -m "feat: play sparse terminal audio cues"
```

## Task 4: Add Session-Only Home Audio Controls

**Files:**
- Modify: `scenes/modules/home/home_panel.gd:8-52`
- Modify: `tests/test_panels_basic.gd:7-38`

**Interfaces:**
- Consumes: Named native buses from Task 1 and `AudioServer` methods `get_bus_index`, `set_bus_volume_db`, `set_bus_mute`, and `is_bus_mute`.
- Produces: Keyboard-focusable Home children `MasterSlider`, `AmbienceSlider`, `SfxSlider`, `MuteButton`, `MasterValue`, `AmbienceValue`, and `SfxValue`.
- Contract: Values apply immediately for the session. The bus layout starts Master at 80%; Ambience and SFX at 100%. Main keeps ambience quiet with its player volume, not a hidden bus default. Muting Master sets its visible slider to zero and restores its prior nonzero value on unmute.

- [ ] **Step 1: Write failing control behavior tests**

After the existing Home summary assertions in `test_panels_basic.gd`, add:

```gdscript
var master := home.find_child("MasterSlider", true, false) as HSlider
var ambience := home.find_child("AmbienceSlider", true, false) as HSlider
var sfx := home.find_child("SfxSlider", true, false) as HSlider
var mute := home.find_child("MuteButton", true, false) as Button
var master_value := home.find_child("MasterValue", true, false) as Label
check(master != null and ambience != null and sfx != null and mute != null,
	"Home exposes all audio controls")
check(master.value == 80.0 and ambience.value == 100.0 and sfx.value == 100.0,
	"Home applies authored session defaults")
master.value = 35.0
check(master_value.text == "35%" and not AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Master")),
	"Master slider exposes and applies its value")
mute.pressed.emit()
check(master.value == 0.0 and AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Master")),
	"Mute silences Master")
mute.pressed.emit()
check(master.value == 35.0 and not AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Master")),
	"Mute restores the prior Master value")
```

Save the original bus volumes and mute states at the top of `_run()` and restore them before freeing `gs`, so the test leaves the process-wide native audio state unchanged.

- [ ] **Step 2: Run the focused test and verify it fails**

Run:

```powershell
rtk powershell -ExecutionPolicy Bypass -File tests/run_test.ps1 test_panels_basic
```

Expected: `FAIL` because the named controls do not exist.

- [ ] **Step 3: Build the compact controls in Home**

In `home_panel.gd`, add this fallback constant:

```gdscript
const MASTER_DEFAULT := 80.0
```

In `_build_children()`, retain the existing title and summary, then append an `AUDIO` `Label` and three rows. Each row contains a fixed-width channel label, an `HSlider` named exactly as the produced interface, and a percentage `Label` named exactly as the produced interface. Set each slider's `min_value = 0.0`, `max_value = 100.0`, `step = 1.0`, `focus_mode = Control.FOCUS_ALL`; connect `value_changed` to a channel-specific handler. Put `MuteButton` beside the Master row with text `MUTE`.

Apply a slider value through the named bus only:

```gdscript
func _apply_bus_percent(bus_name: StringName, percent: float) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		push_error("Audio bus unavailable: " + String(bus_name))
		return
	AudioServer.set_bus_mute(bus_index, percent <= 0.0)
	if percent > 0.0:
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(percent / 100.0))
```

Each slider handler updates only its own percentage label (`"%d%%" % roundi(value)`), then calls `_apply_bus_percent()` with `&"Master"`, `&"Ambience"`, or `&"SFX"`. During `setup()`, read `AudioServer.is_bus_mute()` and `AudioServer.get_bus_volume_db()` for each bus, convert a non-muted dB value with `db_to_linear() * 100.0`, and set each slider with `set_value_no_signal()`. A newly opened Home panel therefore reflects the current session mix rather than resetting it. The `default_bus_layout.tres` Master volume supplies the 80% launch default.

Implement the mute button by preserving `_master_before_mute` whenever Master changes to a nonzero value. If Master is nonzero, set `_master_before_mute`, set `MasterSlider.value = 0.0`, and change the button text to `UNMUTE`. If Master is zero, set its value to `_master_before_mute` (falling back to `MASTER_DEFAULT` only if that value is zero) and restore the text to `MUTE`.

- [ ] **Step 4: Re-run the focused test and verify it passes**

Run:

```powershell
rtk powershell -ExecutionPolicy Bypass -File tests/run_test.ps1 test_panels_basic
```

Expected: `RESULT: ALL PASSED`, including slider defaults, visible percentage, Master mute, Master restore, and existing credit refresh assertions.

- [ ] **Step 5: Run the complete headless suite**

Run every test file and stop at the first failure:

```powershell
rtk powershell -NoProfile -Command "Get-ChildItem tests/test_*.gd | ForEach-Object { & .\tests\run_test.ps1 $_.BaseName; if (`$LASTEXITCODE -ne 0) { exit `$LASTEXITCODE } }"
```

Expected: every test ends with `RESULT: ALL PASSED`.

- [ ] **Step 6: Manually smoke the actual audio surface**

Run the project in Godot and verify, in order:

1. Boot diagnostics remain silent; entering Operations plays the entry cue once.
2. Operations ambience starts once, loops cleanly, and remains below terminal readability.
3. Accepting and proceeding C-1042 each play their matching cue once.
4. Resolve one C-1042 run with `PAY CLEARANCE FEE` and another with `ABORT DELIVERY`; hear distinct completion and failure cues.
5. In Home, use keyboard Tab/arrow keys to focus and change all three sliders. Verify each percentage text updates immediately.
6. Press `MUTE`, confirm all sound stops, then press `UNMUTE`, confirming Master returns to its preceding percentage.
7. With one OGG temporarily renamed, launch and traverse its associated path. Confirm a single engine error names that exact path while boot/contracts remain usable; restore the file afterward.

- [ ] **Step 7: Commit Home controls and verification changes**

```powershell
rtk git add scenes/modules/home/home_panel.gd tests/test_panels_basic.gd
rtk git commit -m "feat: add session audio controls"
```

## Plan Self-Review

- **Spec coverage:** Task 1 supplies the exact assets and bus routing. Task 2 provides semantic post-success contract events. Task 3 implements the silent boot diagnostics, entry cue, single Main ambience, all four contract outcome cues, local ownership, missing-stream resilience, and no refresh-triggered playback. Task 4 implements keyboard-accessible Master/Ambience/SFX controls, Master mute/restore, session-only behavior, focused tests, full regression, and manual audible verification.
- **Placeholder scan:** No unresolved names, placeholder tasks, generic error-handling statements, or unspecified tests remain. The only external prerequisite is the user-supplied six OGG files, with exact target paths and acceptance criteria defined in the approved design and Task 1.
- **Type consistency:** All signal and node names use `StringName` or exact scene-node strings consistently: `contract_accepted`, `contract_proceeded`, `contract_resolved`, `BootSfx`, `Ambience`, `ContractSfx`, `MasterSlider`, `AmbienceSlider`, `SfxSlider`, and `MuteButton`.
