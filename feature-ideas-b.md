# Feature Recommendations & Expansion Ideas

This document outlines high-leverage feature additions for *Operator* that build directly on the existing UI-first terminal shell, event-sequence contract resolution engine, and data-driven catalogs without requiring real-time action mechanics.

---

## 1. Key Assets & Tool Inventory (Contract Enablers)
* **Concept:** An inventory module (`res://scenes/modules/inventory/`) for consumable and reusable operational assets (e.g., *Military-Grade Scrambler*, *Forged Dock Pass*, *Sub-dermal ICE Shunt*, *Burner Transponder*).
* **Gameplay Hook:** Expands contract complication choices. Instead of choices checking only Credits or Heat thresholds, high-reward or low-risk resolutions check for specific gear in inventory (`requires_item: "scrambler"`), consuming it or risking degradation upon use.
* **Architecture Fit:** 
  * Add item catalog in `data/items/item_catalog.gd`.
  * Track `owned_item_ids: Array[StringName]` in `GameState`.
  * Render a clean item grid panel plugged into `module_registry.tres`.

---

## 2. Specialist Roster & Mission Delegation
* **Concept:** A crew/operatives module where the player recruits freelance specialists (hackers, drivers, enforcers, fixers) on salary or revenue-share.
* **Gameplay Hook:** Supports the core fantasy of evolving from a solo field runner to a remote dispatcher.
  * **Solo Execution:** 100% reward, full personal risk of injury and Heat accumulation.
  * **Delegated Execution:** Operative resolves complications based on their individual traits/risk ratings; cuts into profit margins and risks operative capture/injury on critical failures.
* **Architecture Fit:** Extends the existing event-sequence resolution engine by evaluating complication choice trees against assigned operative attributes rather than manual player inputs.

---

## 3. Active Heat Repercussions & Corporate Audits
* **Concept:** Dynamic escalation events tied to the `heat` variable when resting, traveling, or completing contracts.
* **Gameplay Hook:** Transforms Heat from a passive gate into an active threat:
  * **Level 3–4 (Elevated):** Increased transit tolls, delayed contract payouts due to frozen accounts.
  * **Level 5+ (Critical):** Safehouse raids on sleep, forced sudden relocations (eviction), burner hardware confiscation, or hostile ambush event sequences delivered through the Comms feed.
* **Architecture Fit:** Add a lightweight check inside `GameState.advance_time()` that triggers emergency event overlays or urgent comms dispatches before morning resolution.

---

## 4. Intel Gathering & Network Sniffing (Pre-Mission Phase)
* **Concept:** A packet-interception and surveillance tool inside the terminal shell.
* **Gameplay Hook:** Before accepting high-risk contracts, players tap into district sub-nodes, review leaked audio transcripts, or buy broker tips in the Comms feed. Gathering intel uncovers hidden complication options (e.g., discovering security shift rotations unlocks a clean bypass choice during execution).
* **Architecture Fit:** Data-driven text logs and simple flag unlocks (`discovered_intel: Array[StringName]`) evaluated during contract resolution.

---

## 5. District Network & Multi-Location Progression
* **Concept:** A district travel map linking Lower Vesper, Sector 9, Harbor Ward, and Industrial Outer Rim.
* **Gameplay Hook:**
  * Each district hosts unique local contracts, market rates, and contact bases.
  * Moving between districts consumes transit time, costs transit fees, and triggers customs checkpoints if Heat is high.
  * Pairs with the existing layered environment system to load distinct skyline art, ambient audio, and weather profiles per district.
* **Architecture Fit:** Extends `residence_catalog.gd` into a broader `district_catalog.gd` driving both background assets and local contract filtering.

---

## 6. Procedural Contract Generator (Post-Authored Sandbox)
* **Concept:** An algorithmic contract generator using modular contract templates (Cargo Transport, Infiltration, Extraction, Asset Audit).
* **Gameplay Hook:** Once authored story contracts are completed, contacts issue randomized jobs constructed from combinatorial event components (Client + Cargo Type + Complication + Choice Array).
* **Architecture Fit:** Directly reuses the existing `complication` dictionary schema from `ContractCatalog`, enabling an infinite end-game loop without modifying the UI renderer.
