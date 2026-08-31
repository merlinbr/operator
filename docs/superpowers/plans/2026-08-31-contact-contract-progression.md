# Contact Contract Progression Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add seven authored contracts across two Contacts, visible one-way Contact standing, and save migration that preserves every valid version-1 profile.

**Architecture:** `ContactCatalog` owns immutable Contact definitions and tier labels; `ContractCatalog` owns immutable authored contracts and choice consequences. `GameState` owns mutable standings, authoritative availability, resolution updates, profile migration, and signals. COMMS and Contracts render snapshots from `GameState` and emit no state mutations.

**Tech Stack:** Godot 4.7, GDScript, existing `SceneTree` test harness, JSON single-profile persistence.

## Global Constraints

- Contact standing is exactly `COLD` (0), `KNOWN` (1), and `TRUSTED` (2); it only increases by 0 or 1 and caps at 2.
- Favor and Contact standing remain separate mechanics.
- Preserve the existing contract event sequence, existing reward/Heat/favor outcomes, atomic profile replacement, and no-dead-end publication behavior.
- Version-1 profiles must migrate to version 2 without a clean-profile reset or lost progress.
- Do not add factions, negative standing, generated content, a Contact module, a weather system, or a dependency.

---

### Task 1: Author the Contacts and seven-contract portfolio

**Files:**
- Create: `data/contacts/contact_catalog.gd`
- Modify: `data/contracts/contract_catalog.gd`
- Modify: `tests/test_contract_catalog.gd`

**Interfaces:**
- Produces `ContactCatalog.all() -> Array[Dictionary]`, `ContactCatalog.get(id: StringName) -> Dictionary`, and `ContactCatalog.standing_label(standing: int) -> String`.
- Every contract record provides `contact_id: StringName` and `minimum_contact_standing: int`; every resolution choice provides `contact_standing_delta: int`.

- [ ] **Step 1: Add failing catalog assertions**

Extend `tests/test_contract_catalog.gd` to preload `ContactCatalog` and assert the exact Contact IDs, initial standings, and labels:

```gdscript
var contacts := ContactCatalog.all()
check(contacts.map(func(contact: Dictionary) -> StringName: return contact.id)
	== [&"mara", &"vesper_clinic"], "catalog owns Mara and Vesper Clinic")
check(ContactCatalog.get(&"mara").starting_standing == 1
	and ContactCatalog.get(&"vesper_clinic").starting_standing == 0,
	"authored contacts start Known and Cold")
check(ContactCatalog.standing_label(0) == "COLD"
	and ContactCatalog.standing_label(1) == "KNOWN"
	and ContactCatalog.standing_label(2) == "TRUSTED",
	"standing labels are fixed and visible")
```

Add assertions that the contract IDs equal:

```gdscript
[&"cold_chain_delivery", &"data_retrieval", &"dead_drop_audit",
 &"silent_partner", &"clinic_asset_recovery", &"dialysis_relay",
 &"quarantine_manifest"]
```

For every record, assert a valid Contact ID, a minimum in `[0, 2]`, and that every choice has `contact_standing_delta` in `[0, 1]`.

- [ ] **Step 2: Run the catalog test red**

Run:

```powershell
rtk powershell -ExecutionPolicy Bypass -File tests/run_test.ps1 test_contract_catalog
```

Expected: failure because no Contact catalog or expanded portfolio exists.

- [ ] **Step 3: Add immutable Contact data**

Create `data/contacts/contact_catalog.gd`:

```gdscript
class_name ContactCatalog
extends RefCounted

const COLD := 0
const KNOWN := 1
const TRUSTED := 2

static func all() -> Array[Dictionary]:
	return [
		{"id": &"mara", "display_name": "MARA", "starting_standing": KNOWN},
		{"id": &"vesper_clinic", "display_name": "VESPER CLINIC", "starting_standing": COLD},
	]

static func get(id: StringName) -> Dictionary:
	for contact in all():
		if contact.id == id:
			return contact
	return {}

static func standing_label(standing: int) -> String:
	return ["COLD", "KNOWN", "TRUSTED"][clampi(standing, COLD, TRUSTED)]
```

- [ ] **Step 4: Expand authored contract content**

Add `contact_id` and `minimum_contact_standing` to all current records. Add `contact_standing_delta` to every current choice: only authored strong completions receive `1`; aborts and weak outcomes receive `0`.

Add these four records, each following the existing offer/proceed/complication/choices shape and with at least one success, one costly-or-risky success, and one abort outcome:

```gdscript
{"id": &"dead_drop_audit", "code": "M-508", "contact_id": &"mara",
 "minimum_contact_standing": 1, "is_playable": false}
{"id": &"silent_partner", "code": "M-613", "contact_id": &"mara",
 "minimum_contact_standing": 2, "is_playable": false}
{"id": &"dialysis_relay", "code": "H-118", "contact_id": &"vesper_clinic",
 "minimum_contact_standing": 1, "is_playable": false}
{"id": &"quarantine_manifest", "code": "Q-219", "contact_id": &"vesper_clinic",
 "minimum_contact_standing": 2, "is_playable": false}
```

Publish `dead_drop_audit` alongside `data_retrieval` after C-1042; publish `silent_partner` after D-207; keep R-311 published after D-207; publish `dialysis_relay` after R-311 and `quarantine_manifest` after H-118. Every publisher's completed and abort choices must carry the same `unlocks_contract_id`.

- [ ] **Step 5: Run the catalog test green**

Run the command from Step 2.

Expected: `RESULT: ALL PASSED`.

### Task 2: Make standing authoritative and migrate profiles

**Files:**
- Modify: `autoload/game_state.gd`
- Modify: `tests/test_game_state.gd`
- Modify: `tests/test_persistence.gd`

**Interfaces:**
- Produces `contacts_changed`, `contact_standing: Dictionary`, `contact_snapshot() -> Array[Dictionary]`, `standing_for(contact_id: StringName) -> int`, and `is_contract_available(contract: Dictionary) -> bool`.
- Consumes contract `contact_id`, `minimum_contact_standing`, and choice `contact_standing_delta` fields from Task 1.
- Profile version changes from `1` to `2`; `_migrate_v1_profile(data: Dictionary) -> Dictionary` normalizes old valid data before version-2 validation.

- [ ] **Step 1: Add failing behavior and migration tests**

In `tests/test_game_state.gd`, assert fresh Mara and Vesper standings, that a `TRUSTED` Mara job rejects at `KNOWN`, a qualifying C-1042 resolution raises Mara once, and an abort never lowers it:

```gdscript
check(gs.standing_for(&"mara") == 1 and gs.standing_for(&"vesper_clinic") == 0,
	"fresh contact standings are Known and Cold")
check(not gs.accept_contract(&"silent_partner"),
	"Trusted Mara work rejects a Known operator")
```

In `tests/test_persistence.gd`, construct a version-1 payload from the existing saved profile, remove `contact_standing`, set `version` to `1`, write it, and assert after `load_profile()` that Credits, active/matching contract state, and housing remain unchanged; Mara is `KNOWN`, Clinic is `KNOWN` only after a completed R-311; and all seven authored contracts exist.

- [ ] **Step 2: Run the state and persistence tests red**

Run:

```powershell
rtk powershell -ExecutionPolicy Bypass -File tests/run_test.ps1 test_game_state
rtk powershell -ExecutionPolicy Bypass -File tests/run_test.ps1 test_persistence
```

Expected: failures because Contact standing, availability gating, and version-1 migration do not yet exist.

- [ ] **Step 3: Add mutable standings and one authoritative availability predicate**

Preload `ContactCatalog`; add the signal and state:

```gdscript
signal contacts_changed
const PROFILE_VERSION := 2
var contact_standing: Dictionary = _default_contact_standing()
```

Implement the helpers so every caller uses the same gating rule:

```gdscript
func standing_for(contact_id: StringName) -> int:
	return int(contact_standing.get(contact_id, 0))

func is_contract_available(contract: Dictionary) -> bool:
	return contract.is_playable and contract.status == &"available" \
		and standing_for(contract.contact_id) >= int(contract.minimum_contact_standing)
```

Make `accept_contract()` call `is_contract_available(contract)` instead of checking only `is_playable`, `status`, and `phase`. After a valid resolution, apply the authored delta with `min(current + delta, ContactCatalog.TRUSTED)`, emit `contacts_changed` only if a tier changed, then save through the existing path.

`contact_snapshot()` must combine immutable Contact display data with the mutable tier and its `standing_label`, without exposing the mutable dictionary.

- [ ] **Step 4: Persist, validate, and migrate version 1**

Include `contact_standing` in `_profile_payload()`. Before normal validation in `_read_profile_candidate`, normalize version-1 data using `_migrate_v1_profile()`.

Migration must start from `ContractCatalog.all()`, index the old records by `id`, and copy only these mutable fields when the ID exists:

```gdscript
["is_playable", "status", "phase", "resolution_id"]
```

It must retain all other profile fields, append new authored contracts as their defaults, set Mara to `KNOWN`, set Clinic to `KNOWN` only when `clinic_asset_recovery.status == &"completed"`, and set `version` to `2`. Validation must require exactly the two authored Contact IDs with integer values from 0 through 2.

- [ ] **Step 5: Run the state and persistence tests green**

Run the commands from Step 2.

Expected: both print `RESULT: ALL PASSED`.

### Task 3: Render standings and locked requirements in existing modules

**Files:**
- Modify: `scenes/modules/comms/comms_panel.gd`
- Modify: `scenes/modules/contracts/contracts_panel.gd`
- Modify: `scenes/main/main.gd`
- Modify: `tests/test_panels_basic.gd`
- Modify: `tests/test_main.gd`

**Interfaces:**
- Consumes `GameState.contact_snapshot()`, `GameState.messages`, and `GameState.is_contract_available(contract)`.
- COMMS setup receives `{"contacts": Array, "messages": Array}`.
- Contracts setup receives the `GameState` and `gs.contracts`; its selectable predicate delegates to `gs.is_contract_available(contract)`.

- [ ] **Step 1: Add failing UI assertions**

Add COMMS assertions that fresh state renders `MARA // KNOWN` and `VESPER CLINIC // COLD` before the message rows. Add contract-panel assertions that an unpublished contract says `NETWORK OFFLINE`, while a published but under-qualified contract says `MARA // TRUSTED REQUIRED` or `VESPER CLINIC // KNOWN REQUIRED` and is disabled.

- [ ] **Step 2: Run panel and main tests red**

Run:

```powershell
rtk powershell -ExecutionPolicy Bypass -File tests/run_test.ps1 test_panels_basic
rtk powershell -ExecutionPolicy Bypass -File tests/run_test.ps1 test_main
```

Expected: failures because COMMS has no Contact rows and contract rows do not report standing requirements.

- [ ] **Step 3: Render Contact rows in COMMS**

Add a `CONTACTS` label and one compact label row per `contact_snapshot()` entry before `_rows_box`. Accept a data dictionary in `setup()` and render Contacts first, then the existing message rows. Keep COMMS read-only and preserve the existing unread-message rendering.

- [ ] **Step 4: Make Contracts use GameState availability and explain locks**

Replace the local selectability condition with `gs.is_contract_available(contract)`. In `_row_text`, preserve `NETWORK OFFLINE` for unpublished records; for a published available record below its Contact standing, return:

```gdscript
"%s // %s REQUIRED" % [
	contract.contact_id.to_upper(),
	ContactCatalog.standing_label(int(contract.minimum_contact_standing)),
]
```

Use the Contact catalog display name rather than the raw ID in the final code. Completed, failed, and active rows retain their current text.

- [ ] **Step 5: Route snapshots and refresh active panels**

In `Main.select_module()`, pass this COMMS data shape:

```gdscript
{"contacts": gs.contact_snapshot(), "messages": gs.messages}
```

Connect `contacts_changed` and refresh only an open active COMMS panel. Continue using `contracts_changed` for contracts; the standing mutation must also trigger its contract availability refresh.

- [ ] **Step 6: Run panel and main tests green**

Run the commands from Step 2.

Expected: both print `RESULT: ALL PASSED`.

### Task 4: Verify the complete playable and persistence paths

**Files:**
- Test: `tests/run_all.ps1`

**Interfaces:**
- Verifies the complete seven-contract catalog, standing UI, standing-gated acceptance, legacy migration, and existing housing/contract behavior together.

- [ ] **Step 1: Run the full suite**

Run:

```powershell
rtk powershell -ExecutionPolicy Bypass -File tests/run_all.ps1
```

Expected: every suite prints `RESULT: ALL PASSED` and the runner exits zero.

- [ ] **Step 2: Run an interactive smoke scenario**

Start a clean profile. Verify COMMS starts with Mara `KNOWN` and Vesper Clinic `COLD`; complete a standing-raising Mara outcome; confirm the relevant locked Mara row becomes selectable; complete R-311; confirm the Clinic status advances; then restart and verify the status and unlocked contract states persist. Repeat from a synthetic version-1 save and confirm no reset occurs.

- [ ] **Step 3: Commit the focused slice**

```powershell
rtk git add autoload/game_state.gd data/contacts/contact_catalog.gd data/contracts/contract_catalog.gd scenes/main/main.gd scenes/modules/comms/comms_panel.gd scenes/modules/contracts/contracts_panel.gd tests/test_contract_catalog.gd tests/test_game_state.gd tests/test_persistence.gd tests/test_panels_basic.gd tests/test_main.gd context.md docs/superpowers/specs/2026-08-31-contact-contract-progression-design.md docs/superpowers/plans/2026-08-31-contact-contract-progression.md
rtk git commit -m "feat: add contact contract progression"
```

## Self-review

- **Spec coverage:** Tasks 1–3 cover authored Contacts/contracts, one-way availability, COMMS and board presentation, profile v2 persistence, and v1 migration. Task 4 verifies every stated acceptance path.
- **Placeholder scan:** no unbounded content system, unspecified interface, or generic test task remains.
- **Type consistency:** Contract contact fields are `StringName` and `int`; mutable standing is a `Dictionary`; UI consumes snapshots; profile migration produces the same version-2 shape validated by `GameState`.
