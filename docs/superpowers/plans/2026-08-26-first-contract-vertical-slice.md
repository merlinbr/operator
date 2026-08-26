# First Contract Vertical Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn Contract Network into one complete deterministic C-1042 cold-chain delivery loop that changes time, Credits, Heat, messages, and ticker feedback within the existing floating workspace.

**Architecture:** `GameState` owns one mutable array of contract records, one active-contract ID, the one-bit `mara_favor_owed` consequence, and mutable Comms messages. A static Dictionary catalog supplies fresh initial records. Contract UI only renders record state and emits intent; `Main` owns transient selection plus workspace/detail coordination, then forwards intent to `GameState`.

**Tech Stack:** Godot 4.7.1, GDScript, existing native Godot `Control` nodes, and the repository's minimal headless `SceneTree` tests.

## Global Constraints

- Implement only `C-1042 // COLD-CHAIN DELIVERY`; retain the other two catalog rows as visibly disabled unavailable offers.
- The offer deadline is exactly `DAY 15 // 04:00`.
- `PROCEED TO DOCK 17` advances exactly 80 minutes: Day 14 // 23:41 becomes Day 15 // 01:01.
- Contract statuses are only `available`, `active`, `completed`, and `failed`; do not create `declined`, cancelled, expired, paused, or abandoned status.
- Offer and active detail uses `CLOSE`, not Decline. Close changes no contract state.
- Customs choices are deterministic: Pay fee `+1,150 CR/+0 Heat`, Call Mara `+1,400 CR/+0 Heat/mara_favor_owed`, Bypass `+1,400 CR/+2 Heat`, Abort `failed/+0 CR/+0 Heat`.
- `mara_favor_owed` is one explicit `bool` in `GameState`; do not add a favor, contact, reputation, debt, or relationship system.
- Use the existing adjacent `ContextHost`; no full-screen panel, modal, custom autoload, manager, Resource hierarchy, RNG, real-time timer, event graph, or quest engine.
- Preserve dependency injection/headless construction: components receive `GameState` through `setup()` and never access the autoload singleton by name.
- Follow existing programmatic scene construction and `Dictionary` content conventions. Add no dependency.
- Prefix every shell command with `rtk`.

---

## File Map

| File | Responsibility after this plan |
|---|---|
| `data/contracts/contract_catalog.gd` | New static source of fresh C-1042 and disabled-offer dictionaries. No mutable global state. |
| `autoload/game_state.gd` | Runtime contract/message collections, contract transitions, Credits/Heat/time effects, ticker/message signals, Mara boolean. |
| `scenes/modules/contracts/contracts_panel.gd` | Contract Network row text, status treatment, disabled unavailable/terminal rows, ID-only selection signal. |
| `scenes/modules/contracts/contract_detail.gd` | Offer/active/Customs/resolved rendering and intent-only buttons/signals. |
| `scenes/main/main.gd` | GameState data injection, transient selected contract ID, panel wiring and refresh. |
| `tests/test_contract_catalog.gd` | Static catalog data and fresh-copy behavior. |
| `tests/test_game_state.gd` | State-machine transition and effect contracts. |
| `tests/test_contracts.gd` | Network and detail UI rendering/intent contracts. |
| `tests/test_main.gd` | Adjacent-panel wiring and Close/Acknowledge behavior. |
| `tests/test_panels_basic.gd` | Comms setup from `GameState.messages`. |
| `data/placeholder/placeholder_contracts.gd` | Deleted after every caller uses the catalog/GameState path. |
| `data/placeholder/placeholder_messages.gd` | Deleted after GameState directly owns the initial message records. |
| `tests/test_placeholder_data.gd` | Deleted after catalog coverage replaces shell-placeholder coverage. |

---

### Task 1: Add the static contract catalog

**Files:**
- Create: `data/contracts/contract_catalog.gd`
- Create: `tests/test_contract_catalog.gd`

**Interfaces:**
- Consumes: Existing GDScript `RefCounted` static-data pattern used by `PlaceholderContracts`.
- Produces: `ContractCatalog.all() -> Array[Dictionary]`, returning a new three-record array on every call. Every record supplies `id`, `title`, `client`, `reward_credits`, `risk`, `destination`, `deadline_day`, `deadline_minute`, `is_playable`, `status`, `phase`, and `resolution_id`. C-1042 additionally supplies `code`, `proceed_minutes`, and `complication.choices`.

- [ ] **Step 1: Create the failing catalog test**

Create `tests/test_contract_catalog.gd`:

```gdscript
extends "res://tests/test_base.gd"

const ContractCatalog := preload("res://data/contracts/contract_catalog.gd")

func _run() -> void:
	var contracts := ContractCatalog.all()
	check(contracts.size() == 3, "catalog has C-1042 plus two unavailable offers")

	var delivery: Dictionary = contracts[0]
	check(delivery.id == &"cold_chain_delivery", "first contract is cold-chain delivery")
	check(delivery.code == "C-1042", "delivery has operator-facing code")
	check(delivery.deadline_day == 15 and delivery.deadline_minute == 240,
		"deadline is Day 15 at 04:00")
	check(delivery.proceed_minutes == 80, "proceed duration is exactly 80 minutes")
	check(delivery.is_playable and delivery.status == &"available" and delivery.phase == &"offer",
		"delivery starts playable and available")
	check(delivery.complication.choices.size() == 4, "delivery has four deterministic Customs choices")

	check(not contracts[1].is_playable and not contracts[2].is_playable,
		"other catalog offers start unavailable")
	contracts[0].status = &"completed"
	check(ContractCatalog.all()[0].status == &"available",
		"each catalog request returns fresh runtime records")
```

- [ ] **Step 2: Run the catalog test and confirm it fails before the catalog exists**

Run:

```powershell
rtk powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\run_test.ps1 test_contract_catalog
```

Expected: Godot fails to preload `res://data/contracts/contract_catalog.gd` because the catalog has not been created.

- [ ] **Step 3: Commit the failing catalog contract**

```powershell
rtk git add tests/test_contract_catalog.gd
rtk git commit -m "test: specify first contract catalog"
```

- [ ] **Step 4: Create `ContractCatalog` with fresh dictionaries**

Create `data/contracts/contract_catalog.gd` with a single static provider:

```gdscript
class_name ContractCatalog
extends RefCounted

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
	"complication": {
		"title": "CUSTOMS HOLD // DOCK 17",
		"body": "Cold-chain cargo flagged for manual inspection.",
		"choices": [
			{
				"id": &"pay_fee", "label": "PAY CLEARANCE FEE // 250 CR",
				"credit_delta": 1150, "heat_delta": 0, "terminal_status": &"completed",
			},
			{
				"id": &"call_mara", "label": "CALL MARA",
				"credit_delta": 1400, "heat_delta": 0, "terminal_status": &"completed",
				"sets_mara_favor_owed": true,
			},
			{
				"id": &"bypass", "label": "BYPASS INSPECTION",
				"credit_delta": 1400, "heat_delta": 2, "terminal_status": &"completed",
			},
			{
				"id": &"abort", "label": "ABORT DELIVERY",
				"credit_delta": 0, "heat_delta": 0, "terminal_status": &"failed",
			},
		],
	},
		},
	]
```

Add two smaller records retaining the current Data Retrieval and encrypted-offer presentation data, but set `is_playable` to `false`, `status` to `&"available"`, `phase` to `&"offer"`, and `resolution_id` to `&""`. Do not give either a complication or an accept path.

- [ ] **Step 5: Run the catalog test and confirm it passes**

Run:

```powershell
rtk powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\run_test.ps1 test_contract_catalog
```

Expected: `RESULT: ALL PASSED`, including the exact deadline, 80-minute duration, four choices, unavailable offers, and fresh-record assertion.

- [ ] **Step 6: Commit the catalog implementation**

```powershell
rtk git add data/contracts/contract_catalog.gd tests/test_contract_catalog.gd
rtk git commit -m "feat: add cold-chain contract catalog"
```

---

### Task 2: Give GameState available/active/proceed transitions

**Files:**
- Modify: `autoload/game_state.gd`
- Modify: `tests/test_game_state.gd`

**Interfaces:**
- Consumes: `ContractCatalog.all()` from Task 1 and existing `advance_minutes`, `push_ticker`, Credits, Heat, and clock signals.
- Produces: `contracts`, `active_contract_id`, `contracts_changed`, `get_contract(id) -> Dictionary`, `accept_contract(id) -> bool`, and `proceed_contract(id) -> bool`.

- [ ] **Step 1: Add failing available/active/proceed assertions using a dedicated state fixture**

In `tests/test_game_state.gd`, create a second fresh `GameStateScript` instance after the existing basic-state assertions so existing clock tests keep their current setup. Add:

```gdscript
	var contract_gs := GameStateScript.new()
	var delivery: Dictionary = contract_gs.get_contract(&"cold_chain_delivery")
	check(delivery.status == &"available" and delivery.phase == &"offer",
		"C-1042 starts available in offer phase")
	check(contract_gs.active_contract_id == &"", "no active contract at start")
	check(not contract_gs.proceed_contract(&"cold_chain_delivery"),
		"cannot proceed before accepting")
	check(contract_gs.accept_contract(&"cold_chain_delivery"), "accepting C-1042 succeeds")
	check(contract_gs.active_contract_id == &"cold_chain_delivery", "accepted contract becomes active")
	check(contract_gs.get_contract(&"cold_chain_delivery").phase == &"ready_to_proceed",
		"accepted contract is ready to proceed")
	check(contract_gs.proceed_contract(&"cold_chain_delivery"), "proceeding active C-1042 succeeds")
	check(contract_gs.day == 15 and contract_gs.clock_text() == "01:01",
		"proceed advances exactly 80 minutes across midnight")
	check(contract_gs.get_contract(&"cold_chain_delivery").phase == &"customs_hold",
		"proceed exposes the Customs hold")
	contract_gs.free()
```

- [ ] **Step 2: Run the GameState test and confirm the new contract assertions fail**

Run:

```powershell
rtk powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\run_test.ps1 test_game_state
```

Expected: existing GameState checks pass; the new test fails because the contract API and state fields do not exist.

- [ ] **Step 3: Commit the failing transition contract**

```powershell
rtk git add tests/test_game_state.gd
rtk git commit -m "test: specify contract acceptance flow"
```

- [ ] **Step 4: Add GameState contract collection and lookup**

At the top of `autoload/game_state.gd`, preload the Task 1 catalog and declare:

```gdscript
const ContractCatalog := preload("res://data/contracts/contract_catalog.gd")

signal contracts_changed

var contracts: Array[Dictionary] = ContractCatalog.all()
var active_contract_id: StringName = &""
```

Add these helpers below `advance_minutes`:

```gdscript
func _contract_index(id: StringName) -> int:
	for index in contracts.size():
		if contracts[index].id == id:
			return index
	return -1

func get_contract(id: StringName) -> Dictionary:
	var index := _contract_index(id)
	return {} if index < 0 else contracts[index].duplicate(true)
```

Returning a deep duplicate prevents UI/tests from mutating GameState's owned record.

- [ ] **Step 5: Add `accept_contract` with single-active validation**

Add:

```gdscript
func accept_contract(id: StringName) -> bool:
	var index := _contract_index(id)
	if index < 0 or active_contract_id != &"":
		return false
	var contract: Dictionary = contracts[index]
	if not contract.is_playable or contract.status != &"available" or contract.phase != &"offer":
		return false
	contract.status = &"active"
	contract.phase = &"ready_to_proceed"
	active_contract_id = id
	contracts_changed.emit()
	push_ticker("CONTRACT ACCEPTED // " + contract.code, true)
	return true
```

Do not advance time, alter Credits/Heat, or add a second active contract in this method. Task 3 adds its required Mara feedback only after `messages` and `add_message` exist.

- [ ] **Step 6: Add `proceed_contract` with the exact rollover**

Add:

```gdscript
func proceed_contract(id: StringName) -> bool:
	var index := _contract_index(id)
	if index < 0 or active_contract_id != id:
		return false
	var contract: Dictionary = contracts[index]
	if contract.status != &"active" or contract.phase != &"ready_to_proceed":
		return false
	advance_minutes(contract.proceed_minutes)
	contract.phase = &"customs_hold"
	contracts_changed.emit()
	push_ticker("CUSTOMS HOLD // " + contract.destination, true)
	return true
```

The catalog's `proceed_minutes == 80` is the only source of travel duration. Do not calculate travel from deadline, use a timer, or add a time-control UI.

- [ ] **Step 7: Run the focused GameState test and confirm it passes**

Run:

```powershell
rtk powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\run_test.ps1 test_game_state
```

Expected: `RESULT: ALL PASSED`, including refusal before acceptance and Day 14 // 23:41 → Day 15 // 01:01.

- [ ] **Step 8: Commit the available/active/proceed implementation**

```powershell
rtk git add autoload/game_state.gd tests/test_game_state.gd
rtk git commit -m "feat: add contract acceptance progression"
```

---

### Task 3: Add terminal outcomes and minimal Mara messages

**Files:**
- Modify: `autoload/game_state.gd`
- Modify: `tests/test_game_state.gd`

**Interfaces:**
- Consumes: Task 2's active `customs_hold` record and existing `credits_changed`, `heat_changed`, and `ticker_message` behavior.
- Produces: `mara_favor_owed`, `messages`, `messages_changed`, `add_message(sender, preview)`, and `resolve_contract(id, choice_id) -> bool`.

- [ ] **Step 1: Add failing resolution and message assertions**

Add a helper to `tests/test_game_state.gd`:

func _at_customs() -> Variant:
	var gs := GameStateScript.new()
	check(gs.accept_contract(&"cold_chain_delivery"), "accept setup succeeds")
	check(gs.proceed_contract(&"cold_chain_delivery"), "proceed setup succeeds")
	return gs
```

Then append one fresh fixture per outcome:

```gdscript
	var fee_gs := _at_customs()
	check(fee_gs.resolve_contract(&"cold_chain_delivery", &"pay_fee"), "fee resolves")
	check(fee_gs.credits == fee_gs.START_CREDITS + 1150, "fee awards net 1,150 CR")
	check(fee_gs.heat == 2, "fee preserves Heat")
	check(fee_gs.get_contract(&"cold_chain_delivery").status == &"completed", "fee completes contract")
	fee_gs.free()

	var mara_gs := _at_customs()
	check(mara_gs.resolve_contract(&"cold_chain_delivery", &"call_mara"), "Mara resolves")
	check(mara_gs.credits == mara_gs.START_CREDITS + 1400, "Mara awards full payout")
	check(mara_gs.heat == 2 and mara_gs.mara_favor_owed, "Mara creates only the favor boolean")
	check(mara_gs.messages.any(func(message: Dictionary) -> bool: return message.sender == "MARA"),
		"Mara resolution records a Comms message")
	mara_gs.free()

	var bypass_gs := _at_customs()
	check(bypass_gs.resolve_contract(&"cold_chain_delivery", &"bypass"), "bypass resolves")
	check(bypass_gs.credits == bypass_gs.START_CREDITS + 1400 and bypass_gs.heat == 4,
		"bypass trades Heat for full payout")
	bypass_gs.free()

	var abort_gs := _at_customs()
	check(abort_gs.resolve_contract(&"cold_chain_delivery", &"abort"), "abort resolves")
	check(abort_gs.credits == abort_gs.START_CREDITS and abort_gs.heat == 2,
		"abort changes neither Credits nor Heat")
	check(abort_gs.get_contract(&"cold_chain_delivery").status == &"failed", "abort fails contract")
	abort_gs.free()
```

Also assert that resolving before Customs returns false and leaves `active_contract_id` unchanged.

- [ ] **Step 2: Run the GameState test and confirm new resolution assertions fail**

Run:

```powershell
rtk powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\run_test.ps1 test_game_state
```

Expected: existing acceptance/proceed checks pass; resolution/message checks fail because `resolve_contract`, `messages`, and `mara_favor_owed` do not exist.

- [ ] **Step 3: Commit the failing outcome contract**

```powershell
rtk git add tests/test_game_state.gd
rtk git commit -m "test: specify contract outcome effects"
```

- [ ] **Step 4: Add the one-bit Mara/message state and accepted/proceed feedback**

In `autoload/game_state.gd`, add:

```gdscript
signal messages_changed

var mara_favor_owed := false
var messages: Array[Dictionary] = [
	{"id": &"msg_mara_crate", "sender": "MARA", "preview": "Vesper has a cold-chain run. Start there.", "unread": true},
	{"id": &"msg_system_sweep", "sender": "SYSTEM", "preview": "corp sweep expected in Sector 9 tonight", "unread": true},
	{"id": &"msg_vasquez_docks", "sender": "VASQUEZ", "preview": "docks shift change is at 04:00, not 03:00", "unread": false},
]

func add_message(sender: String, preview: String) -> void:
	messages.append({
		"id": StringName("msg_%s_%d" % [sender.to_lower(), messages.size()]),
		"sender": sender,
		"preview": preview,
		"unread": true,
	})
	messages_changed.emit()
	push_ticker("NEW MESSAGE // " + sender, true)
```

Extend the existing accepted/proceed operations immediately after their current direct ticker calls:

```gdscript
# accept_contract
add_message("MARA", "Keep it cold. Keep it boring.")

# proceed_contract
add_message("MARA", "Customs is fishing for an excuse.")
```

Keep this as one flat message list. Do not add conversations, contacts, read actions, or a message database.

- [ ] **Step 5: Add `resolve_contract` with direct catalog-defined effects**

Add a private choice lookup and the terminal resolver:

```gdscript
func _choice(contract: Dictionary, choice_id: StringName) -> Dictionary:
	for choice: Dictionary in contract.complication.choices:
		if choice.id == choice_id:
			return choice
	return {}

func resolve_contract(id: StringName, choice_id: StringName) -> bool:
	var index := _contract_index(id)
	if index < 0 or active_contract_id != id:
		return false
	var contract: Dictionary = contracts[index]
	if contract.status != &"active" or contract.phase != &"customs_hold":
		return false
	var choice := _choice(contract, choice_id)
	if choice.is_empty():
		return false
	if choice.credit_delta != 0:
		add_credits(choice.credit_delta)
	if choice.heat_delta != 0:
		heat += choice.heat_delta
	if choice.get("sets_mara_favor_owed", false):
		mara_favor_owed = true
	contract.status = choice.terminal_status
	contract.phase = &"resolved"
	contract.resolution_id = choice_id
	active_contract_id = &""
	contracts_changed.emit()
	_push_resolution_feedback(choice_id)
	return true
```

Implement `_push_resolution_feedback(choice_id: StringName) -> void` as a four-branch private method. It must add exactly one outcome-specific Mara message and one contract-status ticker line for each `choice_id`:

```gdscript
func _push_resolution_feedback(choice_id: StringName) -> void:
	match choice_id:
		&"pay_fee":
			push_ticker("CONTRACT COMPLETE // +1,150 CR", true)
			add_message("MARA", "Paperwork cost less than a seizure.")
		&"call_mara":
			push_ticker("CONTRACT COMPLETE // +1,400 CR", true)
			add_message("MARA", "You owe me one.")
		&"bypass":
			push_ticker("CONTRACT COMPLETE // +1,400 CR // HEAT +2", true)
			add_message("MARA", "The crate moved; so did their cameras.")
		&"abort":
			push_ticker("CONTRACT FAILED // DELIVERY ABORTED", true)
			add_message("MARA", "Walking was cheaper than escalation.")
```

This local `match` is intentionally specific to C-1042's authored outcomes. Do not build a generic effect dispatcher or message-script system.

- [ ] **Step 6: Run the focused GameState test and confirm every outcome passes**

Run:

```powershell
rtk powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\run_test.ps1 test_game_state
```

Expected: `RESULT: ALL PASSED`; the four fresh fixtures prove terminal status, exact Credits/Heat effects, active-ID clearing, the Mara boolean, and the failure branch.

- [ ] **Step 7: Commit terminal effects and messages**

```powershell
rtk git add autoload/game_state.gd tests/test_game_state.gd
rtk git commit -m "feat: add cold-chain contract outcomes"
```

---

### Task 4: Render Contract Network availability and status

**Files:**
- Modify: `scenes/modules/contracts/contracts_panel.gd`
- Modify: `tests/test_contracts.gd`

**Interfaces:**
- Consumes: GameState contract record shape from Tasks 1–3.
- Produces: `signal contract_selected(contract_id: StringName)`; enabled available/active rows; disabled unavailable/completed/failed rows; no Dictionary is emitted from UI.

- [ ] **Step 1: Replace shell-placeholder list assertions with failing status assertions**

In `tests/test_contracts.gd`, preload no placeholder contract file. Use `gs.contracts` in `panel.setup(gs, gs.contracts)`. Replace the selection capture with:

```gdscript
	var seen_id: StringName = &""
	panel.contract_selected.connect(func(id: StringName) -> void: seen_id = id)
```

After collecting the three buttons, assert:

```gdscript
	check(buttons.size() == 3, "three catalog rows")
	check(buttons[0].text.contains("COLD-CHAIN DELIVERY") and buttons[0].text.contains("1,400 CR"),
		"C-1042 shows its available reward")
	check(not buttons[0].disabled, "C-1042 is selectable")
	check(buttons[1].disabled and buttons[1].text.contains("NETWORK OFFLINE"),
		"Data Retrieval is visibly unavailable")
	check(buttons[2].disabled and buttons[2].text.contains("NETWORK OFFLINE"),
		"encrypted offer is visibly unavailable")
	buttons[0].pressed.emit()
	check(seen_id == &"cold_chain_delivery", "C-1042 emits only its ID")
```

Pass deep copies with `status = &"active"`, `&"completed"`, and `&"failed"` in subsequent `panel.setup()` calls. Assert active is enabled and visibly marked `ACTIVE`, while terminal rows are disabled and visibly marked `COMPLETED` or `FAILED`.

- [ ] **Step 2: Run the contracts test and confirm the network assertions fail**

Run:

```powershell
rtk powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\run_test.ps1 test_contracts
```

Expected: current code still emits Dictionaries, exposes unrelated rows, and lacks status treatment; the updated assertions fail.

- [ ] **Step 3: Commit the failing Contract Network contract**

```powershell
rtk git add tests/test_contracts.gd
rtk git commit -m "test: specify contract network states"
```

- [ ] **Step 4: Change Contract Network to ID-only selection**

In `contracts_panel.gd`, change the signal declaration to:

```gdscript
signal contract_selected(contract_id: StringName)
```

Replace `_row_text(contract)` with status-aware text:

```gdscript
func _row_text(contract: Dictionary) -> String:
	if not contract.is_playable:
		return "%s   NETWORK OFFLINE" % contract.title
	match contract.status:
		&"active":
			return "ACTIVE // " + contract.title
		&"completed":
			return "COMPLETED // " + contract.title
		&"failed":
			return "FAILED // " + contract.title
		_:
			return "%s   %s CR" % [contract.title, GameStateScript.format_credits(contract.reward_credits)]
```

- [ ] **Step 5: Disable non-selectable rows before connecting them**

In the `setup()` row loop, set:

```gdscript
	var selectable: bool = contract.is_playable and contract.status in [&"available", &"active"]
	btn.disabled = not selectable
	if selectable:
		btn.pressed.connect(_on_row.bind(contract.id))
```

Change `_on_row` to receive and emit the ID:

```gdscript
func _on_row(contract_id: StringName) -> void:
	contract_selected.emit(contract_id)
```

Do not special-case encrypted offers beyond their catalog `is_playable == false`; disabled state is the one interaction gate.

- [ ] **Step 6: Run the Contract Network test and confirm it passes**

Run:

```powershell
rtk powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\run_test.ps1 test_contracts
```

Expected: Contract Network assertions pass. Existing detail assertions may still fail until Task 5; do not commit a knowingly failing focused test at the end of this task. Temporarily remove only the old detail assertions in Step 1 and add Task 5's replacement detail assertions in its failing-test commit.

- [ ] **Step 7: Commit Contract Network implementation**

```powershell
rtk git add scenes/modules/contracts/contracts_panel.gd tests/test_contracts.gd
rtk git commit -m "feat: render contract network states"
```

---

### Task 5: Render Contract Detail phases and intent-only controls

**Files:**
- Modify: `scenes/modules/contracts/contract_detail.gd`
- Modify: `tests/test_contracts.gd`

**Interfaces:**
- Consumes: One contract snapshot with catalog fields plus `status`, `phase`, and `resolution_id`.
- Produces: `accept_requested(contract_id)`, `proceed_requested(contract_id)`, `resolution_requested(contract_id, choice_id)`, `close_requested()`, and `acknowledge_requested()`; detail does not mutate GameState.

- [ ] **Step 1: Add failing detail phase/rendering assertions**

Append phase-specific detail tests in `tests/test_contracts.gd`. Use `gs.get_contract(&"cold_chain_delivery")` for the offer phase, then a deep duplicate with the required `status`, `phase`, and `resolution_id` fields for each later phase.

Add helper functions:

```gdscript
func _text(control: Control) -> String:
	var out := ""
	for label: Label in control.find_children("*", "Label", true, false):
		out += label.text + "\n"
	return out

func _button(control: Control, text: String) -> Button:
	for button: Button in control.find_children("*", "Button", true, false):
		if button.text == text:
			return button
	return null
```

Assert the offer contains `DAY 15 // 04:00`, `ACCEPT`, and `CLOSE`, but not `DECLINE`. Assert active contains `PROCEED TO DOCK 17`; Customs contains all four exact labels; and completed/failed resolved records contain `ACKNOWLEDGE` plus their terminal status.

Connect to each new signal, emit the corresponding button press, and assert that the expected ID/choice is observed while `gs` Credits, Heat, day, and contract phase remain unchanged.

- [ ] **Step 2: Run the contracts test and confirm detail assertions fail**

Run:

```powershell
rtk powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\run_test.ps1 test_contracts
```

Expected: the existing detail only displays static fields and has no action buttons/signals, so phase/action assertions fail.

- [ ] **Step 3: Commit the failing detail contract**

```powershell
rtk git add tests/test_contracts.gd
rtk git commit -m "test: specify contract detail phases"
```

- [ ] **Step 4: Add action signals and an action container**

At the top of `contract_detail.gd`, add:

```gdscript
signal accept_requested(contract_id: StringName)
signal proceed_requested(contract_id: StringName)
signal resolution_requested(contract_id: StringName, choice_id: StringName)
signal close_requested
signal acknowledge_requested

var _actions: VBoxContainer
var _contract_id: StringName = &""
```

In `_build_children()`, create `_actions := VBoxContainer.new()` after `_body`, set a small separation, and add it to the existing root `vbox`. Add helpers:

```gdscript
func _clear_actions() -> void:
	for child in _actions.get_children():
		child.queue_free()

func _add_action(text: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	_actions.add_child(button)
```

- [ ] **Step 5: Add phase dispatch plus offer/active rendering**

In `setup()`, clear prior controls even for empty input, assign `_contract_id`, then dispatch by phase:

```gdscript
_clear_actions()
if c.is_empty():
	_contract_id = &""
	_title.text = ""
	_body.text = ""
	return
_contract_id = c.id
match c.phase:
	&"offer":
		_render_offer(c)
	&"ready_to_proceed":
		_render_ready(c)
	&"customs_hold":
		_render_customs(c)
	&"resolved":
		_render_resolved(c)
```

Add these two render methods:

```gdscript
func _render_offer(c: Dictionary) -> void:
	_title.text = "CONTRACT // " + c.code
	_body.text = "\n".join([
		c.title, "", "CLIENT      " + c.client, "DESTINATION " + c.destination,
		"DEADLINE    DAY %d // %02d:%02d" % [
			c.deadline_day, floori(c.deadline_minute / 60.0), c.deadline_minute % 60,
		],
		"RISK        " + c.risk, "REWARD      " + GameStateScript.format_credits(c.reward_credits) + " CR",
	])
	_add_action("ACCEPT", func() -> void: accept_requested.emit(_contract_id))
	_add_action("CLOSE", func() -> void: close_requested.emit())

func _render_ready(c: Dictionary) -> void:
	_title.text = "ACTIVE // " + c.code
	_body.text = "\n".join([
		c.title, "", "DESTINATION " + c.destination,
		"DEADLINE    DAY %d // %02d:%02d" % [
			c.deadline_day, floori(c.deadline_minute / 60.0), c.deadline_minute % 60,
		],
		"STATUS      CARGO IN TRANSIT",
	])
	_add_action("PROCEED TO DOCK 17", func() -> void: proceed_requested.emit(_contract_id))
	_add_action("CLOSE", func() -> void: close_requested.emit())
```

- [ ] **Step 6: Add Customs and resolved rendering**

Add a choice lookup and render the terminal phases from the selected catalog choice:

```gdscript
func _choice(c: Dictionary, choice_id: StringName) -> Dictionary:
	for choice: Dictionary in c.complication.choices:
		if choice.id == choice_id:
			return choice
	return {}

func _render_customs(c: Dictionary) -> void:
	_title.text = c.complication.title
	_body.text = c.complication.body
	for choice: Dictionary in c.complication.choices:
		var choice_id: StringName = choice.id
		_add_action(choice.label, func() -> void:
			resolution_requested.emit(_contract_id, choice_id))

func _render_resolved(c: Dictionary) -> void:
	var choice := _choice(c, c.resolution_id)
	_title.text = "CONTRACT COMPLETE" if c.status == &"completed" else "CONTRACT FAILED"
	_body.text = "\n".join([
		c.title,
		"CREDITS     %+d CR" % choice.credit_delta,
		"HEAT        %+d" % choice.heat_delta,
	])
	_add_action("ACKNOWLEDGE", func() -> void: acknowledge_requested.emit())
```

Do not calculate rewards, mutate state, or add a Decline button in ContractDetail.

- [ ] **Step 7: Run the contracts test and confirm it passes**

Run:

```powershell
rtk powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\run_test.ps1 test_contracts
```

Expected: `RESULT: ALL PASSED`; panel status and every detail phase/action signal are verified without UI-owned state mutation.

- [ ] **Step 8: Commit Contract Detail implementation**

```powershell
rtk git add scenes/modules/contracts/contract_detail.gd tests/test_contracts.gd
rtk git commit -m "feat: add contract detail flow"
```

---

### Task 6: Wire the vertical slice through Main and Comms

**Files:**
- Modify: `scenes/main/main.gd`
- Modify: `tests/test_main.gd`
- Modify: `tests/test_panels_basic.gd`

**Interfaces:**
- Consumes: `GameState.get_contract`, contract transition methods/signals, `GameState.messages`, Contract Network ID selection, and Contract Detail intent signals.
- Produces: Adjacent detail behavior that re-renders after each state mutation; Close leaves state unchanged; Acknowledge closes context and retains Contract Network; Comms receives GameState-owned messages.

- [ ] **Step 1: Add failing Main flow assertions**

Add a helper to `tests/test_main.gd`:

```gdscript
func _button(control: Control, text: String) -> Button:
	for button: Button in control.find_children("*", "Button", true, false):
		if button.text == text:
			return button
	return null
```

After the existing module-switch test, select contracts, press the C-1042 row, then assert ContextHost contains `ContractDetail` alongside unchanged `ContractsPanel`. Press `ACCEPT`, assert the same context has `PROCEED TO DOCK 17`; press Proceed, assert `gs.day == 15` and detail has `ABORT DELIVERY`; press Abort, assert the list row is disabled/failed; press `ACKNOWLEDGE`, assert ContextHost is empty while `primary` still contains `ContractsPanel` and remains visible.

Before the abort branch, create a separate selection run that presses `CLOSE` on the offer and asserts `gs.get_contract(&"cold_chain_delivery").status == &"available"`.

- [ ] **Step 2: Run the Main test and confirm it fails before wiring changes**

Run:

```powershell
rtk powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\run_test.ps1 test_main
```

Expected: Main still passes placeholder Dictionaries and connects the obsolete detail-only flow, so C-1042 actions and state refresh checks fail.

- [ ] **Step 3: Commit the failing Main integration contract**

```powershell
rtk git add tests/test_main.gd
rtk git commit -m "test: specify first contract workspace flow"
```

- [ ] **Step 4: Replace Main's placeholder injections with GameState data**

Remove the `PlaceholderContracts` and `PlaceholderMessages` preloads from `main.gd`. In `_build_primary_module(id)`, use:

```gdscript
	if id == &"contracts":
		panel.contract_selected.connect(_on_contract_selected)
		panel.setup(gs, gs.contracts)
	else:
		panel.setup(gs, gs.messages if id == &"comms" else null)
```

Declare one transient field beside the other Main fields:

```gdscript
var _selected_contract_id: StringName = &""
```

In `_build_shell()`, connect:

```gdscript
gs.contracts_changed.connect(_on_contracts_changed)
```

- [ ] **Step 5: Replace Dictionary selection with detail intent wiring**

Replace `_on_contract_selected(contract: Dictionary)` with:

```gdscript
func _on_contract_selected(contract_id: StringName) -> void:
	_selected_contract_id = contract_id
	var detail: Control = ContractDetailScene.instantiate()
	detail.accept_requested.connect(_on_contract_accept)
	detail.proceed_requested.connect(_on_contract_proceed)
	detail.resolution_requested.connect(_on_contract_resolution)
	detail.close_requested.connect(_close_contract_detail)
	detail.acknowledge_requested.connect(_close_contract_detail)
	open_context(detail)
	detail.setup(gs, gs.get_contract(contract_id))
```

Add intent forwarding plus refresh methods:

```gdscript
func _on_contract_accept(id: StringName) -> void:
	gs.accept_contract(id)

func _on_contract_proceed(id: StringName) -> void:
	gs.proceed_contract(id)

func _on_contract_resolution(id: StringName, choice_id: StringName) -> void:
	gs.resolve_contract(id, choice_id)

func _on_contracts_changed() -> void:
	if gs.active_module != &"contracts" or not gs.module_open:
		return
	var panel := primary_host.get_child(0)
	panel.setup(gs, gs.contracts)
	if _selected_contract_id != &"" and context_host.get_child_count() > 0:
		context_host.get_child(0).setup(gs, gs.get_contract(_selected_contract_id))

func _close_contract_detail() -> void:
	_selected_contract_id = &""
	close_context()
```

`contracts_changed` is emitted after each accepted/proceeded/resolved record mutation, so no Main method manually recalculates or writes UI state.

- [ ] **Step 6: Change Comms basic-panel setup to GameState messages**

In `tests/test_panels_basic.gd`, remove the `PlaceholderMessages` preload. Replace:

```gdscript
comms.setup(gs, PlaceholderMessages.all())
```

with:

```gdscript
comms.setup(gs, gs.messages)
```

Keep its existing assertion for three initial message rows. No CommsPanel live-refresh signal is added for this slice.

- [ ] **Step 7: Run the affected tests and confirm they pass**

Run:

```powershell
rtk powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\run_test.ps1 test_main
rtk powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\run_test.ps1 test_panels_basic
```

Expected: both print `RESULT: ALL PASSED`; Main proves Close is non-mutating, the Abort path is terminal, Acknowledge returns to Network, and Comms renders GameState-owned initial messages.

- [ ] **Step 8: Commit workspace wiring**

```powershell
rtk git add scenes/main/main.gd tests/test_main.gd tests/test_panels_basic.gd
rtk git commit -m "feat: wire first contract workspace loop"
```

---

### Task 7: Remove superseded placeholder paths and verify the slice

**Files:**
- Delete: `data/placeholder/placeholder_contracts.gd`
- Delete: `data/placeholder/placeholder_messages.gd`
- Delete: `tests/test_placeholder_data.gd`
- Verify: `autoload/game_state.gd`
- Verify: `data/contracts/contract_catalog.gd`
- Verify: `scenes/modules/contracts/contracts_panel.gd`
- Verify: `scenes/modules/contracts/contract_detail.gd`
- Verify: `scenes/main/main.gd`
- Verify: `tests/test_contract_catalog.gd`
- Verify: `tests/test_game_state.gd`
- Verify: `tests/test_contracts.gd`
- Verify: `tests/test_main.gd`
- Verify: `tests/test_panels_basic.gd`

**Interfaces:**
- Consumes: Completed GameState/catalog/UI/Main migration from Tasks 1–6.
- Produces: One clean contract-data path, no obsolete placeholder contracts/messages, passing focused regression suite, and visual proof of all four outcomes.

- [ ] **Step 1: Confirm no source caller remains on either placeholder provider**

Run:

```powershell
rtk git grep -n -e "placeholder_contracts" -e "PlaceholderContracts" -e "placeholder_messages" -e "PlaceholderMessages" -- autoload data scenes tests
```

Expected: only the obsolete provider/test files themselves are returned. If any active caller remains, migrate it to `GameState.contracts`, `GameState.messages`, or `ContractCatalog.all()` before deletion.

- [ ] **Step 2: Delete the obsolete providers and their obsolete data test**

Delete exactly these files:

```text
data/placeholder/placeholder_contracts.gd
data/placeholder/placeholder_messages.gd
tests/test_placeholder_data.gd
```

Do not delete the `data/placeholder` directory if it becomes empty; directory cleanup is not required for gameplay correctness.

- [ ] **Step 3: Run all focused headless tests**

Run:

```powershell
rtk powershell -NoProfile -Command "$tests = 'test_contract_catalog','test_game_state','test_contracts','test_main','test_panels_basic'; foreach ($test in $tests) { & .\tests\run_test.ps1 $test; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE } }"
```

Expected: every script prints `RESULT: ALL PASSED` and the command exits successfully.

- [ ] **Step 4: Run the full existing headless suite with the new catalog test**

Run:

```powershell
rtk powershell -NoProfile -Command "$tests = 'test_smoke','test_game_state','test_module_registry','test_theme','test_contract_catalog','test_status_chip','test_icon_rail','test_ticker_bar','test_panels_basic','test_contracts','test_main'; foreach ($test in $tests) { & .\tests\run_test.ps1 $test; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE } }"
```

Expected: every test prints `RESULT: ALL PASSED` and the command exits successfully.

- [ ] **Step 5: Smoke-test each player-visible terminal branch in Godot**

Run:

```powershell
rtk powershell -NoProfile -Command "& 'C:\Users\merli\Documents\Godot Projects\Godot_v4.7.1-stable_win64_console.exe' --path ."
```

For four fresh launches, open Contract Network, select C-1042, accept, proceed, and choose one option per launch: Pay fee, Call Mara, Bypass, Abort. On every launch verify:

1. C-1042 detail remains adjacent to Contract Network, never fullscreen.
2. Proceed changes Day 14 // 23:41 to Day 15 // 01:01.
3. Pay fee displays +1,150 CR with unchanged Heat.
4. Call Mara displays +1,400 CR, unchanged Heat, and `You owe me one.` in Comms.
5. Bypass displays +1,400 CR and Heat +2.
6. Abort displays failed with no Credits/Heat change.
7. Acknowledge closes only Contract Detail; the terminal C-1042 row is disabled; the Network remains open.
8. Ticker receives contract status and `NEW MESSAGE // MARA` feedback.

- [ ] **Step 6: Commit the clean cutover**

Run:

```powershell
rtk git add autoload/game_state.gd data/contracts/contract_catalog.gd scenes/main/main.gd scenes/modules/contracts/contracts_panel.gd scenes/modules/contracts/contract_detail.gd tests/test_contract_catalog.gd tests/test_game_state.gd tests/test_contracts.gd tests/test_main.gd tests/test_panels_basic.gd data/placeholder/placeholder_contracts.gd data/placeholder/placeholder_messages.gd tests/test_placeholder_data.gd
rtk git commit -m "feat: complete first contract vertical slice"
```

The explicit path list stages only this slice's modifications and deletions. Do not use `git add -A`; unrelated user work must remain untouched.
