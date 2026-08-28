# Sparse Terminal Audio

**Date:** 2026-08-28  
**Status:** Scope approved; specification self-review passed; user review pending  
**Scope:** Add restrained diegetic audio to the existing boot and operations-terminal flow.

## Goal

Give the UI-first operator loop a physical presence without obscuring contract reading or creating an audio subsystem. The player hears a quiet Lower Vesper apartment while working, clear confirmation at meaningful contract transitions, and a distinct outcome at resolution.

Audio is presentation only. It must not change GameState, contract rules, Credits, Heat, clock, unlocks, or input behavior.

## Player Experience

1. The boot terminal remains silent while its diagnostics reveal.
2. Choosing **ENTER OPERATIONS** plays one short terminal relay cue during the existing fade.
3. On entering Operations, a low-level Lower Vesper apartment ambience begins and loops continuously.
4. Contract accept, proceed, resolution-success, and resolution-failure each play one short, distinct cue after their accepted GameState transition.
5. Rejected UI input, ticker rotation, rail navigation, ordinary buttons, and conditional-choice visibility remain silent. No click is emitted merely for focus or hover.
6. In Home, the player can adjust Master, Ambience, and SFX volume independently for the current session and can mute Master immediately.

The default mix must make the ambience felt rather than foregrounded. Contract cues must be audible over it but end quickly enough that they never delay reading or interaction.

## Asset Contract

The user supplies the final audio tracks. Before integration, normalize them to `.ogg` and place them at these exact paths:

| Path | Use | Required characteristics |
|---|---|---|
| `res://assets/audio/ambience/lower_vesper_apartment.ogg` | Operations ambience | Stereo, seamless loop, no melody or voice, low-intensity rain/city/HVAC/room tone. |
| `res://assets/audio/ui/terminal_enter.ogg` | Boot entry | Short terminal relay; under 1.5 seconds. |
| `res://assets/audio/ui/contract_accepted.ogg` | Accepted contract | Positive but restrained acknowledgment; under 1 second. |
| `res://assets/audio/ui/contract_proceeded.ogg` | Travel/proceed | Brief route/relay transition; under 1.5 seconds. |
| `res://assets/audio/ui/contract_completed.ogg` | Completed resolution | Clear, modest success confirmation; under 2 seconds. |
| `res://assets/audio/ui/contract_failed.ogg` | Failed resolution | Clear negative confirmation; under 2 seconds. |

Do not use speech, radio chatter, licensed music with uncertain provenance, or a melodic score in this slice. Ambient material must be licensed for distribution with this MIT project or be original work owned by the project.

An absent or unloadable required stream reports one actionable engine error naming its path and leaves that sound silent. It must not block boot, contract progression, or the rest of the mix.

## Runtime Architecture

Use Godot's native audio buses and scene-local players. Do not introduce an `AudioManager`, a generic event bus, a sound registry, or persistent settings storage.

### Buses

Add the project bus layout with three buses:

- **Master** — overall output; Home's mute and Master control change this bus.
- **Ambience** — Lower Vesper loop only.
- **SFX** — boot and contract one-shots.

Each slider maps its 0–100 range to Godot's bus volume in decibels. A value of zero silences the corresponding bus; all nonzero values use a logarithmic dB mapping so the control behaves perceptually rather than linearly. Controls begin at authored defaults on each launch because the project has no settings persistence.

### Scene ownership

- `boot.gd` owns one non-looping `AudioStreamPlayer` routed to **SFX**. It plays `terminal_enter.ogg` once after entry is accepted.
- `main.gd` owns one looping **Ambience** player and one non-looping **SFX** player. The ambience starts only after Main is ready. The SFX player plays the one-shot associated with an accepted contract transition.
- The Home panel owns only the three controls and calls Godot's `AudioServer` directly. It neither owns players nor reads/writes GameState.

### GameState transition signals

Expose semantic signals from `GameState`, emitted only after the existing transition succeeds:

- `contract_accepted(id: StringName)`
- `contract_proceeded(id: StringName)`
- `contract_resolved(id: StringName, status: StringName)`

`main.gd` maps these signals to the four contract cues. `contract_resolved` maps `completed` to `contract_completed.ogg` and `failed` to `contract_failed.ogg`. Existing `contracts_changed`, ticker, and Comms behavior remains unchanged.

The signals communicate contract facts, not audio IDs, so GameState retains no presentation knowledge. Invalid or out-of-phase methods return `false` as today and emit neither state changes nor sound signals.

## Home Audio Controls

Append a compact `AUDIO` section to the existing Home summary panel:

- `MASTER` slider plus `[ MUTE ]` toggle.
- `AMBIENCE` slider.
- `SFX` slider.

Controls are keyboard-focusable, expose their current percentage as text, and do not alter the current module or workspace state. `MUTE` sets Master to zero while retaining the prior Master value; toggling it again restores that value. Sliders apply immediately. No control writes to disk in this scope.

## Error Handling and Invariants

- Audio can never prevent the boot transition or a valid contract transition.
- A failed contract action emits no cue.
- Each accepted contract transition emits exactly one matching SFX cue.
- The ambience player is the only looping player and only runs while Main exists.
- Opening or refreshing panels cannot restart ambience or replay past contract cues.
- Master mute silences every bus; Ambience and SFX controls affect only their bus.
- No audio node or UI panel accesses the `GameState` autoload by name.

## Tests

Extend the existing headless GDScript tests with focused behavior:

1. GameState emits each new semantic signal exactly once for its accepted transition and never for rejected calls.
2. Main starts a single looping ambience player and maps accepted, proceeded, completed, and failed signals to the expected SFX stream without replay on refresh.
3. Boot plays its entry stream once despite repeated entry input.
4. Home controls change only their expected native audio bus, Master mute restores its prior value, and no setting mutates GameState.
5. Missing stream handling leaves the relevant player silent while the boot and contract path continue.
6. Run the full headless suite and manually smoke boot entry, one completed contract, one failed contract, Master mute, and each volume control with the supplied assets.

## Explicit Non-Goals

- No soundtrack, dynamic music, adaptive score, playlist, voice acting, radio chatter, or procedural audio.
- No hover/click spam, ticker sounds, ambient weather simulation, positional audio, or audio-reactive visuals.
- No audio manager, generalized event/effects system, registry, dependency, or external middleware.
- No save/load system, persistent settings file, settings module, profile, or unrelated workspace redesign.
- No changes to contract content, GameState rules, environment art, progression, economy, or post-portfolio content.
