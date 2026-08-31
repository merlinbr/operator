extends "res://tests/test_base.gd"

const GameStateScript := preload("res://autoload/game_state.gd")
const HomePanel := preload("res://scenes/modules/home/home_panel.tscn")
const CommsPanel := preload("res://scenes/modules/comms/comms_panel.tscn")
const ContractsPanel := preload("res://scenes/modules/contracts/contracts_panel.tscn")

func _run() -> void:
	var native_buses := [&"Master", &"Ambience", &"SFX"]
	var original_volumes: Dictionary = {}
	var original_mutes: Dictionary = {}
	for bus_name in native_buses:
		var bus_index := AudioServer.get_bus_index(bus_name)
		if bus_index >= 0:
			original_volumes[bus_name] = AudioServer.get_bus_volume_db(bus_index)
			original_mutes[bus_name] = AudioServer.is_bus_mute(bus_index)
	var ambience_bus := AudioServer.get_bus_index(&"Ambience")
	var sfx_bus := AudioServer.get_bus_index(&"SFX")
	check(ambience_bus >= 0 and AudioServer.get_bus_send(ambience_bus) == &"Master",
		"Ambience bus routes to Master")
	check(sfx_bus >= 0 and AudioServer.get_bus_send(sfx_bus) == &"Master",
		"SFX bus routes to Master")
	var gs := GameStateScript.new()
	gs.name = "GameState"
	root.add_child(gs)

	var home := HomePanel.instantiate()
	root.add_child(home)
	home.setup(gs)
	var home_text := ""
	for label in home.find_children("*", "Label", true, false):
		home_text += label.text + "\n"
	check(home_text.contains("OPERATIONS TERMINAL v0.1"), "home title")
	check(home_text.contains("12,480 CR"), "home shows credits")
	check(home_text.contains("LOWER VESPER"), "home shows district")
	var master := home.find_child("MasterSlider", true, false) as HSlider
	var ambience := home.find_child("AmbienceSlider", true, false) as HSlider
	var sfx := home.find_child("SfxSlider", true, false) as HSlider
	var mute := home.find_child("MuteButton", true, false) as Button
	var master_value := home.find_child("MasterValue", true, false) as Label
	check(master != null and ambience != null and sfx != null and mute != null,
		"Home exposes all audio controls")
	check(master.value == 80.0 and ambience.value == 100.0 and sfx.value == 50.0,
		"Home applies authored session defaults")
	var residence_text := ""
	for label in home.find_children("*", "Label", true, false):
		residence_text += label.text + "\n"
	check(residence_text.contains("RESIDENCE") and residence_text.contains("LOWER VESPER STUDIO")
		and residence_text.contains("LEASED") and residence_text.contains("2,000 CR")
		and residence_text.contains("NEXT DUE") and residence_text.contains("DAY 30"),
		"Home shows the current leased residence and rent schedule")
	var rest := home.find_child("RestButton", true, false) as Button
	var pay_rent := home.find_child("PayRentButton", true, false) as Button
	var move := home.find_child("MoveButton", true, false) as Button
	var buyout := home.find_child("BuyoutButton", true, false) as Button
	var confirm := home.find_child("ConfirmResidenceButton", true, false) as Button
	var cancel := home.find_child("CancelResidenceButton", true, false) as Button
	var confirmation_box := home.find_child("ResidenceConfirmation", true, false) as VBoxContainer
	var confirmation := home.find_child("ResidenceConfirmLabel", true, false) as Label
	var requested_move := [&""]
	var requested_rest := [false]
	var requested_buyout := [false]
	home.move_requested.connect(func(id: StringName) -> void: requested_move[0] = id)
	home.rest_requested.connect(func() -> void: requested_rest[0] = true)
	home.buyout_requested.connect(func() -> void: requested_buyout[0] = true)
	check(rest != null and rest.text == "REST // ADVANCE TO DAY 15" and not rest.disabled,
		"REST advances to the next day while idle")
	check(pay_rent != null and not pay_rent.visible, "PAY RENT is hidden while rent is current")
	var credits_before_move := gs.credits
	var residence_before_move := gs.current_residence_id
	move.pressed.emit()
	check(confirmation.visible and confirmation.text.contains("CREDITS       12,480 CR")
		and confirmation.text.contains("EXACT COST    8,000 CR")
		and confirmation.text.contains("CURRENT RENT  2,000 CR / 30 DAYS")
		and confirmation.text.contains("RESULTING RENT 6,000 CR / 30 DAYS"),
		"Move confirmation shows exact Credits, cost, and rent transition")
	confirm.pressed.emit()
	check(requested_move[0] == &"sector_9_loft" and gs.credits == credits_before_move
		and gs.current_residence_id == residence_before_move,
		"Move confirmation emits intent without mutating GameState")
	rest.pressed.emit()
	check(requested_rest[0], "REST emits an intent signal")
	gs.active_contract_id = &"cold_chain_delivery"
	gs.contracts_changed.emit()
	check(rest.disabled, "REST is disabled during active work")
	gs.active_contract_id = &""
	gs.rent_status = &"due"
	gs.rent_due_amount = 2000
	gs.credits = 1000
	gs.rent_changed.emit(gs.rent_status, gs.rent_due_amount, gs.next_rent_due_day)
	check(not pay_rent.visible, "PAY RENT stays hidden when the due bill is unaffordable")
	gs.credits = 2000
	gs.rent_changed.emit(gs.rent_status, gs.rent_due_amount, gs.next_rent_due_day)
	check(pay_rent.visible, "PAY RENT appears when a due bill is funded")
	var requested_pay := [false]
	home.rent_payment_requested.connect(func() -> void: requested_pay[0] = true)
	pay_rent.pressed.emit()
	check(requested_pay[0] and gs.credits == 2000, "PAY RENT emits intent without mutating GameState")
	gs.rent_status = &"current"
	gs.rent_due_amount = 0
	gs.credits = 150000
	check(buyout != null and buyout.visible, "Studio buyout is offered when funded")
	buyout.pressed.emit()
	check(confirmation.visible and confirmation.text.contains("CREDITS       150,000 CR")
		and confirmation.text.contains("EXACT COST    150,000 CR")
		and confirmation.text.contains("CURRENT RENT  2,000 CR / 30 DAYS")
		and confirmation.text.contains("RESULTING RENT RENT FREE"),
		"Buyout confirmation shows exact Credits, cost, and rent transition")
	gs.credits = 149999
	gs.credits_changed.emit(gs.credits)
	confirm.pressed.emit()
	check(confirmation.visible and not requested_buyout[0],
		"Stale buyout confirmation emits no intent and remains open")
	cancel.pressed.emit()
	check(not confirmation_box.visible, "Residence confirmation can be cancelled")
	gs.credits = 150000
	gs.credits_changed.emit(gs.credits)
	buyout.pressed.emit()
	var credits_before_buyout := gs.credits
	confirm.pressed.emit()
	check(requested_buyout[0] and gs.credits == credits_before_buyout,
		"Buyout confirmation emits intent without mutating GameState")
	cancel.pressed.emit()
	gs.credits = 12480
	gs.rent_status = &"current"
	gs.rent_due_amount = 0
	gs.rent_changed.emit(gs.rent_status, gs.rent_due_amount, gs.next_rent_due_day)
	master.value = 35.0
	master.value_changed.emit(master.value)
	check(master_value.text == "35%" and not AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Master")),
		"Master slider exposes and applies its value")
	mute.pressed.emit()
	check(master.value == 0.0 and AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Master")),
		"Mute silences Master")
	mute.pressed.emit()
	check(master.value == 35.0 and not AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Master")),
		"Mute restores the prior Master value")
	gs.add_credits(1000)
	var refreshed_text := ""
	for label in home.find_children("*", "Label", true, false):
		refreshed_text += label.text + "\n"
	check(refreshed_text.contains("13,480 CR"), "home refreshes on credits change")
	home.queue_free()

	var comms := CommsPanel.instantiate()
	root.add_child(comms)
	comms.setup(gs, {"contacts": gs.contact_snapshot(), "messages": gs.messages})
	var rows := comms.find_children("Row*", "HBoxContainer", true, false)
	check(rows.size() == 3, "three message rows — got %d" % rows.size())
	var first_row_text := ""
	for label in rows[0].find_children("*", "Label", true, false):
		first_row_text += label.text + " "
	check(first_row_text.contains("●") and first_row_text.contains("MARA"), "unread marker and sender")
	var comms_text := ""
	for label in comms.find_children("*", "Label", true, false):
		comms_text += label.text + "\n"
	check(comms_text.contains("MARA // KNOWN") and comms_text.contains("VESPER CLINIC // COLD"),
		"COMMS renders the two visible Contact standings")
	var contracts := ContractsPanel.instantiate()
	root.add_child(contracts)
	gs.contracts[3].is_playable = true
	contracts.setup(gs, gs.contracts)
	var contract_text := ""
	for button: Button in contracts.find_children("*", "Button", true, false):
		contract_text += button.text + "\n"
	check(contract_text.contains("MARA // TRUSTED REQUIRED")
		and contract_text.contains("DATA RETRIEVAL   NETWORK OFFLINE"),
		"Contracts distinguishes standing requirements from unpublished work")
	contracts.queue_free()
	comms.queue_free()
	for bus_name in native_buses:
		var bus_index := AudioServer.get_bus_index(bus_name)
		if bus_index >= 0 and original_volumes.has(bus_name):
			AudioServer.set_bus_volume_db(bus_index, original_volumes[bus_name])
			AudioServer.set_bus_mute(bus_index, original_mutes[bus_name])
	gs.queue_free()
