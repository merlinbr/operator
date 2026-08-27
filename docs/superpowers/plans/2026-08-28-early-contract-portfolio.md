# Early Contract Portfolio Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Expand Contract Network into a linear, deterministic three-contract early-game portfolio where prior Heat and Mara-favor decisions change later authored choices.

**Architecture:** Keep the existing static `ContractCatalog` Dictionary records and `GameState`-owned mutable records. Contract availability remains the existing `is_playable` flag; each terminal choice optionally unlocks one successor. `GameState` filters conditional choice snapshots and validates the same conditions on resolution, while Contract Detail remains a pure renderer of the supplied snapshot and Main retains its existing refresh behavior.

**Tech Stack:** Godot 4.7.1, GDScript, existing native `Control` scenes, existing minimal headless `SceneTree` test harness, PowerShell.

## Global Constraints

- Preserve the existing C-1042 player-visible outcomes: `pay_fee` +1,150 CR/+0 Heat; `call_mara` +1,400 CR/+0 Heat and set `mara_favor_owed`; `bypass` +1,400 CR/+2 Heat; `abort` failed/+0 CR/+0 Heat.
- The portfolio unlock order is C-1042 → D-207 → R-311. A terminal success **or** failure unlocks the successor.
- The only new cross-contract conditions are D-207’s `Heat < 4` / `Heat >= 4` identity-route substitution and R-311’s existing `mara_favor_owed` condition.
- Keep the existing statuses (`available`, `active`, `completed`, `failed`) and phases (`offer`, `ready_to_proceed`, `customs_hold`, `resolved`).
- `GameState` remains the sole mutable-state owner. UI emits intent and must never calculate effects or mutate GameState.
- Use no new dependency, autoload, manager, Resource hierarchy, event graph, quest engine, RNG, deadline-expiry system, timer-driven progression, combat, or free-roam system.
- Use the existing floating Contract Network and adjacent Contract Detail workspace. Do not redesign the HUD, rail, environment, ticker, theme, or Comms layout.
- Prefix every shell command with `rtk`.

---

## File Map

| File | Responsibility after this plan |
|---|---|
| `data/contracts/contract_catalog.gd` | Static authored C-1042, D-207, and R-311 records, including availability, conditional choices, authored feedback, and successor IDs. |
| `autoload/game_state.gd` | Dynamic availability filtering, generic authored resolution feedback, successor unlocking, and conditional-choice validation. |
| `scenes/modules/contracts/contract_detail.gd` | Renders contract-specific proceed labels instead of the hard-coded Dock 17 label. |
| `tests/test_contract_catalog.gd` | Catalog content and fresh-record assertions for all three authored contracts. |
| `tests/test_game_state.gd` | Availability, transitions, outcome effects, Heat substitution, favor settlement, and invalid hidden-choice behavior. |
| `tests/test_contracts.gd` | Contract Detail rendering for dynamic proceed labels and filtered conditional choices. |
| `tests/test_main.gd` | Sequential workspace unlock/refresh behavior across all three jobs. |
| `README.md` | Accurate prototype status, active slice description, and valid design-document links. |

### Runtime interfaces

`GameState` adds or changes only these private helpers; public UI intent methods remain unchanged:

```gdscript
func get_contract(id: StringName) -> Dictionary
func _available_choices(contract: Dictionary) -> Array[Dictionary]
func _choice(choices: Array[Dictionary], choice_id: StringName) -> Dictionary
func _unlock_contract(id: StringName) -> void
func _push_resolution_feedback(choice: Dictionary) -> void
```

Every playable catalog contract has:

```gdscript
{
    "id": StringName,
    "code": String,
    "title": String,
    "client": String,
    "reward_credits": int,
    "risk": String,
    "destination": String,
    "deadline_day": int,
    "deadline_minute": int,
    "is_playable": bool,
    "status": StringName,
    "phase": StringName,
    "resolution_id": StringName,
    "proceed_minutes": int,
    "proceed_label": String,
    "accept_message": String,
    "proceed_message": String,
    "complication": {"title": String, "body": String, "choices": Array[Dictionary]},
}
```

Every terminal choice has `id`, `label`, `credit_delta`, `heat_delta`, `terminal_status`, `preview`, `result`, `ticker`, `message_sender`, and `message_preview`. A choice may additionally define `max_heat`, `min_heat`, `requires_mara_favor`, `sets_mara_favor_owed`, `clears_mara_favor`, and `unlocks_contract_id`.

---

### Task 1: Author the three-contract catalog

**Files:**
- Modify: `data/contracts/contract_catalog.gd`
- Modify: `tests/test_contract_catalog.gd`

**Interfaces:**
- Consumes: The existing `ContractCatalog.all() -> Array[Dictionary]` static fresh-record provider.
- Produces: Three complete authored records: enabled C-1042, disabled D-207, and disabled R-311. Every terminal choice has authored feedback and successor metadata.

- [ ] **Step 1: Replace the catalog test with assertions for the entire portfolio**

In `tests/test_contract_catalog.gd`, retain the fresh-copy check and replace the body of `_run()` with assertions covering the three-record sequence and the exact new content:

```gdscript
func _run() -> void:
    var contracts := ContractCatalog.all()
    check(contracts.size() == 3, "catalog contains the three-contract early portfolio")

    var delivery: Dictionary = contracts[0]
    check(delivery.id == &"cold_chain_delivery" and delivery.code == "C-1042",
        "C-1042 remains the first contract")
    check(delivery.is_playable and delivery.proceed_label == "DOCK 17",
        "C-1042 starts enabled with its existing proceed label")
    for choice: Dictionary in delivery.complication.choices:
        check(choice.has("ticker") and choice.has("message_sender")
            and choice.has("message_preview") and choice.has("unlocks_contract_id"),
            "each C-1042 outcome has authored feedback and a successor")
        check(choice.unlocks_contract_id == &"data_retrieval",
            "every C-1042 outcome unlocks D-207")

    var data_retrieval: Dictionary = contracts[1]
    check(data_retrieval.id == &"data_retrieval" and data_retrieval.code == "D-207",
        "second contract is D-207")
    check(not data_retrieval.is_playable and data_retrieval.proceed_minutes == 55
        and data_retrieval.proceed_label == "TRANSIT EXCHANGE",
        "D-207 starts locked and has its authored travel action")
    check(data_retrieval.deadline_day == 15 and data_retrieval.deadline_minute == 7 * 60,
        "D-207 deadline is Day 15 at 07:00")
    check(_choice(data_retrieval, &"spoof_credentials").max_heat == 3,
        "credential spoof is limited to Heat below four")
    check(_choice(data_retrieval, &"routed_vendor_id").min_heat == 4,
        "routed vendor ID replaces spoofing at Heat four or above")
    for choice: Dictionary in data_retrieval.complication.choices:
        check(choice.unlocks_contract_id == &"clinic_asset_recovery",
            "every D-207 outcome unlocks R-311")

    var recovery: Dictionary = contracts[2]
    check(recovery.id == &"clinic_asset_recovery" and recovery.code == "R-311",
        "third contract is R-311")
    check(not recovery.is_playable and recovery.proceed_minutes == 65
        and recovery.proceed_label == "MEDICAL SUBLEVEL",
        "R-311 starts locked and has its authored travel action")
    check(recovery.deadline_day == 15 and recovery.deadline_minute == 12 * 60,
        "R-311 deadline is Day 15 at 12:00")
    var hand_delivery := _choice(recovery, &"settle_mara_favor")
    check(hand_delivery.requires_mara_favor and hand_delivery.clears_mara_favor
        and hand_delivery.credit_delta == 2600,
        "R-311 contains the lower-paying Mara favor settlement")

    contracts[0].status = &"completed"
    check(ContractCatalog.all()[0].status == &"available",
        "each catalog request returns fresh runtime records")

func _choice(contract: Dictionary, choice_id: StringName) -> Dictionary:
    for choice: Dictionary in contract.complication.choices:
        if choice.id == choice_id:
            return choice
    return {}
```

- [ ] **Step 2: Run the catalog test and verify it fails on the missing authored fields**

Run:

```powershell
rtk powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\run_test.ps1 test_contract_catalog
```

Expected: `test_contract_catalog` fails because D-207/R-311 lack the specified code, travel, condition, feedback, and successor fields.

- [ ] **Step 3: Replace the static catalog contents with the three precise records**

In `data/contracts/contract_catalog.gd`, keep `class_name ContractCatalog`, `extends RefCounted`, and `static func all() -> Array[Dictionary]`. Replace its returned array with the records below. Every `preview`, `result`, ticker, and message string is player-visible authored content.

```gdscript
static func all() -> Array[Dictionary]:
    return [
        {
            "id": &"cold_chain_delivery",
            "code": "C-1042",
            "title": "COLD-CHAIN DELIVERY",
            "client": "Vesper Logistics",
            "reward_credits": 1400,
            "risk": "LOW",
            "destination": "DOCK 17",
            "deadline_day": 15,
            "deadline_minute": 4 * 60,
            "is_playable": true,
            "status": &"available",
            "phase": &"offer",
            "resolution_id": &"",
            "proceed_minutes": 80,
            "proceed_label": "DOCK 17",
            "accept_message": "Keep it cold. Keep it boring.",
            "proceed_message": "Customs is fishing for an excuse.",
            "complication": {
                "title": "CUSTOMS HOLD // DOCK 17",
                "body": "Cold-chain cargo flagged for manual inspection.",
                "choices": [
                    {"id": &"pay_fee", "label": "PAY CLEARANCE FEE // 250 CR", "credit_delta": 1150, "heat_delta": 0, "terminal_status": &"completed", "unlocks_contract_id": &"data_retrieval", "preview": "+1,150 CR // HEAT +0 // CONTRACT COMPLETE", "result": "CLEARANCE PAID // CARGO RELEASED", "ticker": "CONTRACT COMPLETE // +1,150 CR", "message_sender": "MARA", "message_preview": "Paperwork cost less than a seizure."},
                    {"id": &"call_mara", "label": "CALL MARA", "credit_delta": 1400, "heat_delta": 0, "terminal_status": &"completed", "sets_mara_favor_owed": true, "unlocks_contract_id": &"data_retrieval", "preview": "+1,400 CR // HEAT +0 // CONTRACT COMPLETE // MARA FAVOR OWED", "result": "MARA CALLED // FAVOR OWED", "ticker": "CONTRACT COMPLETE // +1,400 CR", "message_sender": "MARA", "message_preview": "You owe me one."},
                    {"id": &"bypass", "label": "BYPASS INSPECTION", "credit_delta": 1400, "heat_delta": 2, "terminal_status": &"completed", "unlocks_contract_id": &"data_retrieval", "preview": "+1,400 CR // HEAT +2 // CONTRACT COMPLETE", "result": "INSPECTION BYPASSED // CAMERAS ALERTED", "ticker": "CONTRACT COMPLETE // +1,400 CR // HEAT +2", "message_sender": "MARA", "message_preview": "The crate moved; so did their cameras."},
                    {"id": &"abort", "label": "ABORT DELIVERY", "credit_delta": 0, "heat_delta": 0, "terminal_status": &"failed", "unlocks_contract_id": &"data_retrieval", "preview": "+0 CR // HEAT +0 // CONTRACT FAILED", "result": "DELIVERY ABORTED // CARGO LOST", "ticker": "CONTRACT FAILED // DELIVERY ABORTED", "message_sender": "MARA", "message_preview": "Walking was cheaper than escalation."},
                ],
            },
        },
        {
            "id": &"data_retrieval",
            "code": "D-207",
            "title": "DATA RETRIEVAL",
            "client": "Northline Systems",
            "reward_credits": 4200,
            "risk": "ELEVATED",
            "destination": "SECTOR 9 // TRANSIT EXCHANGE",
            "deadline_day": 15,
            "deadline_minute": 7 * 60,
            "is_playable": false,
            "status": &"available",
            "phase": &"offer",
            "resolution_id": &"",
            "proceed_minutes": 55,
            "proceed_label": "TRANSIT EXCHANGE",
            "accept_message": "Northline pays for silence. Keep the shard intact.",
            "proceed_message": "The kiosk is live. Corporate audit is already on it.",
            "complication": {
                "title": "REMOTE AUDIT // TRANSIT EXCHANGE",
                "body": "The service kiosk holding the controller shard is under corporate audit.",
                "choices": [
                    {"id": &"spoof_credentials", "label": "SPOOF SERVICE CREDENTIALS", "credit_delta": 4200, "heat_delta": 0, "terminal_status": &"completed", "max_heat": 3, "unlocks_contract_id": &"clinic_asset_recovery", "preview": "+4,200 CR // HEAT +0 // CONTRACT COMPLETE", "result": "CREDENTIALS SPOOFED // SHARD RETRIEVED", "ticker": "CONTRACT COMPLETE // +4,200 CR", "message_sender": "MARA", "message_preview": "Clean work. Northline will not see your name."},
                    {"id": &"buy_token", "label": "BUY CLEAN ACCESS TOKEN // 400 CR", "credit_delta": 3800, "heat_delta": 0, "terminal_status": &"completed", "unlocks_contract_id": &"clinic_asset_recovery", "preview": "+3,800 CR // HEAT +0 // CONTRACT COMPLETE", "result": "AUDITED ACCESS PURCHASED // SHARD RETRIEVED", "ticker": "CONTRACT COMPLETE // +3,800 CR", "message_sender": "MARA", "message_preview": "Expensive, but nobody is looking for you."},
                    {"id": &"force_readout", "label": "FORCE KIOSK READOUT", "credit_delta": 4200, "heat_delta": 1, "terminal_status": &"completed", "unlocks_contract_id": &"clinic_asset_recovery", "preview": "+4,200 CR // HEAT +1 // CONTRACT COMPLETE", "result": "READOUT FORCED // AUDIT RECORDED", "ticker": "CONTRACT COMPLETE // +4,200 CR // HEAT +1", "message_sender": "MARA", "message_preview": "You have the shard. The audit has your silhouette."},
                    {"id": &"routed_vendor_id", "label": "USE ROUTED VENDOR ID // 650 CR", "credit_delta": 3550, "heat_delta": 0, "terminal_status": &"completed", "min_heat": 4, "unlocks_contract_id": &"clinic_asset_recovery", "preview": "+3,550 CR // HEAT +0 // CONTRACT COMPLETE", "result": "VENDOR ID ROUTED // SHARD RETRIEVED", "ticker": "CONTRACT COMPLETE // +3,550 CR", "message_sender": "MARA", "message_preview": "That Heat made quiet expensive. Still beats a second flag."},
                    {"id": &"abort", "label": "ABORT RETRIEVAL", "credit_delta": 0, "heat_delta": 0, "terminal_status": &"failed", "unlocks_contract_id": &"clinic_asset_recovery", "preview": "+0 CR // HEAT +0 // CONTRACT FAILED", "result": "RETRIEVAL ABORTED // SHARD LEFT IN PLACE", "ticker": "CONTRACT FAILED // DATA RETRIEVAL", "message_sender": "MARA", "message_preview": "Leaving clean is better than leaving tagged."},
                ],
            },
        },
        {
            "id": &"clinic_asset_recovery",
            "code": "R-311",
            "title": "CLINIC ASSET RECOVERY",
            "client": "Vesper Community Clinic",
            "reward_credits": 3200,
            "risk": "MODERATE",
            "destination": "LOWER VESPER // MEDICAL SUBLEVEL",
            "deadline_day": 15,
            "deadline_minute": 12 * 60,
            "is_playable": false,
            "status": &"available",
            "phase": &"offer",
            "resolution_id": &"",
            "proceed_minutes": 65,
            "proceed_label": "MEDICAL SUBLEVEL",
            "accept_message": "Clinic work is clean work. Try to leave it that way.",
            "proceed_message": "The diagnostic drone is behind a contractor lock.",
            "complication": {
                "title": "MAINTENANCE LOCK // MEDICAL SUBLEVEL",
                "body": "The diverted diagnostic drone is parked behind contractor security.",
                "choices": [
                    {"id": &"clinic_override", "label": "REQUEST CLINIC OVERRIDE", "credit_delta": 3200, "heat_delta": 0, "terminal_status": &"completed", "preview": "+3,200 CR // HEAT +0 // CONTRACT COMPLETE", "result": "OVERRIDE GRANTED // DRONE RETURNED", "ticker": "CONTRACT COMPLETE // +3,200 CR", "message_sender": "MARA", "message_preview": "Ordinary work still pays. Remember that."},
                    {"id": &"maintenance_bypass", "label": "USE MAINTENANCE BYPASS", "credit_delta": 3500, "heat_delta": 2, "terminal_status": &"completed", "preview": "+3,500 CR // HEAT +2 // CONTRACT COMPLETE", "result": "MAINTENANCE LOCK BYPASSED // DRONE RETURNED", "ticker": "CONTRACT COMPLETE // +3,500 CR // HEAT +2", "message_sender": "MARA", "message_preview": "You got paid. The lock logged the rest."},
                    {"id": &"settle_mara_favor", "label": "SETTLE MARA'S FAVOR // HAND DELIVERY", "credit_delta": 2600, "heat_delta": 0, "terminal_status": &"completed", "requires_mara_favor": true, "clears_mara_favor": true, "preview": "+2,600 CR // HEAT +0 // CONTRACT COMPLETE // FAVOR SETTLED", "result": "HAND DELIVERY COMPLETE // FAVOR SETTLED", "ticker": "CONTRACT COMPLETE // +2,600 CR // FAVOR SETTLED", "message_sender": "MARA", "message_preview": "We are square. Keep the clinic on your good side."},
                    {"id": &"abort", "label": "ABORT RECOVERY", "credit_delta": 0, "heat_delta": 0, "terminal_status": &"failed", "preview": "+0 CR // HEAT +0 // CONTRACT FAILED", "result": "RECOVERY ABORTED // DRONE LEFT IN PLACE", "ticker": "CONTRACT FAILED // ASSET RECOVERY", "message_sender": "MARA", "message_preview": "No drone is worth getting boxed in."},
                ],
            },
        },
    ]
```

- [ ] **Step 4: Run the catalog test and verify every static record passes**

Run:

```powershell
rtk powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\run_test.ps1 test_contract_catalog
```

Expected: `RESULT: ALL PASSED`, including C-1042 successor metadata, locked D-207/R-311 records, exact travel/deadline fields, conditional metadata, and fresh-record behavior.

- [ ] **Step 5: Commit the authored portfolio catalog**

```powershell
rtk git add data/contracts/contract_catalog.gd tests/test_contract_catalog.gd
git commit -m "feat: add early contract portfolio catalog"
```

---

### Task 2: Apply availability, conditions, and generic authored resolution in GameState

**Files:**
- Modify: `autoload/game_state.gd`
- Modify: `tests/test_game_state.gd`

**Interfaces:**
- Consumes: Task 1’s complete catalog record and choice field shapes.
- Produces: filtered `get_contract()` snapshots, validation against visible choices, generic choice feedback, and successor activation without changing the public accept/proceed/resolve intent API.

- [ ] **Step 1: Add failing GameState coverage for all stateful portfolio rules**

Append these helpers and assertions to `tests/test_game_state.gd`. Keep the existing C-1042 outcome coverage; use new fixtures so its assertions remain isolated.

```gdscript
func _resolve_c1042(gs: Node, choice_id: StringName) -> void:
    check(gs.accept_contract(&"cold_chain_delivery"), "C-1042 accept setup succeeds")
    check(gs.proceed_contract(&"cold_chain_delivery"), "C-1042 proceed setup succeeds")
    check(gs.resolve_contract(&"cold_chain_delivery", choice_id), "C-1042 resolution setup succeeds")

func _at_data_customs(gs: Node, c1042_choice: StringName) -> void:
    _resolve_c1042(gs, c1042_choice)
    check(gs.accept_contract(&"data_retrieval"), "D-207 accept setup succeeds")
    check(gs.proceed_contract(&"data_retrieval"), "D-207 proceed setup succeeds")

func _choice_ids(contract: Dictionary) -> Array[StringName]:
    var ids: Array[StringName] = []
    for choice: Dictionary in contract.complication.choices:
        ids.append(choice.id)
    return ids
```

Add these blocks at the end of `_run()` before the final `gs.free()`:

```gdscript
var locked_gs := GameStateScript.new()
check(not locked_gs.get_contract(&"data_retrieval").is_playable
    and not locked_gs.get_contract(&"clinic_asset_recovery").is_playable,
    "only C-1042 is playable in fresh state")
check(not locked_gs.accept_contract(&"data_retrieval"), "locked D-207 cannot be accepted")
locked_gs.free()

var failure_unlock_gs := GameStateScript.new()
_resolve_c1042(failure_unlock_gs, &"abort")
check(failure_unlock_gs.get_contract(&"data_retrieval").is_playable,
    "failed C-1042 still unlocks D-207")
_at_data_customs(failure_unlock_gs, &"abort")
check(failure_unlock_gs.resolve_contract(&"data_retrieval", &"abort"), "D-207 abort resolves")
check(failure_unlock_gs.get_contract(&"clinic_asset_recovery").is_playable,
    "failed D-207 still unlocks R-311")
failure_unlock_gs.free()

var low_heat_gs := GameStateScript.new()
_at_data_customs(low_heat_gs, &"pay_fee")
var low_heat_ids := _choice_ids(low_heat_gs.get_contract(&"data_retrieval"))
check(low_heat_ids.has(&"spoof_credentials") and not low_heat_ids.has(&"routed_vendor_id"),
    "Heat below four exposes spoof credentials only")
check(low_heat_gs.resolve_contract(&"data_retrieval", &"spoof_credentials"),
    "low-Heat spoof resolves")
check(low_heat_gs.credits == low_heat_gs.START_CREDITS + 1150 + 4200 and low_heat_gs.heat == 2,
    "spoof awards full data reward without Heat")
check(low_heat_gs.get_contract(&"clinic_asset_recovery").is_playable,
    "D-207 completion unlocks R-311")
low_heat_gs.free()

var high_heat_gs := GameStateScript.new()
_at_data_customs(high_heat_gs, &"bypass")
var high_heat_ids := _choice_ids(high_heat_gs.get_contract(&"data_retrieval"))
check(not high_heat_ids.has(&"spoof_credentials") and high_heat_ids.has(&"routed_vendor_id"),
    "Heat four replaces spoof credentials with routed vendor ID")
var high_heat_credits := high_heat_gs.credits
check(not high_heat_gs.resolve_contract(&"data_retrieval", &"spoof_credentials"),
    "hidden spoof credential choice is rejected")
check(high_heat_gs.credits == high_heat_credits and high_heat_gs.active_contract_id == &"data_retrieval",
    "hidden choice rejection does not mutate state")
check(high_heat_gs.resolve_contract(&"data_retrieval", &"routed_vendor_id"),
    "routed vendor ID resolves at Heat four")
check(high_heat_gs.credits == high_heat_gs.START_CREDITS + 1400 + 3550 and high_heat_gs.heat == 4,
    "routed vendor ID pays its authored reduced reward without new Heat")
high_heat_gs.free()

var mara_gs := GameStateScript.new()
_at_data_customs(mara_gs, &"call_mara")
check(mara_gs.resolve_contract(&"data_retrieval", &"buy_token"), "Mara setup resolves D-207")
check(mara_gs.accept_contract(&"clinic_asset_recovery"), "R-311 accepts after D-207")
check(mara_gs.proceed_contract(&"clinic_asset_recovery"), "R-311 proceeds")
var recovery_ids := _choice_ids(mara_gs.get_contract(&"clinic_asset_recovery"))
check(recovery_ids.has(&"settle_mara_favor"), "R-311 exposes favor settlement when owed")
check(mara_gs.resolve_contract(&"clinic_asset_recovery", &"settle_mara_favor"),
    "favor settlement resolves")
check(not mara_gs.mara_favor_owed
    and mara_gs.credits == mara_gs.START_CREDITS + 1400 + 3800 + 2600,
    "favor settlement clears the flag and applies its lower reward")
mara_gs.free()

var no_favor_gs := GameStateScript.new()
_at_data_customs(no_favor_gs, &"pay_fee")
check(no_favor_gs.resolve_contract(&"data_retrieval", &"buy_token"), "no-favor setup resolves D-207")
check(no_favor_gs.accept_contract(&"clinic_asset_recovery"), "no-favor R-311 accepts")
check(no_favor_gs.proceed_contract(&"clinic_asset_recovery"), "no-favor R-311 proceeds")
check(not _choice_ids(no_favor_gs.get_contract(&"clinic_asset_recovery")).has(&"settle_mara_favor"),
    "R-311 hides settlement when no favor is owed")
check(not no_favor_gs.resolve_contract(&"clinic_asset_recovery", &"settle_mara_favor"),
    "hidden favor settlement is rejected")
no_favor_gs.free()
```

- [ ] **Step 2: Run the focused test and verify the new portfolio assertions fail**

Run:

```powershell
rtk powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\run_test.ps1 test_game_state
```

Expected: existing C-1042 assertions pass; the new assertions fail because D-207/R-311 cannot yet unlock, conditions are not filtered, and feedback still depends on C-1042’s hard-coded choice IDs.

- [ ] **Step 3: Filter choice snapshots and validate the same set on resolution**

In `autoload/game_state.gd`, replace the existing `get_contract()` and `_choice()` helpers with these implementations. They keep mutable catalog records private and make hidden choices invalid as well as invisible.

```gdscript
func get_contract(id: StringName) -> Dictionary:
    var index := _contract_index(id)
    if index < 0:
        return {}
    var snapshot: Dictionary = contracts[index].duplicate(true)
    if snapshot.has("complication"):
        snapshot.complication.choices = _available_choices(contracts[index])
    return snapshot

func _available_choices(contract: Dictionary) -> Array[Dictionary]:
    var available: Array[Dictionary] = []
    if not contract.has("complication"):
        return available
    for choice: Dictionary in contract.complication.choices:
        if choice.has("max_heat") and heat > int(choice.max_heat):
            continue
        if choice.has("min_heat") and heat < int(choice.min_heat):
            continue
        if choice.get("requires_mara_favor", false) and not mara_favor_owed:
            continue
        available.append(choice)
    return available

func _choice(choices: Array[Dictionary], choice_id: StringName) -> Dictionary:
    for choice: Dictionary in choices:
        if choice.id == choice_id:
            return choice
    return {}
```

In `resolve_contract()`, replace the current choice lookup with:

```gdscript
var choice := _choice(_available_choices(contract), choice_id)
```

- [ ] **Step 4: Generalize authored feedback, favor cleanup, and successor activation**

In `accept_contract()` and `proceed_contract()`, retain existing state transitions and direct acceptance ticker, but use per-contract messages and the authored complication title:

```gdscript
push_ticker("CONTRACT ACCEPTED // " + contract.code, true)
add_message("MARA", contract.accept_message)
```

```gdscript
advance_minutes(contract.proceed_minutes)
contract.phase = &"customs_hold"
contracts_changed.emit()
push_ticker(contract.complication.title, true)
add_message("MARA", contract.proceed_message)
```

In `resolve_contract()`, retain Credits/Heat application and add the clear/unlock operations before terminal-state assignment:

```gdscript
if choice.get("sets_mara_favor_owed", false):
    mara_favor_owed = true
if choice.get("clears_mara_favor", false):
    mara_favor_owed = false
_unlock_contract(choice.get("unlocks_contract_id", &""))
```

Add the helper below `resolve_contract()`:

```gdscript
func _unlock_contract(id: StringName) -> void:
    if id == &"":
        return
    var index := _contract_index(id)
    if index >= 0:
        contracts[index].is_playable = true
```

Replace `_push_resolution_feedback(choice_id: StringName)` with this authored-record version and call it as `_push_resolution_feedback(choice)`:

```gdscript
func _push_resolution_feedback(choice: Dictionary) -> void:
    push_ticker(choice.ticker, true)
    add_message(choice.message_sender, choice.message_preview)
```

Do not add a fallback message path. Task 1 makes the seven C-1042/D-207/R-311 terminal choice records complete; missing catalog fields should fail visibly in development rather than silently inventing player text.

- [ ] **Step 5: Run the GameState contract suite and verify all portfolio rules**

Run:

```powershell
rtk powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\run_test.ps1 test_game_state
```

Expected: `RESULT: ALL PASSED`, including failure-path unlocks, exact reward/Heat effects, mutually exclusive Data Retrieval identity options, hidden-choice rejection without mutation, and favor settlement cleanup.

- [ ] **Step 6: Commit the GameState portfolio rules**

```powershell
rtk git add autoload/game_state.gd tests/test_game_state.gd
git commit -m "feat: add contract portfolio progression"
```

---

### Task 3: Render dynamic travel and conditional choice snapshots

**Files:**
- Modify: `scenes/modules/contracts/contract_detail.gd`
- Modify: `tests/test_contracts.gd`

**Interfaces:**
- Consumes: `GameState.get_contract()` snapshots from Task 2, whose `complication.choices` list contains only valid current choices, and the new `proceed_label` field.
- Produces: contract-specific Proceed action text and a UI contract proving that only filtered choices are shown and emitted.

- [ ] **Step 1: Add failing Contract Detail assertions for D-207 and R-311**

In `tests/test_contracts.gd`, add a second state fixture after the existing C-1042 detail assertions. It must enter valid states through `GameState`, then assert the controls rendered from snapshots:

```gdscript
var portfolio_gs := GameStateScript.new()
check(portfolio_gs.accept_contract(&"cold_chain_delivery"), "portfolio setup accepts C-1042")
check(portfolio_gs.proceed_contract(&"cold_chain_delivery"), "portfolio setup proceeds C-1042")
check(portfolio_gs.resolve_contract(&"cold_chain_delivery", &"bypass"), "portfolio setup bypasses C-1042")
check(portfolio_gs.accept_contract(&"data_retrieval"), "portfolio setup accepts D-207")
var data_ready := portfolio_gs.get_contract(&"data_retrieval")
detail.setup(portfolio_gs, data_ready)
check(_button(detail, "PROCEED TO TRANSIT EXCHANGE") != null,
    "D-207 uses its authored proceed label")
check(_button(detail, "PROCEED TO DOCK 17") == null,
    "D-207 does not use C-1042's hard-coded proceed label")
check(portfolio_gs.proceed_contract(&"data_retrieval"), "portfolio setup proceeds D-207")
var high_heat_data := portfolio_gs.get_contract(&"data_retrieval")
detail.setup(portfolio_gs, high_heat_data)
check(_button(detail, "USE ROUTED VENDOR ID // 650 CR") != null,
    "high-Heat D-207 renders routed vendor ID")
check(_button(detail, "SPOOF SERVICE CREDENTIALS") == null,
    "high-Heat D-207 hides spoof credentials")

var favor_gs := GameStateScript.new()
check(favor_gs.accept_contract(&"cold_chain_delivery"), "favor setup accepts C-1042")
check(favor_gs.proceed_contract(&"cold_chain_delivery"), "favor setup proceeds C-1042")
check(favor_gs.resolve_contract(&"cold_chain_delivery", &"call_mara"), "favor setup calls Mara")
check(favor_gs.accept_contract(&"data_retrieval"), "favor setup accepts D-207")
check(favor_gs.proceed_contract(&"data_retrieval"), "favor setup proceeds D-207")
check(favor_gs.resolve_contract(&"data_retrieval", &"buy_token"), "favor setup resolves D-207")
check(favor_gs.accept_contract(&"clinic_asset_recovery"), "favor setup accepts R-311")
var recovery_ready := favor_gs.get_contract(&"clinic_asset_recovery")
detail.setup(favor_gs, recovery_ready)
check(_button(detail, "PROCEED TO MEDICAL SUBLEVEL") != null,
    "R-311 uses its authored proceed label")
check(favor_gs.proceed_contract(&"clinic_asset_recovery"), "favor setup proceeds R-311")
detail.setup(favor_gs, favor_gs.get_contract(&"clinic_asset_recovery"))
check(_button(detail, "SETTLE MARA'S FAVOR // HAND DELIVERY") != null,
    "favor-owed R-311 renders the settlement action")
portfolio_gs.free()
favor_gs.free()
```

Place it before the existing final `detail.queue_free()`. Do not emit these buttons: Task 2 already proves resolver effects; this task proves detail rendering only.

- [ ] **Step 2: Run the Contract UI test and verify it fails on the hard-coded action label**

Run:

```powershell
rtk powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\run_test.ps1 test_contracts
```

Expected: the dynamic filtered-choice assertions pass after Task 2, but the test fails because Contract Detail still renders `PROCEED TO DOCK 17` for every active contract.

- [ ] **Step 3: Render the catalog-provided proceed label**

In `_render_ready(c: Dictionary)` in `scenes/modules/contracts/contract_detail.gd`, replace:

```gdscript
_add_action("PROCEED TO DOCK 17", func() -> void: proceed_requested.emit(_contract_id))
```

with:

```gdscript
_add_action("PROCEED TO " + c.proceed_label,
    func() -> void: proceed_requested.emit(_contract_id))
```

Do not add conditional rendering to Contract Detail. `GameState.get_contract()` supplies the already filtered `complication.choices` snapshot, and the existing loop must remain a renderer of that list.

- [ ] **Step 4: Run the Contract UI test and verify all detail phases pass**

Run:

```powershell
rtk powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\run_test.ps1 test_contracts
```

Expected: `RESULT: ALL PASSED`, including C-1042 regression assertions, D-207/R-311 dynamic Proceed labels, and Heat/Mara-filtered action visibility.

- [ ] **Step 5: Commit dynamic Contract Detail rendering**

```powershell
rtk git add scenes/modules/contracts/contract_detail.gd tests/test_contracts.gd
git commit -m "feat: render conditional contract choices"
```

---

### Task 4: Verify sequential contract progression through Main

**Files:**
- Modify: `tests/test_main.gd`

**Interfaces:**
- Consumes: Task 2’s `contracts_changed` emissions after terminal resolution and Task 3’s dynamic action text.
- Produces: integration proof that Main requires no new production coordination code: the existing refresh connection updates Contract Network and adjacent detail across the portfolio.

- [ ] **Step 1: Extend the existing Main contract flow with sequential unlock checks**

In `tests/test_main.gd`, immediately after the existing C-1042 Abort/Acknowledge assertions, add this end-to-end failure-path progression. It uses failures deliberately to prove the portfolio cannot dead-end:

```gdscript
var d207_row := _button(primary, "DATA RETRIEVAL   4,200 CR")
check(d207_row != null and not d207_row.disabled,
    "C-1042 resolution enables D-207 in the refreshed network")
d207_row.pressed.emit()
check(_button(context, "ACCEPT") != null, "D-207 opens its offer detail")
_button(context, "ACCEPT").pressed.emit()
check(_button(context, "PROCEED TO TRANSIT EXCHANGE") != null,
    "D-207 accept renders its destination action")
_button(context, "PROCEED TO TRANSIT EXCHANGE").pressed.emit()
check(_button(context, "ABORT RETRIEVAL") != null,
    "D-207 proceed renders its authored interruption")
_button(context, "ABORT RETRIEVAL").pressed.emit()
check(_button(primary, "FAILED // DATA RETRIEVAL") != null,
    "D-207 failure refreshes its terminal network row")
_button(context, "ACKNOWLEDGE").pressed.emit()

var r311_row := _button(primary, "CLINIC ASSET RECOVERY   3,200 CR")
check(r311_row != null and not r311_row.disabled,
    "D-207 resolution enables R-311 despite failure")
r311_row.pressed.emit()
_button(context, "ACCEPT").pressed.emit()
check(_button(context, "PROCEED TO MEDICAL SUBLEVEL") != null,
    "R-311 accepts and uses its destination action")
_button(context, "PROCEED TO MEDICAL SUBLEVEL").pressed.emit()
check(_button(context, "ABORT RECOVERY") != null,
    "R-311 proceed renders its authored interruption")
_button(context, "ABORT RECOVERY").pressed.emit()
check(_button(primary, "FAILED // CLINIC ASSET RECOVERY") != null,
    "R-311 resolution refreshes its terminal network row")
_button(context, "ACKNOWLEDGE").pressed.emit()
check(context.get_child_count() == 0 and primary.visible,
    "final acknowledgement closes only detail and leaves the network open")
```

The existing earlier C-1042 abort path remains intact. Do not change `main.gd`: it already receives `contracts_changed`, rebuilds the primary contract panel, and re-renders a selected detail snapshot.

- [ ] **Step 2: Run the Main integration test against the completed portfolio**

Run:

```powershell
rtk powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\run_test.ps1 test_main
```

Expected: `RESULT: ALL PASSED`; the preceding catalog and GameState tasks provide all new behavior, so `main.gd` requires no production change. The test proves sequential terminal refresh, destination-specific travel actions, failure-path unlocking, terminal row presentation, and persistent Contract Network layout.

- [ ] **Step 3: Commit Main integration coverage**

```powershell
rtk git add tests/test_main.gd
git commit -m "test: cover contract portfolio workspace flow"
```

---

### Task 5: Update project status and perform final verification

**Files:**
- Modify: `README.md`
- Verify: `data/contracts/contract_catalog.gd`
- Verify: `autoload/game_state.gd`
- Verify: `scenes/modules/contracts/contract_detail.gd`
- Verify: `tests/test_contract_catalog.gd`
- Verify: `tests/test_game_state.gd`
- Verify: `tests/test_contracts.gd`
- Verify: `tests/test_main.gd`

**Interfaces:**
- Consumes: Complete authored portfolio and all focused regression coverage from Tasks 1–4.
- Produces: Accurate project documentation, passing headless suite, and manual player-visible proof of both cross-contract conditions.

- [ ] **Step 1: Update README status and active-slice description**

In `README.md`, replace the current status sentence with:

```markdown
> **Status:** early prototype. The current build contains the navigable operations-terminal shell, a Tier 1 apartment environment, and a deterministic three-contract early-game portfolio. It has no persistent save, simulation, combat, or procedural content systems.
```

Replace the broken `context.md` link under “See the design documents” with these two current docs, retaining the terminal-shell links:

```markdown
- [`docs/superpowers/specs/2026-08-26-first-contract-vertical-slice-design.md`](docs/superpowers/specs/2026-08-26-first-contract-vertical-slice-design.md) — first playable contract slice
- [`docs/superpowers/specs/2026-08-28-early-contract-portfolio-design.md`](docs/superpowers/specs/2026-08-28-early-contract-portfolio-design.md) — three-contract early-game portfolio
```

Update the architecture note so it says contract content lives in `data/contracts/contract_catalog.gd`, with mutable state in `GameState`; do not claim that contract data remains placeholder-only.

- [ ] **Step 2: Run focused portfolio regressions**

Run:

```powershell
rtk powershell -NoProfile -Command "\$tests = 'test_contract_catalog','test_game_state','test_contracts','test_main'; foreach (\$test in \$tests) { & .\tests\run_test.ps1 \$test; if (\$LASTEXITCODE -ne 0) { exit \$LASTEXITCODE } }"
```

Expected: every test prints `RESULT: ALL PASSED`.

- [ ] **Step 3: Run the complete headless suite**

Run:

```powershell
rtk powershell -NoProfile -Command "\$tests = 'test_smoke','test_game_state','test_module_registry','test_theme','test_contract_catalog','test_status_chip','test_icon_rail','test_ticker_bar','test_panels_basic','test_contracts','test_main','test_environment'; foreach (\$test in \$tests) { & .\tests\run_test.ps1 \$test; if (\$LASTEXITCODE -ne 0) { exit \$LASTEXITCODE } }"
```

Expected: every test prints `RESULT: ALL PASSED`.

- [ ] **Step 4: Smoke-test the two cross-contract player paths**

Launch the game:

```powershell
rtk powershell -NoProfile -Command "& 'C:\Users\merli\Documents\Godot Projects\Godot_v4.7.1-stable_win64_console.exe' --path ."
```

Run these fresh-launch paths:

1. **Heat path:** C-1042 → Bypass Inspection → D-207. Verify D-207 presents `USE ROUTED VENDOR ID // 650 CR`, does not present `SPOOF SERVICE CREDENTIALS`, resolves for `+3,550 CR` and no additional Heat, and unlocks R-311.
2. **Mara path:** C-1042 → Call Mara → D-207 → Buy Clean Access Token → R-311. Verify R-311 presents `SETTLE MARA'S FAVOR // HAND DELIVERY`, resolves for `+2,600 CR`, clears the favor, and announces the authored result in ticker and Comms.

For both paths, verify Contract Detail remains beside Contract Network; each resolution disables the terminal row; Acknowledge closes only detail; no full-screen interface, layout regression, or interaction error occurs.

- [ ] **Step 5: Commit documentation and final verification state**

```powershell
rtk git add README.md
git commit -m "docs: describe early contract portfolio"
```

## Plan Self-Review

- **Spec coverage:** Task 1 implements exact C-1042/D-207/R-311 content, linear availability, metadata, and authored feedback. Task 2 implements success/failure unlocks, Heat substitution, Mara settlement, shared snapshot/validation rules, and GameState ownership. Task 3 covers dynamic UI action labels and filtered choice rendering. Task 4 protects the unchanged Main workspace integration. Task 5 updates stale project documentation, runs focused/full suites, and manually verifies both player-visible cross-contract paths.
- **Placeholder scan:** No unfilled work markers, deferred implementation language, unspecified tests, or unspecified error handling remains.
- **Type consistency:** All catalog IDs are `cold_chain_delivery`, `data_retrieval`, and `clinic_asset_recovery`; condition fields are `max_heat`, `min_heat`, `requires_mara_favor`, and `clears_mara_favor`; both snapshot rendering and resolver validation call `_available_choices(contract)`; all UI code uses the established `StringName` contract IDs and intent signals.
