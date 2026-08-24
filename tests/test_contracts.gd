extends "res://tests/test_base.gd"

const GameStateScript := preload("res://autoload/game_state.gd")
const ContractsPanel := preload("res://scenes/modules/contracts/contracts_panel.tscn")
const ContractDetail := preload("res://scenes/modules/contracts/contract_detail.tscn")
const PlaceholderContracts := preload("res://data/placeholder/placeholder_contracts.gd")

func _run() -> void:
	var gs := GameStateScript.new()
	gs.name = "GameState"
	root.add_child(gs)

	var panel := ContractsPanel.instantiate()
	root.add_child(panel)

	var seen := [{}]
	panel.contract_selected.connect(func(c: Dictionary) -> void: seen[0] = c)
	panel.setup(gs, PlaceholderContracts.all())

	var buttons: Array[Button] = []
	for child in panel.find_children("*", "Button", true, false):
		buttons.append(child)
	check(buttons.size() == 3, "three contract rows")
	check(buttons[0].text.contains("Freight Transfer") and buttons[0].text.contains("1,400 CR"),
		"row text with formatted reward")
	check(buttons[2].text.contains("[ENCRYPTED OFFER]") and buttons[2].text.contains("?????"),
		"encrypted row hides reward")

	buttons[1].pressed.emit()
	check(seen[0].get("id", &"") == &"data_retrieval", "selecting row emits contract")
	buttons[2].pressed.emit()
	check(seen[0].get("id", &"") == &"data_retrieval", "encrypted row does not emit")
	panel.queue_free()

	var detail := ContractDetail.instantiate()
	root.add_child(detail)
	detail.setup(gs, PlaceholderContracts.all()[1])
	var detail_text := ""
	for label in detail.find_children("*", "Label", true, false):
		detail_text += label.text + "\n"
	check(detail_text.contains("Data Retrieval"), "detail title")
	check(detail_text.contains("4,200 CR") and detail_text.contains("SECTOR 9"), "detail body fields")
	detail.setup(gs, PlaceholderContracts.all()[2])
	var enc_text := ""
	for label in detail.find_children("*", "Label", true, false):
		enc_text += label.text + "\n"
	check(enc_text.contains("?????") and enc_text.contains("ENCRYPTED"), "encrypted detail redacted")
	detail.queue_free()
	gs.queue_free()
