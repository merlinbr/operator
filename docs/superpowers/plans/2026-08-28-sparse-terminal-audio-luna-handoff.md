# Luna Handoff: Sparse Terminal Audio

## Start Here

Implement the approved plan in:

`docs/superpowers/plans/2026-08-28-sparse-terminal-audio.md`

Read the approved design first:

`docs/superpowers/specs/2026-08-28-sparse-terminal-audio-design.md`

The plan is authoritative for task order, code snippets, test assertions, asset paths, exact node/signal names, commands, and commit boundaries. Read both documents before editing.

## Blocking Asset Prerequisite

Do **not** begin source changes until the user has supplied all six final, distributable OGG files and they are present at these exact paths:

```text
res://assets/audio/ambience/lower_vesper_apartment.ogg
res://assets/audio/ui/terminal_enter.ogg
res://assets/audio/ui/contract_accepted.ogg
res://assets/audio/ui/contract_proceeded.ogg
res://assets/audio/ui/contract_completed.ogg
res://assets/audio/ui/contract_failed.ogg
```

The ambience must be stereo, loop cleanly, and contain only low-intensity Lower Vesper apartment/city/rain/HVAC room tone—no voice or melody. Enable looping only for that import. UI clips must remain non-looping and meet the plan’s duration limits. Every asset must be original or licensed for redistribution with this MIT project.

## Goal

Make the existing boot and contract loop feel physical with restrained, diegetic sound:

```text
silent boot diagnostics
→ one terminal entry relay
→ continuous quiet apartment ambience in Operations
→ one accepted cue per contract accept/proceed/resolve event
→ compact Home volume controls
```

Audio is presentation-only. It must not change gameplay state, Credits, Heat, time, contract availability, input behavior, or workspace state.

## Required Audio Behavior

| Event | Stream | Required behavior |
|---|---|---|
| Enter Operations | `terminal_enter.ogg` | One SFX after accepted boot entry; repeated input cannot replay it. |
| Main ready | `lower_vesper_apartment.ogg` | Starts once, loops through Main’s lifetime, routed to Ambience, player volume `-18.0 dB`. |
| Valid `accept_contract()` | `contract_accepted.ogg` | One SFX only after accepted state transition. |
| Valid `proceed_contract()` | `contract_proceeded.ogg` | One SFX only after accepted state transition. |
| Valid completed `resolve_contract()` | `contract_completed.ogg` | One SFX only after accepted state transition. |
| Valid failed `resolve_contract()` | `contract_failed.ogg` | One SFX only after accepted state transition. |

Rejected actions, hover/focus, rail navigation, ordinary button presses, ticker rotation, and conditional-choice visibility stay silent. Never infer sound from `contracts_changed` or ticker text; those signals also fire for UI refreshes.

## Native Routing and Ownership

Use native Godot audio only. There is **no AudioManager** in this slice.

| Owner | Responsibility | Must not own |
|---|---|---|
| `default_bus_layout.tres` | `Master`, `Ambience → Master`, `SFX → Master`; Master starts at `-1.9382 dB` (80%). | Effects, persistence, gameplay behavior. |
| `autoload/game_state.gd` | Semantic post-success transition signals. | Audio asset paths, audio IDs, players, or volume state. |
| `scenes/boot/boot.gd` | One direct child named `BootSfx`, bus `SFX`; entry cue. | Main ambience, contract mapping, GameState access. |
| `scenes/main/main.gd` | Direct children `Ambience` (bus `Ambience`) and `ContractSfx` (bus `SFX`); exact signal-to-stream mapping. | Global audio service, generic effect registry, settings persistence. |
| `scenes/modules/home/home_panel.gd` | Current-session Master/Ambience/SFX controls and Master mute/restore. | Players, GameState access by autoload name, saved preferences. |

Create the bus resource at the project root so Godot loads `res://default_bus_layout.tres` automatically. Keep `Ambience` and `ContractSfx` as direct `Main` children; do not add them to a scene file as autoplay nodes.

## Required GameState Interface

Add only these signals, beside the existing contract/message signals:

```gdscript
signal contract_accepted(id: StringName)
signal contract_proceeded(id: StringName)
signal contract_resolved(id: StringName, status: StringName)
```

Emit each one exactly once, after its existing operation has fully succeeded and emitted its existing UI feedback. Invalid IDs, wrong phases, inactive contracts, and hidden choices continue returning `false` without any new signal.

Main connects those semantic signals in `_build_shell()` and maps them directly to the four contract streams. Do not modify contract data, state-machine rules, messages, ticker behavior, or existing `contracts_changed` behavior.

## Missing Audio Rules

Load streams dynamically rather than with `preload`, so a missing user file cannot stop a scene from parsing. A missing/unloadable stream must call:

```gdscript
push_error("Audio stream unavailable: " + path)
```

Report a path once, silence only that player/event, and leave boot/contracts usable. Main may retain a private set/dictionary of failed paths solely to suppress duplicate errors; do not turn it into a registry or manager.

## Home Controls

Append a compact `AUDIO` section to the existing Home panel. Required children:

```text
MasterSlider       HSlider
AmbienceSlider     HSlider
SfxSlider          HSlider
MuteButton         Button
MasterValue        Label
AmbienceValue      Label
SfxValue           Label
```

Each slider is keyboard-focusable with range `0.0..100.0`, step `1.0`, immediate application, and an exact visible percentage such as `35%`.

- Initial launch values come from the bus layout: Master 80%, Ambience 100%, SFX 100%.
- Reopening Home must read the existing native bus state; it must not reset the session mix.
- `MUTE` stores the current nonzero Master percentage, sets Master to zero and changes to `UNMUTE`.
- `UNMUTE` restores the stored value; fall back to 80% only if no nonzero value exists.
- Use `AudioServer` directly: named bus lookup, `set_bus_volume_db(linear_to_db(percent / 100.0))` for nonzero values, and `set_bus_mute()` at zero.
- Controls do not write to disk. Persistent preferences wait for a real profile/settings slice.

## Execute in This Exact Order

1. **Assets and buses:** stage the six supplied OGGs; configure only the ambience to loop; write failing routing checks; create `default_bus_layout.tres`; re-run checks; commit.
2. **Contract boundary:** write failing GameState signal tests; add only the three semantic signals and post-success emissions; re-run `test_game_state`; commit.
3. **Local playback:** write failing Boot/Main node and mapping tests; add `BootSfx`, `Ambience`, `ContractSfx`, dynamic loading, missing-path guards, and direct signal callbacks; run `test_boot` and `test_main`; commit.
4. **Home controls:** write failing control/mute/restore tests; build the compact controls; ensure reopening Home preserves the current session bus mix; run `test_panels_basic`, full tests, and manual smoke; commit.

Do not merge tasks, skip red/green checks, fold in settings persistence, or refactor unrelated scenes.

## Test Commands

Every shell command uses `rtk`:

```powershell
rtk powershell -ExecutionPolicy Bypass -File tests/run_test.ps1 test_panels_basic
rtk powershell -ExecutionPolicy Bypass -File tests/run_test.ps1 test_game_state
rtk powershell -ExecutionPolicy Bypass -File tests/run_test.ps1 test_boot
rtk powershell -ExecutionPolicy Bypass -File tests/run_test.ps1 test_main
rtk powershell -NoProfile -Command "Get-ChildItem tests/test_*.gd | ForEach-Object { & .\tests\run_test.ps1 $_.BaseName; if (`$LASTEXITCODE -ne 0) { exit `$LASTEXITCODE } }"
```

Tests must prove:

- Ambience and SFX buses exist and route to Master.
- Every accepted contract transition emits its exact semantic event once; rejected calls emit none.
- Boot owns `BootSfx`, plays after its first accepted entry, and repeated entry input remains guarded.
- Main owns one active ambience player and one SFX player; accepted/proceeded/completed/failed each choose the correct stream.
- A `contracts_changed` refresh cannot replace or replay a stopped cue.
- Home exposes the named controls, applies values to only the expected bus, updates percentage text, mutes Master, restores Master, and never mutates GameState.
- Existing headless tests stay green.

## Manual Smoke Requirements

Launch the real project after the headless suite passes and verify:

1. Boot diagnostics are silent; entering Operations plays its cue once.
2. Apartment ambience begins once, loops without a seam, and stays below terminal reading.
3. C-1042 accept and proceed each play their unique cue exactly once.
4. Resolve C-1042 once through `PAY CLEARANCE FEE` and once through `ABORT DELIVERY`; completion and failure sound distinct.
5. In Home, Tab/arrow keys reach every slider; each applies immediately and updates its visible percentage.
6. `MUTE` silences all buses; `UNMUTE` restores the preceding Master percentage.
7. Temporarily rename one OGG, launch/traverse its event, verify one error names the exact path while the game stays usable, then restore the file.

## Explicitly Out of Scope

- Any `AudioManager`, autoload audio service, sound/effect registry, generic event bus, or middleware.
- Music score, adaptive music, playlist, voice acting, radio chatter, positional audio, audio-reactive visuals, weather simulation, or click/hover spam.
- Save/load, profile/settings screen, persistent settings file, or user preference persistence.
- Contract/catalog/state-machine changes; game economy, progression, apartment art, HUD, rail, ticker, Comms, or workspace redesign.

## Deliverable Standard

Do not report completion until the six supplied assets import cleanly; all focused tests and the complete headless suite pass; and the manual smoke confirms both distinct resolution cues, readable ambience, keyboard-accessible controls, Master mute/restore, one-time missing-path reporting, and no broken boot or contract progression.
