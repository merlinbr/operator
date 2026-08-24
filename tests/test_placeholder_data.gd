extends "res://tests/test_base.gd"

const Contracts := preload("res://data/placeholder/placeholder_contracts.gd")
const Messages := preload("res://data/placeholder/placeholder_messages.gd")

func _run() -> void:
	var contracts := Contracts.all()
	check(contracts.size() == 3, "3 placeholder contracts")
	check(contracts[0].id == &"freight_transfer" and contracts[0].reward_credits == 1400, "freight transfer 1400")
	check(contracts[1].reward_credits == 4200, "data retrieval 4200")
	check(contracts[2].encrypted == true, "third contract is encrypted")
	for c: Dictionary in contracts:
		check(c.has_all(["id", "title", "client", "reward_credits", "risk", "district", "encrypted"]),
			"contract %s has all keys" % [c.id])

	var messages := Messages.all()
	check(messages.size() == 3, "3 placeholder messages")
	check(messages[0].sender == "MARA" and messages[0].unread, "MARA unread first")
	var unread_count := 0
	for m: Dictionary in messages:
		if m.unread:
			unread_count += 1
	check(unread_count == 2, "two unread messages")
