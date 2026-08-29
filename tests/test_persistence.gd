extends "res://tests/test_base.gd"

const GameStateScript := preload("res://autoload/game_state.gd")
const ResidenceCatalogScript := preload("res://data/housing/residence_catalog.gd")
const SAVE_PATH := "user://operator_save.json"

func _run() -> void:
	var catalog := ResidenceCatalogScript.all()
	check(catalog.size() == 2, "catalog has Studio and Loft")
	check(catalog[0].id == &"lower_vesper_studio"
		and catalog[0].name == "Lower Vesper Studio"
		and catalog[0].artwork_path == "res://assets/tier-1-appartment.png"
		and catalog[0].monthly_rent == 2000
		and catalog[0].move_in_cost == 0
		and catalog[0].buyout_cost == 150000,
		"Studio catalog record matches design")
	check(catalog[1].id == &"sector_9_loft"
		and catalog[1].name == "Sector 9 Loft"
		and catalog[1].artwork_path == "res://assets/tier-2-appartment-update.png"
		and catalog[1].monthly_rent == 6000
		and catalog[1].move_in_cost == 8000
		and catalog[1].buyout_cost == 0,
		"Loft catalog record matches design")

	var clean := GameStateScript.new()
	clean.reset_profile()
	check(clean.current_residence_id == &"lower_vesper_studio"
		and clean.next_rent_due_day == 30
		and clean.rent_due_amount == 0
		and clean.rent_status == &"current"
		and clean.owned_residence_ids.is_empty(),
		"clean state starts in the Studio with current Day 30 rent and no ownership")

	clean.credits = 98765
	clean.district = "SECTOR 9"
	clean.day = 27
	clean.minute_of_day = 321
	clean.heat = 6
	clean.alerts = 4
	clean.workspace_collapsed = true
	clean.active_module = &"contracts"
	clean.module_open = true
	clean.current_residence_id = &"sector_9_loft"
	clean.owned_residence_ids = [&"lower_vesper_studio"]
	clean.next_rent_due_day = 57
	clean.rent_due_amount = 6000
	clean.rent_status = &"due"
	clean.mara_favor_owed = true
	clean.messages.append({"id": &"msg_saved", "sender": "TEST", "preview": "saved", "unread": false})
	check(clean.accept_contract(&"cold_chain_delivery"), "contract mutation setup succeeds")
	check(clean.save_profile(), "profile saves")

	var restored := GameStateScript.new()
	check(restored.load_profile(), "profile loads")
	check(restored.credits == 98765 and restored.district == "SECTOR 9"
		and restored.day == 27 and restored.minute_of_day == 321
		and restored.heat == 6 and restored.alerts == 4,
		"scalar gameplay fields restore")
	check(restored.workspace_collapsed and restored.active_module == &"contracts"
		and restored.module_open and restored.mara_favor_owed,
		"workspace, module, and favor state restore")
	check(restored.current_residence_id == &"sector_9_loft"
		and restored.owned_residence_ids == [&"lower_vesper_studio"]
		and restored.next_rent_due_day == 57
		and restored.rent_due_amount == 6000
		and restored.rent_status == &"due",
		"housing fields restore")
	check(restored.messages.any(func(message: Dictionary) -> bool:
		return message.id == &"msg_saved" and message.preview == "saved"),
		"messages restore")
	check(restored.active_contract_id == &"cold_chain_delivery"
		and restored.get_contract(&"cold_chain_delivery").status == &"active"
		and restored.get_contract(&"cold_chain_delivery").phase == &"ready_to_proceed",
		"active contract record restores")

	var malformed := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	malformed.store_string("{ definitely not JSON")
	malformed.close()
	var recovered := GameStateScript.new()
	check(not recovered.load_profile(), "malformed profile is rejected")
	check(recovered.credits == recovered.START_CREDITS
		and recovered.day == recovered.START_DAY
		and recovered.current_residence_id == &"lower_vesper_studio"
		and recovered.next_rent_due_day == 30
		and recovered.rent_due_amount == 0
		and recovered.rent_status == &"current"
		and recovered.owned_residence_ids.is_empty()
		and recovered.active_contract_id == &""
		and recovered.get_contract(&"cold_chain_delivery").status == &"available",
		"malformed profile recovers to clean playable state")
	recovered.reset_profile()
	clean.free()
	restored.free()
	recovered.free()
