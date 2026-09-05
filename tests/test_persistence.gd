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
	clean.contracts[0].deadline_at_minute = clean.current_minute() + int(clean.contracts[0].deadline_window_minutes)
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
	_test_deadline_round_trip()
	_test_legacy_deadline_migration(1)
	_test_legacy_deadline_migration(2)
	_test_overdue_deadline_load()
	_test_invalid_deadline_profile()

func _write_deadline_profile(payload: Dictionary) -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	check(file != null, "deadline save fixture opens")
	if file == null:
		return
	file.store_string(JSON.stringify(payload))
	file.close()

func _test_deadline_round_trip() -> void:
	var gs := GameStateScript.new()
	gs.reset_profile()
	var original_due: int = gs.get_contract(&"cold_chain_delivery").deadline_at_minute
	gs.advance_minutes(30)
	check(gs.accept_contract(&"cold_chain_delivery"), "deadline round-trip accepts on time")
	var restored := GameStateScript.new()
	check(restored.load_profile(), "version-3 active profile loads")
	check(restored.get_contract(&"cold_chain_delivery").deadline_at_minute == original_due,
		"load retains remaining time rather than assigning a new window")
	restored.advance_minutes(original_due - restored.current_minute())
	var again := GameStateScript.new()
	check(again.load_profile()
		and again.get_contract(&"cold_chain_delivery").resolution_id == &"deadline_missed"
		and again.get_contract(&"cold_chain_delivery").status == &"failed"
		and again.active_contract_id == &"",
		"deadline failure round-trips without resurrection")
	again.reset_profile()
	gs.free()
	restored.free()
	again.free()

func _test_legacy_deadline_migration(version: int) -> void:
	var gs := GameStateScript.new()
	gs.reset_profile()
	check(gs.accept_contract(&"cold_chain_delivery"), "legacy fixture has an active job")
	var payload: Dictionary = gs._profile_payload()
	payload.version = version
	payload.day = 27
	payload.minute_of_day = 321
	payload.credits = 98765
	for c: Dictionary in payload.contracts:
		c.erase("deadline_at_minute")
	if version == 1:
		payload.erase("contact_standing")
		payload.contracts = payload.contracts.filter(func(c: Dictionary) -> bool:
			return c.id in [&"cold_chain_delivery", &"data_retrieval", &"clinic_asset_recovery"])
	_write_deadline_profile(payload)
	var restored := GameStateScript.new()
	check(restored.load_profile(), "legacy profile migrates through the load path")
	var c: Dictionary = restored.get_contract(&"cold_chain_delivery")
	check(restored.day == 27 and restored.minute_of_day == 321 and restored.credits == 98765
		and c.status == &"active" and c.deadline_at_minute == restored.current_minute() + c.deadline_window_minutes,
		"legacy job receives one full window without losing progress")
	var migrated_file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var persisted: Dictionary = JSON.parse_string(migrated_file.get_as_text())
	migrated_file.close()
	check(persisted.version == 3, "migration is persisted immediately")
	restored.advance_minutes(1)
	var again := GameStateScript.new()
	check(again.load_profile() and again.get_contract(&"cold_chain_delivery").deadline_at_minute == c.deadline_at_minute,
		"subsequent load does not renew the migrated window")
	again.reset_profile()
	gs.free()
	restored.free()
	again.free()

func _test_overdue_deadline_load() -> void:
	var gs := GameStateScript.new()
	gs.reset_profile()
	var due: int = gs.get_contract(&"cold_chain_delivery").deadline_at_minute
	var payload: Dictionary = gs._profile_payload()
	var saved_time: int = due + 361
	payload.day = saved_time / 1440 + 1
	payload.minute_of_day = saved_time % 1440
	_write_deadline_profile(payload)
	var restored := GameStateScript.new()
	check(restored.load_profile(), "valid overdue current-version profile loads")
	check(restored.current_minute() == saved_time and restored.credits == gs.credits
		and restored.get_contract(&"cold_chain_delivery").status == &"expired"
		and restored.get_contract(&"data_retrieval").status == &"expired",
		"load reconciles historical cutoffs without advancing the clock or charging rent")
	var count: int = restored.messages.size()
	var again := GameStateScript.new()
	check(again.load_profile() and again.messages.size() == count,
		"repeated load neither replays messages nor republishes successors")
	again.reset_profile()
	gs.free()
	restored.free()
	again.free()

func _test_invalid_deadline_profile() -> void:
	var gs := GameStateScript.new()
	gs.reset_profile()
	var payload: Dictionary = gs._profile_payload()
	payload.credits = 98765
	payload.contracts[0].deadline_at_minute = "tomorrow"
	_write_deadline_profile(payload)
	var restored := GameStateScript.new()
	check(not restored.load_profile() and restored.credits == restored.START_CREDITS,
		"malformed cutoff follows existing invalid-profile recovery")
	restored.reset_profile()
	payload = restored._profile_payload()
	payload.contracts[0].status = &"completed"
	payload.contracts[0].phase = &"resolved"
	payload.contracts[0].resolution_id = &"deadline_missed"
	_write_deadline_profile(payload)
	check(not restored.load_profile(), "deadline-missed cannot be a successful completion")
	restored.reset_profile()
	gs.free()
	restored.free()
