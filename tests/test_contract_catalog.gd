extends "res://tests/test_base.gd"

const ContractCatalog := preload("res://data/contracts/contract_catalog.gd")

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
