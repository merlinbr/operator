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
	var legacy: Dictionary = restored._profile_payload()
	legacy.version = 1
	legacy.erase("contact_standing")
	legacy.contracts = legacy.contracts.slice(0, 3)
	var migrated := restored._migrate_v1_profile(legacy)
	check(migrated.version == 2 and migrated.contracts.size() == 7
		and migrated.credits == restored.credits
		and migrated.contact_standing[&"mara"] == 1
		and migrated.contact_standing[&"vesper_clinic"] == 0,
		"version-1 profile migration preserves state and adds Contacts and contracts")
	var stable := GameStateScript.new()
	stable.credits = 24680
	check(stable.save_profile(), "stable profile saves before replacement failure")
	var backup_blocker_path := ProjectSettings.globalize_path(GameStateScript.PROFILE_BACKUP_PATH)
	var blocker_error := DirAccess.make_dir_absolute(backup_blocker_path)
	check(blocker_error == OK, "replacement failure setup blocks backup rename")
	check(not stable.save_profile(), "failed replacement reports false")
	var stable_recovered := GameStateScript.new()
	check(stable_recovered.load_profile() and stable_recovered.credits == 24680,
		"failed replacement preserves the prior profile")
	DirAccess.remove_absolute(backup_blocker_path)
	stable_recovered.reset_profile()
	stable_recovered.free()
	stable.free()

	var recovery_payload: Dictionary = restored._profile_payload()
	var temporary_profile := FileAccess.open(GameStateScript.PROFILE_TEMP_PATH, FileAccess.WRITE)
	temporary_profile.store_string(JSON.stringify(recovery_payload))
	temporary_profile.close()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	var temp_recovered := GameStateScript.new()
	check(temp_recovered.load_profile() and temp_recovered.credits == 98765
		and temp_recovered.current_residence_id == &"sector_9_loft",
		"interrupted replacement recovers a valid temporary profile")
	temp_recovered.reset_profile()
	temp_recovered.free()

	var backup_profile := FileAccess.open(GameStateScript.PROFILE_BACKUP_PATH, FileAccess.WRITE)
	backup_profile.store_string(JSON.stringify(recovery_payload))
	backup_profile.close()
	var backup_recovered := GameStateScript.new()
	check(backup_recovered.load_profile() and backup_recovered.credits == 98765
		and backup_recovered.current_residence_id == &"sector_9_loft",
		"interrupted replacement recovers a valid prior profile")
	backup_recovered.reset_profile()
	backup_recovered.free()

	var invalid_rent_payload: Dictionary = restored._profile_payload()
	invalid_rent_payload.rent_due_amount = 1
	var invalid_rent := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	invalid_rent.store_string(JSON.stringify(invalid_rent_payload))
	invalid_rent.close()
	var invalid_rent_recovered := GameStateScript.new()
	check(not invalid_rent_recovered.load_profile()
		and invalid_rent_recovered.current_residence_id == &"lower_vesper_studio"
		and invalid_rent_recovered.rent_status == &"current"
		and invalid_rent_recovered.rent_due_amount == 0
		and invalid_rent_recovered.owned_residence_ids.is_empty(),
		"one-credit rent bill is rejected and starts clean state")
	invalid_rent_recovered.free()

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
