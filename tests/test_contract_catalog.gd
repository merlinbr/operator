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
	for choice: Dictionary in delivery.complication.choices:
		check(choice.has("preview") and not choice.preview.is_empty(),
			"each Customs choice has an authored consequence preview")
		check(choice.has("result") and not choice.result.is_empty(),
			"each Customs choice has an authored operational result")

	check(not contracts[1].is_playable and not contracts[2].is_playable,
		"other catalog offers start unavailable")
	contracts[0].status = &"completed"
	check(ContractCatalog.all()[0].status == &"available",
		"each catalog request returns fresh runtime records")
