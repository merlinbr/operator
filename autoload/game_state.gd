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
signal residence_changed(id: StringName)
signal rent_changed(status: StringName, amount: int, next_due_day: int)
const ContractCatalog := preload("res://data/contracts/contract_catalog.gd")
const ResidenceCatalog := preload("res://data/housing/residence_catalog.gd")
const ContactCatalog := preload("res://data/contacts/contact_catalog.gd")
const PROFILE_PATH := "user://operator_save.json"
const PROFILE_TEMP_PATH := "user://operator_save.json.tmp"
const PROFILE_BACKUP_PATH := "user://operator_save.json.bak"
const PROFILE_VERSION := 2

signal contracts_changed
signal contacts_changed
signal messages_changed
signal contract_accepted(id: StringName)
signal contract_proceeded(id: StringName)
signal contract_resolved(id: StringName, status: StringName)

const DEFAULT_MESSAGES: Array[Dictionary] = [
	{"id": &"msg_mara_crate", "sender": "MARA", "preview": "Vesper has a cold-chain run. Start there.", "unread": true},
	{"id": &"msg_system_sweep", "sender": "SYSTEM", "preview": "corp sweep expected in Sector 9 tonight", "unread": true},
	{"id": &"msg_vasquez_docks", "sender": "VASQUEZ", "preview": "docks shift change is at 04:00, not 03:00", "unread": false},
]

var contracts: Array[Dictionary] = ContractCatalog.all()
var active_contract_id: StringName = &""
var mara_favor_owed := false
var messages: Array[Dictionary] = DEFAULT_MESSAGES.duplicate(true)
var contact_standing: Dictionary = _default_contact_standing()

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
var current_residence_id: StringName = &"lower_vesper_studio"
var owned_residence_ids: Array[StringName] = []
var next_rent_due_day := 30
var rent_due_amount := 0
var rent_status: StringName = &"current"


func _ready() -> void:
	load_profile()

func reset_profile() -> void:
	var old_residence := current_residence_id
	var old_rent_status := rent_status
	var old_rent_amount := rent_due_amount
	var old_next_rent_due_day := next_rent_due_day
	contracts = ContractCatalog.all()
	active_contract_id = &""
	mara_favor_owed = false
	messages = DEFAULT_MESSAGES.duplicate(true)
	credits = START_CREDITS
	district = START_DISTRICT
	day = START_DAY
	minute_of_day = START_MINUTE
	heat = 2
	alerts = 2
	workspace_collapsed = false
	active_module = &""
	module_open = false
	current_residence_id = &"lower_vesper_studio"
	owned_residence_ids = []
	next_rent_due_day = 30
	rent_due_amount = 0
	rent_status = &"current"
	contact_standing = _default_contact_standing()
	for path in [PROFILE_PATH, PROFILE_TEMP_PATH, PROFILE_BACKUP_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_emit_housing_changes(old_residence, old_rent_status, old_rent_amount, old_next_rent_due_day)

func save_profile() -> bool:
	var file := FileAccess.open(PROFILE_TEMP_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Unable to write operator profile temporary file.")
		return false
	file.store_string(JSON.stringify(_profile_payload()))
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		push_error("Unable to finish writing operator profile.")
		return false
	var profile_path := ProjectSettings.globalize_path(PROFILE_PATH)
	var temporary_path := ProjectSettings.globalize_path(PROFILE_TEMP_PATH)
	var backup_path := ProjectSettings.globalize_path(PROFILE_BACKUP_PATH)
	if FileAccess.file_exists(PROFILE_PATH):
		if FileAccess.file_exists(PROFILE_BACKUP_PATH):
			var remove_backup_error := DirAccess.remove_absolute(backup_path)
			if remove_backup_error != OK:
				push_error("Unable to replace operator profile.")
				return false
		var backup_error := DirAccess.rename_absolute(profile_path, backup_path)
		if backup_error != OK:
			push_error("Unable to replace operator profile.")
			return false
	var rename_error := DirAccess.rename_absolute(temporary_path, profile_path)
	if rename_error != OK:
		if FileAccess.file_exists(PROFILE_BACKUP_PATH) and not FileAccess.file_exists(PROFILE_PATH):
			DirAccess.rename_absolute(backup_path, profile_path)
		push_error("Unable to replace operator profile.")
		return false
	if FileAccess.file_exists(PROFILE_BACKUP_PATH):
		DirAccess.remove_absolute(backup_path)
	return true

func load_profile() -> bool:
	var saw_profile := false
	for path in [PROFILE_PATH, PROFILE_TEMP_PATH, PROFILE_BACKUP_PATH]:
		if not FileAccess.file_exists(path):
			continue
		saw_profile = true
		var parsed: Variant = _read_profile_candidate(path)
		if parsed != null:
			_apply_profile(parsed)
			return true
	if saw_profile:
		return _reject_profile("profile candidates are unreadable, malformed, or incompatible")
	reset_profile()
	return false

func _read_profile_candidate(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var text := file.get_as_text()
	var read_error := file.get_error()
	file.close()
	if read_error != OK:
		return null
	var parser := JSON.new()
	if parser.parse(text) != OK or typeof(parser.data) != TYPE_DICTIONARY:
		return null
	var parsed: Dictionary = parser.data
	if _is_int_value(parsed.get("version", null)) and int(parsed.version) == 1:
		parsed = _migrate_v1_profile(parsed)
	if not _validate_profile(parsed).is_empty():
		return null
	return parsed

func _reject_profile(reason: String) -> bool:
	push_error("Unable to load operator profile: %s. Starting clean." % reason)
	reset_profile()
	return false

func _profile_payload() -> Dictionary:
	return {
		"version": PROFILE_VERSION,
		"credits": credits,
		"district": district,
		"day": day,
		"minute_of_day": minute_of_day,
		"heat": heat,
		"alerts": alerts,
		"workspace_collapsed": workspace_collapsed,
		"active_module": active_module,
		"module_open": module_open,
		"active_contract_id": active_contract_id,
		"contact_standing": contact_standing.duplicate(true),
		"contracts": contracts.duplicate(true),
		"mara_favor_owed": mara_favor_owed,
		"messages": messages.duplicate(true),
		"current_residence_id": current_residence_id,
		"owned_residence_ids": owned_residence_ids,
		"next_rent_due_day": next_rent_due_day,
		"rent_due_amount": rent_due_amount,
		"rent_status": rent_status,
	}

func _default_contact_standing() -> Dictionary:
	var standings := {}
	for contact: Dictionary in ContactCatalog.all():
		standings[contact.id] = contact.starting_standing
	return standings

func standing_for(contact_id: StringName) -> int:
	return int(contact_standing.get(contact_id, 0))

func contact_snapshot() -> Array[Dictionary]:
	var snapshot: Array[Dictionary] = []
	for contact: Dictionary in ContactCatalog.all():
		var standing := standing_for(contact.id)
		snapshot.append({
			"id": contact.id,
			"display_name": contact.display_name,
			"standing": standing,
			"standing_label": ContactCatalog.standing_label(standing),
		})
	return snapshot

func _validate_contact_standing(raw: Variant) -> bool:
	if typeof(raw) != TYPE_DICTIONARY or raw.size() != ContactCatalog.all().size():
		return false
	for contact: Dictionary in ContactCatalog.all():
		if not raw.has(contact.id) or not _is_int_value(raw[contact.id]) \
				or int(raw[contact.id]) < ContactCatalog.COLD \
				or int(raw[contact.id]) > ContactCatalog.TRUSTED:
			return false
	return true

func _raise_contact_standing(contact_id: StringName, delta: int) -> void:
	var previous := standing_for(contact_id)
	var raised := mini(previous + delta, ContactCatalog.TRUSTED)
	if raised == previous:
		return
	contact_standing[contact_id] = raised
	contacts_changed.emit()

func _migrate_v1_profile(data: Dictionary) -> Dictionary:
	var migrated := data.duplicate(true)
	var old_contracts := {}
	for record: Variant in data.get("contracts", []):
		if typeof(record) == TYPE_DICTIONARY and _is_string_value(record.get("id", null)):
			old_contracts[StringName(str(record.id))] = record
	var merged_contracts := ContractCatalog.all()
	for contract: Dictionary in merged_contracts:
		var old: Dictionary = old_contracts.get(contract.id, {})
		for key in [&"is_playable", &"status", &"phase", &"resolution_id"]:
			if old.has(key):
				contract[key] = old[key]
	migrated.contracts = merged_contracts
	migrated.contact_standing = _default_contact_standing()
	var old_recovery: Dictionary = old_contracts.get(&"clinic_asset_recovery", {})
	if old_recovery.get("status", &"available") == &"completed":
		migrated.contact_standing[&"vesper_clinic"] = ContactCatalog.KNOWN
	migrated.version = PROFILE_VERSION
	return migrated

func _validate_profile(data: Dictionary) -> String:
	for key in _profile_payload().keys():
		if not data.has(key):
			return "profile is missing '%s'" % key
	if not _is_int_value(data.version) or int(data.version) != PROFILE_VERSION:
		return "profile version is incompatible"
	if not _is_int_value(data.credits) or data.credits < 0:
		return "profile Credits are invalid"
	if not _is_string_value(data.district):
		return "profile district is invalid"
	if not _is_int_value(data.day) or data.day < 1:
		return "profile day is invalid"
	if not _is_int_value(data.minute_of_day) or data.minute_of_day < 0 or data.minute_of_day >= 1440:
		return "profile clock is invalid"
	if not _is_int_value(data.heat) or data.heat < 0:
		return "profile Heat is invalid"
	if not _is_int_value(data.alerts) or data.alerts < 0:
		return "profile alerts are invalid"
	if typeof(data.workspace_collapsed) != TYPE_BOOL or typeof(data.module_open) != TYPE_BOOL:
		return "profile workspace state is invalid"
	if not _is_string_value(data.active_module) or not _is_string_value(data.active_contract_id):
		return "profile active state is invalid"
	if typeof(data.mara_favor_owed) != TYPE_BOOL:
		return "profile favor state is invalid"
	if not _validate_contact_standing(data.contact_standing):
		return "profile contact standing is invalid"
	var contract_reason := _validate_contracts(data.contracts, StringName(str(data.active_contract_id)))
	if not contract_reason.is_empty():
		return contract_reason
	if typeof(data.messages) != TYPE_ARRAY:
		return "profile messages are invalid"
	for message: Variant in data.messages:
		if typeof(message) != TYPE_DICTIONARY or not _is_string_value(message.get("id", null)) \
				or typeof(message.get("sender", null)) != TYPE_STRING \
				or typeof(message.get("preview", null)) != TYPE_STRING \
				or typeof(message.get("unread", null)) != TYPE_BOOL:
			return "profile message records are invalid"
	if not _validate_housing(data):
		return "profile housing state is invalid"
	return ""

func _validate_contracts(raw_contracts: Variant, active_id: StringName) -> String:
	if typeof(raw_contracts) != TYPE_ARRAY:
		return "profile contracts are invalid"
	var authored := ContractCatalog.all()
	if raw_contracts.size() != authored.size():
		return "profile contract records are incompatible"
	var active_count := 0
	for index in authored.size():
		var record: Variant = raw_contracts[index]
		if typeof(record) != TYPE_DICTIONARY:
			return "profile contract records are invalid"
		if not _is_string_value(record.get("id", null)) \
				or StringName(str(record.id)) != authored[index].id:
			return "profile contract IDs are invalid"
		if typeof(record.get("is_playable", null)) != TYPE_BOOL:
			return "profile contract unlocks are invalid"
		if not _is_string_value(record.get("status", null)) \
				or not [&"available", &"active", &"completed", &"failed"].has(StringName(str(record.status))):
			return "profile contract status is invalid"
		if not _is_string_value(record.get("phase", null)) \
				or not [&"offer", &"ready_to_proceed", &"customs_hold", &"resolved"].has(StringName(str(record.phase))):
			return "profile contract phase is invalid"
		if not _is_string_value(record.get("resolution_id", null)):
			return "profile contract resolution is invalid"
		var status := StringName(str(record.status))
		var phase := StringName(str(record.phase))
		if status == &"active":
			active_count += 1
			if phase != &"ready_to_proceed" and phase != &"customs_hold":
				return "profile active contract state is invalid"
			if record.resolution_id != &"":
				return "profile active contract state is invalid"
		elif status == &"available":
			if phase != &"offer" or record.resolution_id != &"":
				return "profile contract state is invalid"
		elif (status == &"completed" or status == &"failed"):
			if phase != &"resolved" or record.resolution_id == &"":
				return "profile terminal contract state is invalid"
	if active_count > 1 or (active_count == 0 and active_id != &"") or (active_count == 1 and active_id == &""):
		return "profile active contract state is invalid"
	if active_id != &"" and not authored.any(func(contract: Dictionary) -> bool: return contract.id == active_id):
		return "profile active contract ID is invalid"
	return ""

func _validate_housing(data: Dictionary) -> bool:
	if not _is_string_value(data.current_residence_id):
		return false
	var current := StringName(str(data.current_residence_id))
	var residence := _residence(current)
	if residence.is_empty():
		return false
	if typeof(data.owned_residence_ids) != TYPE_ARRAY:
		return false
	var owned: Array[StringName] = []
	for raw_id: Variant in data.owned_residence_ids:
		if not _is_string_value(raw_id):
			return false
		var id := StringName(str(raw_id))
		if id != &"lower_vesper_studio" or owned.has(id):
			return false
		owned.append(id)
	if not _is_int_value(data.next_rent_due_day) or data.next_rent_due_day < 1:
		return false
	if not _is_int_value(data.rent_due_amount) or data.rent_due_amount < 0:
		return false
	if not _is_string_value(data.rent_status):
		return false
	var status := StringName(str(data.rent_status))
	if not [&"current", &"due", &"overdue"].has(status):
		return false
	if status == &"current" and data.rent_due_amount != 0:
		return false
	if (status == &"due" or status == &"overdue") \
			and data.rent_due_amount != int(residence.monthly_rent):
		return false
	if owned.has(current) and status != &"current":
		return false
	return true

func _residence(id: StringName) -> Dictionary:
	for residence: Dictionary in ResidenceCatalog.all():
		if residence.id == id:
			return residence
	return {}

func _is_string_value(value: Variant) -> bool:
	return typeof(value) == TYPE_STRING or typeof(value) == TYPE_STRING_NAME
func _is_int_value(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return true
	return typeof(value) == TYPE_FLOAT and is_equal_approx(value, round(value))

func _apply_profile(data: Dictionary) -> void:
	var old_residence := current_residence_id
	var old_rent_status := rent_status
	var old_rent_amount := rent_due_amount
	var old_next_rent_due_day := next_rent_due_day
	credits = int(data.credits)
	district = str(data.district)
	day = int(data.day)
	minute_of_day = int(data.minute_of_day)
	heat = int(data.heat)
	alerts = int(data.alerts)
	workspace_collapsed = data.workspace_collapsed
	active_module = StringName(str(data.active_module))
	module_open = data.module_open
	active_contract_id = StringName(str(data.active_contract_id))
	mara_favor_owed = data.mara_favor_owed
	var restored_contracts: Array[Dictionary] = ContractCatalog.all()
	for index in restored_contracts.size():
		var record: Dictionary = data.contracts[index]
		for key in [&"is_playable", &"status", &"phase", &"resolution_id"]:
			restored_contracts[index][key] = record[key]
	contracts = restored_contracts
	var restored_messages: Array[Dictionary] = []
	for message: Dictionary in data.messages:
		restored_messages.append(message.duplicate(true))
	messages = restored_messages
	contact_standing = data.contact_standing.duplicate(true)
	current_residence_id = StringName(str(data.current_residence_id))
	owned_residence_ids = []
	for raw_id: Variant in data.owned_residence_ids:
		owned_residence_ids.append(StringName(str(raw_id)))
	next_rent_due_day = int(data.next_rent_due_day)
	rent_due_amount = int(data.rent_due_amount)
	rent_status = StringName(str(data.rent_status))
	_emit_housing_changes(old_residence, old_rent_status, old_rent_amount, old_next_rent_due_day)

func _emit_housing_changes(old_residence: StringName, old_rent_status: StringName,
		old_rent_amount: int, old_next_rent_due_day: int) -> void:
	if old_residence != current_residence_id:
		residence_changed.emit(current_residence_id)
	if old_rent_status != rent_status or old_rent_amount != rent_due_amount \
			or old_next_rent_due_day != next_rent_due_day:
		rent_changed.emit(rent_status, rent_due_amount, next_rent_due_day)

func _add_credits(delta_credits: int) -> void:
	credits += delta_credits

func add_credits(delta_credits: int) -> void:
	_add_credits(delta_credits)
	save_profile()

func _add_message(sender: String, preview: String) -> void:
	messages.append({
		"id": StringName("msg_%s_%d" % [sender.to_lower(), messages.size()]),
		"sender": sender,
		"preview": preview,
		"unread": true,
	})
	messages_changed.emit()
	push_ticker("NEW MESSAGE // " + sender, true)

func add_message(sender: String, preview: String) -> void:
	_add_message(sender, preview)
	save_profile()

func advance_minutes(minutes: int) -> void:
	if minutes <= 0:
		return
	_advance_minutes(minutes)
	save_profile()

func _advance_minutes(minutes: int) -> void:
	var remaining := minutes
	while remaining > 0:
		var until_midnight := 1440 - minute_of_day
		if remaining < until_midnight:
			minute_of_day += remaining
			remaining = 0
		else:
			minute_of_day = 0
			remaining -= until_midnight
			day += 1
			_settle_calendar_day(day)
	clock_changed.emit(day, minute_of_day)

func _settle_calendar_day(settlement_day: int) -> void:
	var residence := _residence(current_residence_id)
	if residence.is_empty() or _is_owned(current_residence_id):
		return
	if rent_status == &"due":
		if settlement_day >= next_rent_due_day + 3:
			_set_rent_state(&"overdue", rent_due_amount, next_rent_due_day)
			_housing_feedback("RENT OVERDUE", "Rent is overdue. Existing work remains available.")
		return
	if rent_status == &"overdue":
		return
	if settlement_day < next_rent_due_day:
		return
	var rent := int(residence.monthly_rent)
	if credits >= rent:
		credits -= rent
		_set_rent_state(&"current", 0, next_rent_due_day + 30)
		_housing_feedback("RENT PAID // %s CR" % format_credits(rent),
			"%s rent paid automatically." % residence.name)
	else:
		_set_rent_state(&"due", rent, next_rent_due_day)
		_housing_feedback("RENT DUE // %s CR" % format_credits(rent),
			"%s rent is due." % residence.name)

func _is_owned(id: StringName) -> bool:
	return owned_residence_ids.has(id)

func _set_rent_state(status: StringName, amount: int, due_day: int) -> void:
	var old_status := rent_status
	var old_amount := rent_due_amount
	var old_due_day := next_rent_due_day
	rent_status = status
	rent_due_amount = amount
	next_rent_due_day = due_day
	if old_status != rent_status or old_amount != rent_due_amount or old_due_day != next_rent_due_day:
		rent_changed.emit(rent_status, rent_due_amount, next_rent_due_day)


func _housing_feedback(ticker: String, preview: String) -> void:
	push_ticker(ticker, true)
	_add_message("SYSTEM", preview)

func rest_until_next_day() -> bool:
	if active_contract_id != &"":
		return false
	day += 1
	minute_of_day = 0
	_settle_calendar_day(day)
	clock_changed.emit(day, minute_of_day)
	_housing_feedback("REST // ADVANCE TO DAY %d" % day, "Advanced to Day %d at midnight." % day)
	save_profile()
	return true

func pay_rent() -> bool:
	if (rent_status != &"due" and rent_status != &"overdue") \
			or rent_due_amount <= 0 or credits < rent_due_amount:
		return false
	var amount := rent_due_amount
	credits -= amount
	_set_rent_state(&"current", 0, day + 30)
	_housing_feedback("RENT PAID // %s CR" % format_credits(amount), "Rent payment accepted.")
	save_profile()
	return true

func move_to_residence(id: StringName) -> bool:
	if active_contract_id != &"" or rent_status != &"current":
		return false
	var residence := _residence(id)
	if residence.is_empty() or id == current_residence_id:
		return false
	var move_in_cost := int(residence.move_in_cost)
	if credits < move_in_cost:
		return false
	var old_residence := current_residence_id
	var old_rent_status := rent_status
	var old_rent_amount := rent_due_amount
	var old_next_rent_due_day := next_rent_due_day
	credits -= move_in_cost
	current_residence_id = id
	rent_status = &"current"
	rent_due_amount = 0
	next_rent_due_day = day + 30
	_emit_housing_changes(old_residence, old_rent_status, old_rent_amount, old_next_rent_due_day)

	_housing_feedback("MOVED // " + residence.name.to_upper(),
		"Residence changed to %s." % residence.name)
	save_profile()
	return true

func buy_out_current_residence() -> bool:
	const STUDIO_ID := &"lower_vesper_studio"
	const BUYOUT_COST := 150000
	if active_contract_id != &"" or current_residence_id != STUDIO_ID \
			or _is_owned(STUDIO_ID) or rent_status != &"current" or credits < BUYOUT_COST:
		return false
	credits -= BUYOUT_COST
	owned_residence_ids.append(STUDIO_ID)
	rent_status = &"current"
	rent_due_amount = 0
	next_rent_due_day = day + 30
	rent_changed.emit(rent_status, rent_due_amount, next_rent_due_day)
	_housing_feedback("STUDIO BUYOUT // %s CR" % format_credits(BUYOUT_COST),
		"Lower Vesper Studio is now owned and rent-free.")
	save_profile()
	return true

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

func is_contract_available(contract: Dictionary) -> bool:
	return contract.is_playable and contract.status == &"available" \
		and standing_for(contract.contact_id) >= int(contract.minimum_contact_standing)

func accept_contract(id: StringName) -> bool:
	var index := _contract_index(id)
	if index < 0 or active_contract_id != &"":
		return false
	var contract: Dictionary = contracts[index]
	if not is_contract_available(contract) or contract.phase != &"offer":
		return false
	contract.status = &"active"
	contract.phase = &"ready_to_proceed"
	active_contract_id = id
	contracts_changed.emit()
	push_ticker("CONTRACT ACCEPTED // " + contract.code, true)
	_add_message("MARA", contract.accept_message)
	contract_accepted.emit(id)
	save_profile()
	return true

func proceed_contract(id: StringName) -> bool:
	var index := _contract_index(id)
	if index < 0 or active_contract_id != id:
		return false
	var contract: Dictionary = contracts[index]
	if contract.status != &"active" or contract.phase != &"ready_to_proceed":
		return false
	_advance_minutes(contract.proceed_minutes)
	contract.phase = &"customs_hold"
	contracts_changed.emit()
	push_ticker(contract.complication.title, true)
	_add_message("MARA", contract.proceed_message)
	contract_proceeded.emit(id)
	save_profile()
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
		_add_credits(choice.credit_delta)
	if choice.heat_delta != 0:
		heat += choice.heat_delta
	if choice.contact_standing_delta > 0:
		_raise_contact_standing(contract.contact_id, int(choice.contact_standing_delta))
	if choice.get("sets_mara_favor_owed", false):
		mara_favor_owed = true
	if choice.get("clears_mara_favor", false):
		mara_favor_owed = false
	_unlock_contracts(choice.unlocks_contract_ids)
	contract.status = choice.terminal_status
	contract.phase = &"resolved"
	contract.resolution_id = choice_id
	active_contract_id = &""
	contracts_changed.emit()
	_push_resolution_feedback(choice)
	contract_resolved.emit(id, contract.status)
	save_profile()
	return true

func _unlock_contracts(ids: Array) -> void:
	for id: Variant in ids:
		var index := _contract_index(StringName(str(id)))
		if index >= 0:
			contracts[index].is_playable = true

func _push_resolution_feedback(choice: Dictionary) -> void:
	push_ticker(choice.ticker, true)
	_add_message(choice.message_sender, choice.message_preview)

func set_workspace_collapsed(collapsed: bool) -> void:
	if workspace_collapsed == collapsed:
		return
	workspace_collapsed = collapsed
	workspace_collapsed_changed.emit(collapsed)
	save_profile()

func set_active_module(id: StringName) -> void:
	if active_module == id:
		return
	active_module = id
	active_module_changed.emit(id)
	save_profile()

func set_module_open(open: bool) -> void:
	if module_open == open:
		return
	module_open = open
	module_open_changed.emit(open)
	save_profile()

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
