extends "res://tests/test_base.gd"

const ContractCatalog := preload("res://data/contracts/contract_catalog.gd")
const ContactCatalog := preload("res://data/contacts/contact_catalog.gd")

func _run() -> void:
	var contracts := ContractCatalog.all()
	var contacts := ContactCatalog.all()
	check(contacts.map(func(contact: Dictionary) -> StringName: return contact.id)
		== [&"mara", &"vesper_clinic"]
		and ContactCatalog.by_id(&"mara").starting_standing == ContactCatalog.KNOWN
		and ContactCatalog.by_id(&"vesper_clinic").starting_standing == ContactCatalog.COLD
		and ContactCatalog.standing_label(ContactCatalog.TRUSTED) == "TRUSTED",
		"catalog owns the two visible Contacts and their standing labels")
	var expected_ids: Array[StringName] = [
		&"cold_chain_delivery",
		&"data_retrieval",
		&"dead_drop_audit",
		&"silent_partner",
		&"clinic_asset_recovery",
		&"dialysis_relay",
		&"quarantine_manifest",
	]
	var ids: Array[StringName] = []
	for contract: Dictionary in contracts:
		ids.append(contract.id)
	check(contracts.size() == 7 and ids == expected_ids,
		"catalog contains the authored seven-contract portfolio")

	var delivery: Dictionary = contracts[0]
	check(delivery.code == "C-1042" and delivery.is_playable
		and delivery.contact_id == &"mara" and delivery.minimum_contact_standing == 0,
		"C-1042 is Mara's published Cold-tier introduction")
	check(_successors(delivery) == [&"data_retrieval", &"dead_drop_audit"],
		"every C-1042 outcome publishes both Mara follow-ups")

	var data_retrieval: Dictionary = contracts[1]
	check(data_retrieval.code == "D-207" and not data_retrieval.is_playable
		and data_retrieval.contact_id == &"mara" and data_retrieval.minimum_contact_standing == 1,
		"D-207 is a locked Known-tier Mara contract")
	check(_choice(data_retrieval, &"spoof_credentials").max_heat == 3
		and _choice(data_retrieval, &"routed_vendor_id").min_heat == 4,
		"D-207 preserves its authored Heat-gated choices")
	check(_successors(data_retrieval) == [&"silent_partner", &"clinic_asset_recovery"],
		"every D-207 outcome publishes Mara and Clinic successors")

	var recovery: Dictionary = contracts[4]
	check(recovery.code == "R-311" and recovery.contact_id == &"vesper_clinic"
		and recovery.minimum_contact_standing == 0,
		"R-311 introduces the Cold-tier Vesper Clinic route")
	check(_choice(recovery, &"settle_mara_favor").requires_mara_favor
		and _choice(recovery, &"settle_mara_favor").clears_mara_favor,
		"R-311 preserves Mara's separate favor settlement")
	check(_successors(recovery) == [&"dialysis_relay"],
		"every R-311 outcome publishes the Known-tier Clinic follow-up")

	for contract: Dictionary in contracts:
		check(contract.has("contact_id") and contract.has("minimum_contact_standing")
			and [&"mara", &"vesper_clinic"].has(contract.contact_id)
			and int(contract.minimum_contact_standing) >= 0
			and int(contract.minimum_contact_standing) <= 2,
			"every contract has a valid Contact requirement")
		check(contract.deadline_window_minutes > contract.proceed_minutes,
			"a newly published job permits an on-time journey")
		check(not _choice(contract, &"abort").is_empty(),
			"every deadline outcome has an authored successor route")
		for choice: Dictionary in contract.complication.choices:
			check(choice.has("contact_standing_delta")
				and int(choice.contact_standing_delta) >= 0
				and int(choice.contact_standing_delta) <= 1,
				"every outcome has a one-way standing consequence")

	contracts[0].status = &"completed"
	check(ContractCatalog.all()[0].status == &"available",
		"each catalog request returns fresh runtime records")

func _choice(contract: Dictionary, choice_id: StringName) -> Dictionary:
	for choice: Dictionary in contract.complication.choices:
		if choice.id == choice_id:
			return choice
	return {}

func _successors(contract: Dictionary) -> Array[StringName]:
	var choices: Array = contract.complication.choices
	if choices.is_empty():
		return []
	var ids: Array[StringName] = []
	for id: StringName in choices[0].unlocks_contract_ids:
		ids.append(id)
	for choice: Dictionary in choices:
		if choice.unlocks_contract_ids != ids:
			return []
	return ids
