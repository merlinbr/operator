# Terminal Boot Sequence

**Date:** 2026-08-28  
**Status:** Design approved; specification review pending  
**Scope:** Add a brief, skippable in-world terminal boot before the existing operations workspace.

## Goal

Make starting Operator feel intentional without delaying repeat launches. The application begins on a separate Boot scene that reveals a concise terminal diagnostic over roughly 5.4 seconds while exposing an immediate entry action. Any accepted entry input reveals the remaining diagnostic lines, fades the boot panel, and loads the existing Main scene.

The feature is presentation-only. It does not construct, modify, or inspect gameplay state.

## Player Experience

Every fresh application launch opens this full-viewport screen:

```text
OPERATOR // LOCAL TERMINAL
──────────────────────────
NODE       LOWER VESPER
UPLINK     SECURE
LOCAL TIME DAY 14 // 23:41
WORK QUEUE 01 AVAILABLE
MESSAGE    MARA // UNREAD

[ ENTER OPERATIONS ]
```

The five diagnostic lines reveal in the displayed order at one line every 0.9 seconds. The title and `[ ENTER OPERATIONS ]` action are visible at first frame. The action is always enabled; players are never required to wait for the diagnostic.

Until a save system exists, the sequence is shown on every process launch. The displayed location, time, queue count, and message are fixed opening-premise copy—not a stale snapshot or a separate source of gameplay state.

## Entry Interaction

Any of these inputs enters operations immediately:

- pressing `[ ENTER OPERATIONS ]`;
- primary mouse click in the screen background;
- `ui_accept` (Enter or Space under the default input map);
- `ui_cancel` (Escape);
- any non-echo keyboard key.

The first accepted input:

1. makes all currently hidden diagnostic lines visible;
2. marks the scene as entering so later input and button signals do nothing;
3. fades the boot panel to transparent over exactly 0.2 seconds;
4. changes to `res://scenes/main/main.tscn`.

Input never begins more than one transition. The diagnostic reveal timer stops when entry begins.

## Visual Structure

The new `scenes/boot/boot.tscn` root is a full-rect `Control` using `res://resources/operator_theme.tres`. It contains one centered narrow `PanelContainer`; the panel’s content is built by `boot.gd` with existing native `Label`, `Button`, and container controls.

- Root background: near-black opaque `ColorRect`, using `Color(0.012, 0.020, 0.031, 1.0)`.
- Panel: existing theme `PanelContainer` treatment, compact/narrow width similar to the Home module.
- Font: existing theme and JetBrains Mono; title uses `JetBrainsMono-Bold.ttf` at 18 px.
- Diagnostic labels: existing muted theme body color, initially invisible.
- Entry button: ordinary themed `Button`, text exactly `ENTER OPERATIONS`, visible and enabled from initial layout.

No apartment art, environmental effects, custom shaders, audio, title-logo asset, or new theme resource is required.

## Architecture and Ownership

### Boot

`boot.gd` owns only boot-local presentation and routing:

```gdscript
signal enter_requested

func _reveal_next_line() -> void
func _enter_operations() -> void
func _on_enter_requested() -> void
func _on_unhandled_input(event: InputEvent) -> void
```

It stores the five labels, a one-shot/repeating `Timer`, an `_entering` Boolean, and a boot-panel tween. On `_ready()`, it builds controls, makes title/button visible, hides diagnostics, starts the 0.9-second timer, connects the entry button, and connects `enter_requested` to `_on_enter_requested()`.

`_reveal_next_line()` reveals the next hidden label. Once all lines are visible, it stops the timer.

`_enter_operations()` returns if `_entering` is already true. Otherwise it sets `_entering`, stops the timer, reveals every line, and emits `enter_requested`.

`_on_enter_requested()` fades the centered panel over 0.2 seconds, then changes scene to the preloaded Main scene. The private signal listener lets the scene route itself in production while a headless test disconnects it to assert the intent without changing scenes.

`_on_unhandled_input()` ignores released and keyboard-echo events. It invokes entry for `ui_accept`, `ui_cancel`, or any pressed key. Primary mouse background clicks are handled through the root’s GUI input callback and invoke the same entry method. Button activation uses that method directly.

### Project configuration

Only `project.godot` changes its application entry point:

```ini
run/main_scene="res://scenes/boot/boot.tscn"
```

`Main.tscn`, `main.gd`, GameState, contracts, environment, HUD, and workspace code remain unchanged.

## Error Handling and Invariants

- Button and all entry input funnel through `_enter_operations()`; no duplicate transition is possible.
- A skipped diagnostic reveals all lines before fading; the screen never transitions with hidden content still scheduled.
- Repeated timer timeouts after all lines are visible do not index past the label array.
- Repeated timer timeouts after entry begins do nothing because the timer is stopped and `_entering` is true.
- The root accepts background clicks but the centered button still receives its own activation.
- A headless test must disconnect Boot’s internal scene-transition listener or otherwise suppress actual routing while asserting the `enter_requested` signal; production routing must remain connected.
- The new main scene must load the existing Main scene successfully in the real project.

## Tests

Add `tests/test_boot.gd` using the existing `test_base.gd` harness:

1. Boot builds title, five diagnostics, and the immediately enabled `ENTER OPERATIONS` button.
2. Diagnostics start hidden and reveal in exact order when `_reveal_next_line()` is invoked repeatedly.
3. A sixth reveal is a no-op and does not error.
4. `_enter_operations()` reveals all remaining diagnostics, stops the timer, sets `_entering`, and emits `enter_requested` once.
5. A second `_enter_operations()` call emits no second signal and creates no second transition.
6. A pressed non-echo key and `ui_accept` route through the same entry path.
7. `test_smoke.gd` loads the new Boot scene; a focused running-project smoke confirms pressing `ENTER OPERATIONS` reaches the existing Home workspace.
8. Full existing headless suite remains green.

## Explicit Non-Goals

- No save slots, profiles, settings, quit action, version/update display, or title-menu options.
- No cinematic, extended narrative, loading screen, audio, logo art, animation system, or splash-screen plugin.
- No gameplay-state initialization, reset, persistence, direct GameState read, or opening-contract logic.
- No changes to Main, GameState, contracts, environment, HUD, rail, ticker, Comms, theme, or workspace layout.
