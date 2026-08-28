extends Node
## Central game state singleton (registered as autoload "GameState").
## Components receive this node via setup() injection — they never access
## the autoload global by name. No class_name on purpose (autoload name wins).

signal credits_changed(new_credits: int)
signal clock_changed(day: int, minute_of_day: int)
signal district_changed(new_district: String)
signal heat_changed(new_heat: int)
signal alerts_changed(new_alerts: int)
signal workspace_collapsed_changed(collapsed: bool)
signal active_module_changed(id: StringName)
signal module_open_changed(open: bool)
signal ticker_message(text: String, highlight: bool)
const ContractCatalog := preload("res://data/contracts/contract_catalog.gd")

signal contracts_changed
signal messages_changed

var contracts: Array[Dictionary] = ContractCatalog.all()
var active_contract_id: StringName = &""
var mara_favor_owed := false
var messages: Array[Dictionary] = [
	{"id": &"msg_mara_crate", "sender": "MARA", "preview": "Vesper has a cold-chain run. Start there.", "unread": true},
	{"id": &"msg_system_sweep", "sender": "SYSTEM", "preview": "corp sweep expected in Sector 9 tonight", "unread": true},
	{"id": &"msg_vasquez_docks", "sender": "VASQUEZ", "preview": "docks shift change is at 04:00, not 03:00", "unread": false},
]

const START_CREDITS := 12480
const START_DISTRICT := "LOWER VESPER"
const START_DAY := 14
const START_MINUTE := 23 * 60 + 41

var credits: int = START_CREDITS:
	set(value):
		credits = maxi(value, 0)
		credits_changed.emit(credits)
var district: String = START_DISTRICT:
	set(value):
		district = value
		district_changed.emit(district)
var day: int = START_DAY
var minute_of_day: int = START_MINUTE
var heat: int = 2:
	set(value):
		heat = value
		heat_changed.emit(heat)
var alerts: int = 2:
	set(value):
		alerts = value
		alerts_changed.emit(alerts)
var workspace_collapsed := false
var active_module: StringName = &""
var module_open := false

func add_credits(delta_credits: int) -> void:
	credits += delta_credits
func add_message(sender: String, preview: String) -> void:
	messages.append({
		"id": StringName("msg_%s_%d" % [sender.to_lower(), messages.size()]),
		"sender": sender,
		"preview": preview,
		"unread": true,
	})
	messages_changed.emit()
	push_ticker("NEW MESSAGE // " + sender, true)

func advance_minutes(minutes: int) -> void:
	minute_of_day += minutes
	while minute_of_day >= 1440:
		minute_of_day -= 1440
		day += 1
	clock_changed.emit(day, minute_of_day)

func _contract_index(id: StringName) -> int:
	for index in contracts.size():
		if contracts[index].id == id:
			return index
	return -1

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
	add_message("MARA", contract.accept_message)
	return true

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
	push_ticker(contract.complication.title, true)
	add_message("MARA", contract.proceed_message)
	return true
 

func resolve_contract(id: StringName, choice_id: StringName) -> bool:
	var index := _contract_index(id)
	if index < 0 or active_contract_id != id:
		return false
	var contract: Dictionary = contracts[index]
	if contract.status != &"active" or contract.phase != &"customs_hold":
		return false
	var choice := _choice(_available_choices(contract), choice_id)
	if choice.is_empty():
		return false
	if choice.credit_delta != 0:
		add_credits(choice.credit_delta)
	if choice.heat_delta != 0:
		heat += choice.heat_delta
	if choice.get("sets_mara_favor_owed", false):
		mara_favor_owed = true
	if choice.get("clears_mara_favor", false):
		mara_favor_owed = false
	_unlock_contract(choice.get("unlocks_contract_id", &""))
	contract.status = choice.terminal_status
	contract.phase = &"resolved"
	contract.resolution_id = choice_id
	active_contract_id = &""
	contracts_changed.emit()
	_push_resolution_feedback(choice)
	return true

func _unlock_contract(id: StringName) -> void:
	if id == &"":
		return
	var index := _contract_index(id)
	if index >= 0:
		contracts[index].is_playable = true

func _push_resolution_feedback(choice: Dictionary) -> void:
	push_ticker(choice.ticker, true)
	add_message(choice.message_sender, choice.message_preview)

func set_workspace_collapsed(collapsed: bool) -> void:
	if workspace_collapsed == collapsed:
		return
	workspace_collapsed = collapsed
	workspace_collapsed_changed.emit(collapsed)

func set_active_module(id: StringName) -> void:
	if active_module == id:
		return
	active_module = id
	active_module_changed.emit(id)

func set_module_open(open: bool) -> void:
	if module_open == open:
		return
	module_open = open
	module_open_changed.emit(open)

func toggle_workspace() -> void:
	set_workspace_collapsed(not workspace_collapsed)

func push_ticker(text: String, highlight: bool = false) -> void:
	ticker_message.emit(text, highlight)

func clock_text() -> String:
	return "%02d:%02d" % [floori(minute_of_day / 60.0), minute_of_day % 60]

static func format_credits(amount: int) -> String:
	var digits := str(amount)
	var out := ""
	while digits.length() > 3:
		out = "," + digits.substr(digits.length() - 3) + out
		digits = digits.substr(0, digits.length() - 3)
	return digits + out
