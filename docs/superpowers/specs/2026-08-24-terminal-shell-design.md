# Terminal Shell (Slice 0) — Design Specification

**Date:** 2026-08-24
**Status:** Approved design, pending implementation plan
**Engine:** Godot 4.7.1
**Scope:** First main scene of the Operator RPG — the operations terminal shell

## 1. Purpose

Establish the primary gameplay surface: an environment-first operations terminal that all
future game modules (contract board, comms, crew, market, map) plug into. This slice
proves the layout, theming, state, and module-switching architecture with placeholder
content — no real game systems yet.

Core composition principles (agreed during brainstorming):

- **Environment first.** A full-screen illustrated location scene sits behind everything.
  The workspace floats over it; there is no full-screen terminal frame.
- **Collapsible workspace.** The player can collapse all panels and enjoy the environment
  (early game: a concrete wall and a leaking pipe). Upgrading the apartment/location
  upgrades the view — the environment is progression made visible.
- **Floating visually, docked functionally.** Panels look like detached floating cards,
  but positions are auto-arranged. One primary panel + one optional contextual side
  panel. No free window management, no dragging in this slice.
- **Restrained aliveness.** Environments are illustrated scenes with subtle layered
  effects (rain, neon flicker, steam, distant traffic, light parallax) — not real-time
  interactive scenes.

## 2. Scene architecture

```
Main (Control, full rect)
├── EnvironmentLayer          ← full-screen, behind everything
│   ├── BaseArt               ← illustrated backdrop (placeholder in this slice)
│   ├── ParallaxLayers        ← subtle depth: sky / midground / foreground
│   └── Effects               ← rain, neon flicker, steam (shader/particle based)
└── Workspace (Control, full rect)
    ├── StatusChip            ← top-center, always visible: credits / district / clock
    ├── CollapseToggle        ← top-right, toggles workspace state
    ├── IconRail              ← left, floating, grouped, unlockable modules
    ├── PrimaryPanel          ← the one active module panel (auto-docked)
    ├── ContextPanel          ← optional side panel for detail views (auto-docked)
    └── TickerBar             ← bottom strip: contextual messages / events
```

### Behavior

- **Module switching.** Clicking a rail icon swaps the `PrimaryPanel` content. Each module
  is its own scene (`home_panel.tscn`, `comms_panel.tscn`, `contracts_panel.tscn`, …).
  `Main.gd` owns switching; modules never load other modules directly.
- **Context panel.** Opens on demand (e.g. selecting a contract row opens its detail view
  beside the primary panel). Auto-layout reserves the horizontal split; the primary panel
  shrinks, nothing overlaps.
- **Collapse.** Collapsing tweens all workspace panels out (fade + slide), leaving only
  StatusChip, IconRail, TickerBar, and the environment. Clicking any rail module re-opens
  the workspace with that module active. The collapse state persists across module
  switches within a session.
- **Panel chrome.** Panels have minimal chrome: title row with close (primary) / back
  (context) affordances. Panels are mouse-opaque; the Workspace root is mouse-transparent
  where empty so the environment remains clickable later.

## 3. Icon rail

Slim, floating, icon-based (icon + label on hover), grouped by player intent:

1. **Core modules (prominent, unlocked early):** Home · Comms · Contracts
2. **Operational modules (unlock over time):** Crew · Market · Assets · Map
3. **Utility (separated by divider):** Alerts (badge count when nonzero)

### Unlock visibility (hybrid rule)

- The **next few relevant** modules are visible but greyed-out with a lock indicator, so
  the player sees their terminal growing.
- **Truly late-game** systems (e.g. Political Influence, Holdings, Fleet) are **hidden**
  until their unlock context approaches — they never clutter the rail or spoil progression.
- In this slice: Home, Comms, Contracts unlocked; Crew, Market, Map visible-but-locked;
  Assets and everything later not yet defined in data (hidden by absence).

## 4. State & data flow

- **One autoload: `GameState`** — credits, district, clock, heat, plus workspace UI state
  (collapsed or not). Emits signals on change. `StatusChip`, `TickerBar`, and others
  subscribe; panels receive data via their owning code, they do not reach into state
  singletons from deep inside the tree.
- **Module registry** — a simple data resource: array of module definitions
  (id, display name, icon, rail group, unlock flag/condition). The rail renders from this
  resource; adding a module = adding a definition + a scene, not editing the rail script.
- **Placeholder content** — dummy contracts/messages live in clearly-marked placeholder
  data files, isolated for easy replacement. No content hard-coded in UI scenes
  (per project context.md principles).

## 5. Theme & visual identity

- **Single theme resource `operator_theme.tres`** applied at `Main` root.
- **Palette** (from approved mockup):
  - Panel background: near-black with slight transparency (rgba ~ (8,12,17,0.82))
  - Borders: 1px desaturated blue-grey (#2c404c family), dashed variants for secondary
  - Primary accent: cyan (#39d0ff) — active module, highlights, links
  - Credits/warnings: amber (#ffd27a / #ffb347)
  - Alerts/negative: red (#ff5a78)
  - Body text: desaturated blue-white (#8fa8b5 family)
- **Typography:** monospace as the terminal identity. Ship **JetBrains Mono** (open
  license) in `assets/fonts/`; do not rely on the engine default font.
- **Environment placeholder:** layered gradient skyline + shader rain + 2–3 flickering
  neon elements — enough to validate layering and parallax, replaced by real illustration
  later. Structure it as swappable layers so art can drop in without code changes.

## 6. Resolution & layout

- **Reference/design resolution: 1920×1080**, `canvas_items` stretch mode (already set),
  `expand` aspect.
- Control layouts must remain clean at **1280×720** minimum: panels use anchors/containers
  (no fixed pixel positions), rail and chip scale with the viewport, ticker spans full
  width. No work required below 1280×720 in this slice.

## 7. File layout

```
res://
  autoload/game_state.gd
  scenes/main/            main.tscn, main.gd, environment.tscn, environment.gd
  scenes/ui/              status_chip, icon_rail, ticker_bar, collapse_toggle (+ .gd each)
  scenes/modules/home/    home_panel.tscn/gd
  scenes/modules/comms/   comms_panel.tscn/gd
  scenes/modules/contracts/ contracts_panel.tscn/gd
  resources/              operator_theme.tres, module_registry.tres
  assets/fonts/           JetBrains Mono
  assets/environments/    placeholder environment layers
  data/placeholder/       dummy contracts/messages
```

## 8. Out of scope (this slice)

- Real contract/comms content or game logic
- Save/load system
- Audio
- Final art assets (placeholders only)
- Panel dragging / free window management
- Responsive layouts below 1280×720
- Any additional autoloads beyond `GameState`

## 9. Success criteria

- Project runs to the terminal shell directly (set as main scene)
- All three unlocked modules switch via the rail without scene reload flicker
- Context panel opens/closes alongside a primary panel with clean auto-layout
- Collapse toggle hides all panels; environment + chip + rail + ticker remain; clicking a
  rail module restores the workspace
- Locked modules render greyed with lock; hidden modules are absent
- Layout holds together at 1280×720 and looks intended at 1920×1080
