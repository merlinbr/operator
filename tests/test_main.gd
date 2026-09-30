extends "res://tests/test_base.gd"

const GameStateScript := preload("res://autoload/game_state.gd")
const MainScene := preload("res://scenes/main/main.tscn")
const StudioTexture := preload("res://assets/tier-1-appartment.png")
const LoftTexture := preload("res://assets/tier-2-appartment-update.png")

var _main: Control
var _environment: Control
var _gs: Node

func _init() -> void:
	_run()
	call_deferred("_finish_after_ready")

func _finish_after_ready() -> void:
	var ambience := _main.get_node_or_null("Ambience") as AudioStreamPlayer
	check(ambience != null and ambience.bus == &"Ambience" and ambience.playing,
		"Main owns one playing ambience loop")
	check(_environment.get_child_count() == 4, "environment has four visual layers")
	var background := _environment.get_node("ApartmentBackground") as TextureRect
	check(background.texture == StudioTexture,
		"Main starts EnvironmentLayer on Studio artwork")
	_gs.current_residence_id = &"sector_9_loft"
	_gs.residence_changed.emit(_gs.current_residence_id)
	check(background.texture == LoftTexture
		and _environment._art_profile == _environment.ART_PROFILES[&"sector_9_loft"],
		"Main-injected GameState selects Loft artwork through residence_changed")
	_gs.current_residence_id = &"lower_vesper_studio"
	_gs.residence_changed.emit(_gs.current_residence_id)
	check(background.texture == StudioTexture,
		"Main-injected GameState can restore Studio artwork")
	_main.queue_free()
	_gs.queue_free()
	finish()

func _run() -> void:
	_check_restored_workspace(&"dossier", false, false, &"dossier", false)
	_check_restored_workspace(&"dossier", true, true, &"dossier", true)
	_check_restored_workspace(&"missing", false, false, &"home", true)
	_check_restored_workspace(&"crew", false, false, &"home", true)
	var gs := GameStateScript.new()
	gs.name = "GameState"
	gs.active_module = &"dossier"
	gs.module_open = true
	root.add_child(gs)

	var main := MainScene.instantiate()
	root.add_child(main)
	_main = main
	_gs = gs
	check(gs.active_module == &"dossier" and gs.module_open
		and main.primary_host.visible,
		"startup restores saved Dossier without toggling it closed")
	if gs.active_module != &"home":
		main.select_module(&"home")

	var workspace: Control = main.get_node("Workspace")
	var environment: Control = main.get_node("EnvironmentLayer")
	_environment = environment
	var ambience := main.get_node_or_null("Ambience") as AudioStreamPlayer
	var contract_sfx := main.get_node_or_null("ContractSfx") as AudioStreamPlayer
	check(ambience != null and ambience.bus == &"Ambience",
		"Main owns the ambience player")
	check(contract_sfx != null and contract_sfx.bus == &"SFX",
		"Main owns the contract SFX player")
	check(is_equal_approx(contract_sfx.volume_db, linear_to_db(0.25)),
		"contract SFX uses quarter gain after second reduction")
	check(environment._gs == gs and environment._time_band == &"night",
		"Main injects GameState and Environment applies the initial night band")
	check(main.get_children().find(environment) < main.get_children().find(workspace),
		"environment renders before workspace UI")
	var primary: Control = workspace.get_node("PrimaryHost")
	var context: Control = workspace.get_node("ContextHost")
	var rail: Control = workspace.get_node("IconRail")
	var chip: Control = workspace.get_node("StatusChip")
	check(rail.call("get_button", &"alerts") == null, "Alerts button is absent from the rail")

	check(main.theme != null, "theme applied at Main root")
	check(primary.get_child_count() == 1, "home panel active on start")
	var home_panel: Control = primary.get_child(0)
	gs.current_residence_id = &"lower_vesper_studio"
	gs.owned_residence_ids = []
	gs.rent_status = &"current"
	gs.rent_due_amount = 0
	gs.credits = gs.START_CREDITS
	gs.active_contract_id = &""
	home_panel.refresh()
	var compact_primary_height := primary.size.y
	var home_move_button := home_panel.find_child("MoveButton", true, false) as Button
	home_move_button.pressed.emit()
	var confirm_move := home_panel.find_child("ConfirmMoveButton", true, false) as Button
	check(confirm_move != null and confirm_move.visible, "move confirmation opens")
	check(primary.size.y > compact_primary_height,
		"primary panel expands when Home confirmation opens")
	var required_home_height := home_panel.get_combined_minimum_size().y
	check(primary.size.y >= required_home_height,
		"primary panel expands to fit the active Home content")
	check(confirm_move.get_global_rect().end.y <= primary.get_global_rect().end.y + 1.0,
		"move confirmation fits inside the primary panel")
	var cancel_move := home_panel.find_child("CancelResidenceButton", true, false) as Button
	cancel_move.pressed.emit()
	check(primary.visible, "home panel visible on start")
	check(gs.active_module == &"home", "active module is home")
	check(gs.module_open, "module starts open")
	var initial_module: StringName = gs.active_module
	var initial_open: bool = gs.module_open
	gs.minute_of_day = 180
	gs.clock_changed.emit(gs.day, gs.minute_of_day)
	check(environment._time_band == &"pre_dawn"
		and gs.active_module == initial_module and gs.module_open == initial_open
		and primary.visible,
		"clock updates change atmosphere without changing workspace state")
	if environment._atmosphere_tween != null:
		environment._atmosphere_tween.kill()
	gs.minute_of_day = gs.START_MINUTE
	gs.day = gs.START_DAY
	gs.clock_changed.emit(gs.day, gs.minute_of_day)
	if environment._atmosphere_tween != null:
		environment._atmosphere_tween.kill()
	var ws: Vector2 = workspace.size if workspace.size.x > 0 else Vector2(1920, 1080)
	check(primary.size.x < ws.x * 0.5, "home width is compact")
	check(primary.size.y < ws.y * 0.6, "home height is compact")
	check(absf(primary.position.y - rail.position.y) <= 0.1,
		"primary top aligns with first rail module")
	check(absf(primary.position.x - (rail.position.x + rail.size.x + main.RAIL_GAP)) <= 0.1,
		"primary uses fixed gutter from rail")
	check(absf(rail.position.y - (main.CHIP_TOP + chip.size.y + main.CHIP_GAP)) <= 0.1,
		"rail keeps shared gap below status HUD")
	# active icon toggles its module closed
	main.select_module(&"home")
	check(not primary.visible, "active icon toggles panel closed")
	check(gs.module_open == false, "module_open false after toggle")
	check(gs.workspace_collapsed == false, "toggle-close does not collapse workspace")
	check(gs.active_module == &"home", "active_module stays set while closed")

	# clicking the same (closed) active reopens it
	main.select_module(&"home")
	check(primary.visible and gs.module_open, "clicking closed active reopens it")

	# different icon switches modules
	main.select_module(&"contracts")
	check(primary.get_child(0).name == "ContractsPanel", "module switching swaps panel")
	check(gs.active_module == &"contracts", "active module is contracts")

	# selecting C-1042 opens detail beside the unchanged contract network
	var c1042_row := _button(primary, "COLD-CHAIN DELIVERY   1,400 CR")
	check(c1042_row != null, "C-1042 row is available")
	c1042_row.pressed.emit()
	check(primary.get_child(0).name == "ContractsPanel", "contract network remains in primary")
	check(context.get_child_count() == 1 and context.get_child(0).name == "ContractDetail",
		"C-1042 opens ContractDetail in context")

	# shared context closure also drops the transient selection
	main.close_topmost()
	check(not context.visible and main._selected_contract_id == &"",
		"Esc clears the selected contract with its context")
	c1042_row.pressed.emit()
	rail.get_button(&"dossier").pressed.emit()
	check(gs.active_module == &"dossier" and gs.module_open and primary.visible
		and not context.visible and context.get_child_count() == 0,
		"Dossier switch closes the previous contract context")
	main.close_topmost()
	check(not gs.module_open and not primary.visible and gs.active_module == &"dossier",
		"close hides Dossier without changing its selected module")
	rail.get_button(&"dossier").pressed.emit()
	check(gs.module_open and primary.visible, "Dossier reopens through its rail button")
	main.select_module(&"contracts")

	# a separate offer run proves CLOSE is non-mutating
	c1042_row = _button(primary, "COLD-CHAIN DELIVERY   1,400 CR")
	c1042_row.pressed.emit()
	check(context.get_child_count() == 1, "fresh C-1042 selection opens context")

	# closing an offer is non-mutating

	_button(context, "CLOSE").pressed.emit()
	check(gs.get_contract(&"cold_chain_delivery").status == &"available",
		"CLOSE leaves the offer available")

	# a fresh selection drives the accepted, proceeded, and aborted paths
	_button(primary, "COLD-CHAIN DELIVERY   1,400 CR").pressed.emit()
	_button(context, "ACCEPT").pressed.emit()
	check(contract_sfx.stream.resource_path == "res://assets/audio/ui/contract_accepted.ogg",
		"accept maps to its SFX")
	contract_sfx.stop()
	gs.contracts_changed.emit()
	check(not contract_sfx.playing
		and contract_sfx.stream.resource_path == "res://assets/audio/ui/contract_accepted.ogg",
		"accept cue is not replayed by refresh")
	check(_button(context, "PROCEED TO DOCK 17") != null,
		"ACCEPT refreshes detail to proceed")
	var delivery: Dictionary = gs.get_contract(&"cold_chain_delivery")
	var warning_minute: int = delivery.deadline_at_minute - int(delivery.proceed_minutes)
	gs.day = warning_minute / 1440 + 1
	gs.minute_of_day = warning_minute % 1440
	gs.clock_changed.emit(gs.day, gs.minute_of_day)
	check(_text(context).contains("WARNING")
		and _button(context, "PROCEED TO DOCK 17") != null,
		"clock refreshes the selected detail with late-arrival risk")
	gs.day = gs.START_DAY
	gs.minute_of_day = gs.START_MINUTE
	gs.clock_changed.emit(gs.day, gs.minute_of_day)
	_button(context, "PROCEED TO DOCK 17").pressed.emit()
	check(contract_sfx.stream.resource_path == "res://assets/audio/ui/contract_proceeded.ogg",
		"proceed maps to its SFX")
	contract_sfx.stop()
	gs.contracts_changed.emit()
	check(not contract_sfx.playing
		and contract_sfx.stream.resource_path == "res://assets/audio/ui/contract_proceeded.ogg",
		"proceed cue is not replayed by refresh")
	check(gs.day == 15, "PROCEED advances to day 15")
	check(_button(context, "ABORT DELIVERY") != null,
		"PROCEED refreshes detail to customs choices")
	_button(context, "ABORT DELIVERY").pressed.emit()
	check(contract_sfx.stream.resource_path == "res://assets/audio/ui/contract_failed.ogg",
		"failed resolution maps to its SFX")
	contract_sfx.stop()
	gs.contracts_changed.emit()
	check(not contract_sfx.playing
		and contract_sfx.stream.resource_path == "res://assets/audio/ui/contract_failed.ogg",
		"failed cue is not replayed by refresh")
	var completed_root := Node.new()
	root.add_child(completed_root)
	var completed_gs := GameStateScript.new()
	completed_gs.name = "GameState"
	completed_root.add_child(completed_gs)
	var completed_main := MainScene.instantiate()
	completed_root.add_child(completed_main)
	var completed_sfx := completed_main.get_node("ContractSfx") as AudioStreamPlayer
	var completed_primary: Control = completed_main.get_node("Workspace/PrimaryHost")
	var completed_context: Control = completed_main.get_node("Workspace/ContextHost")
	completed_main.select_module(&"contracts")
	_button(completed_primary, "COLD-CHAIN DELIVERY   1,400 CR").pressed.emit()
	_button(completed_context, "ACCEPT").pressed.emit()
	_button(completed_context, "PROCEED TO DOCK 17").pressed.emit()
	_button(completed_context, "PAY CLEARANCE FEE // 250 CR").pressed.emit()
	check(completed_sfx.stream.resource_path == "res://assets/audio/ui/contract_completed.ogg",
		"completed resolution maps to its SFX")
	completed_sfx.stop()
	completed_gs.contracts_changed.emit()
	check(not completed_sfx.playing
		and completed_sfx.stream.resource_path == "res://assets/audio/ui/contract_completed.ogg",
		"completed cue is not replayed by refresh")
	completed_root.queue_free()
	var failed_row := _button(primary, "FAILED // COLD-CHAIN DELIVERY")
	check(failed_row != null and failed_row.disabled, "ABORT disables the failed C-1042 row")
	check(_button(context, "ACKNOWLEDGE") != null, "failed detail shows ACKNOWLEDGE")
	_button(context, "ACKNOWLEDGE").pressed.emit()
	check(context.get_child_count() == 0 and not context.visible,
		"ACKNOWLEDGE closes the contract context")
	check(primary.visible and primary.get_child(0).name == "ContractsPanel",
		"ACKNOWLEDGE leaves Contract Network open")

	var d207_row := _button(primary, "DATA RETRIEVAL   4,200 CR")
	check(d207_row != null and not d207_row.disabled,
		"C-1042 resolution enables D-207 in the refreshed network")
	d207_row.pressed.emit()
	check(_button(context, "ACCEPT") != null, "D-207 opens its offer detail")
	_button(context, "ACCEPT").pressed.emit()
	check(_button(context, "PROCEED TO TRANSIT EXCHANGE") != null,
		"D-207 accept renders its destination action")
	_button(context, "PROCEED TO TRANSIT EXCHANGE").pressed.emit()
	check(_button(context, "ABORT RETRIEVAL") != null,
		"D-207 proceed renders its authored interruption")
	_button(context, "ABORT RETRIEVAL").pressed.emit()
	check(_button(primary, "FAILED // DATA RETRIEVAL") != null,
		"D-207 failure refreshes its terminal network row")
	_button(context, "ACKNOWLEDGE").pressed.emit()

	var r311_row := _button(primary, "CLINIC ASSET RECOVERY   3,200 CR")
	check(r311_row != null and not r311_row.disabled,
		"D-207 resolution enables R-311 despite failure")
	r311_row.pressed.emit()
	_button(context, "ACCEPT").pressed.emit()
	check(_button(context, "PROCEED TO MEDICAL SUBLEVEL") != null,
		"R-311 accepts and uses its destination action")
	_button(context, "PROCEED TO MEDICAL SUBLEVEL").pressed.emit()
	check(_button(context, "ABORT RECOVERY") != null,
		"R-311 proceed renders its authored interruption")
	_button(context, "ABORT RECOVERY").pressed.emit()
	check(_button(primary, "FAILED // CLINIC ASSET RECOVERY") != null,
		"R-311 resolution refreshes its terminal network row")
	_button(context, "ACKNOWLEDGE").pressed.emit()
	check(context.get_child_count() == 0 and primary.visible,
		"final acknowledgement closes only detail and leaves the network open")

	# context opens alongside primary (primary keeps its class width)
	var primary_w: float = primary.size.x
	main.open_context(load("res://scenes/modules/contracts/contract_detail.tscn").instantiate())
	check(context.visible and context.get_child_count() == 1, "context opens with content")
	check(absf(context.position.y - rail.position.y) <= 0.1,
		"context top aligns with first rail module")
	check(absf(primary.size.x - primary_w) < 1.0, "primary keeps class width when context opens")
	check(primary.position.x + primary.size.x + main.CONTEXT_GAP + context.size.x < ws.x,
		"environment remains visible to the right of panels")

	# Esc closes context first
	main.close_topmost()
	check(not context.visible, "Esc closes context first")

	# Esc closes primary next
	main.close_topmost()
	check(not primary.visible and gs.module_open == false, "Esc closes primary next")

	# Esc does nothing when nothing is open
	main.close_topmost()
	check(not primary.visible, "Esc does nothing when nothing is open")

	# global collapse hides all panels; chrome survives
	gs.set_workspace_collapsed(true)
	check(not primary.visible, "collapse hides primary panel")
	check(not context.visible, "collapse hides context panel")
	check(workspace.get_node("StatusChip").visible, "chip survives collapse")
	check(workspace.get_node("IconRail").visible, "rail survives collapse")
	check(workspace.get_node("TickerBar").visible, "ticker survives collapse")

	# expand preserves module_open state
	gs.set_workspace_collapsed(false)
	check(not primary.visible, "expand does not reopen a closed module")
	check(gs.module_open == false, "expand preserves module_open")

	# selecting a module while collapsed un-collapses and opens that module
	main.select_module(&"comms")
	check(not gs.workspace_collapsed, "selecting a module un-collapses")
	check(primary.visible and primary.get_child(0).name == "CommsPanel", "comms open after un-collapse")
	gs.add_message("SYSTEM", "Surveillance pressure is elevated.")
	check(gs.active_module == &"comms" and _text(primary).contains("Surveillance pressure is elevated."),
		"open Comms refreshes when a new message arrives")
	check(gs.module_open, "module open after un-collapse")

	var status_chip: Control = workspace.get_node("StatusChip")
	var action: Button = status_chip.find_child("WorkspaceAction", true, false) as Button
	check(action != null, "integrated workspace action exists")
	check(workspace.get_node_or_null("CollapseToggle") == null, "legacy collapse toggle removed")
	check(action.text == "COLLAPSE ▲", "expanded workspace action label")
	action.pressed.emit()
	check(gs.workspace_collapsed, "workspace action collapses workspace")
	check(action.text == "EXPAND ▼", "collapsed workspace action label")
	action.pressed.emit()
	check(not gs.workspace_collapsed, "workspace action expands workspace")
	check(action.text == "COLLAPSE ▲", "expanded workspace action label restored")
	check(status_chip.size.x > status_chip.size.y, "status HUD is wider than tall")
	check(absf(status_chip.position.x - (ws.x - status_chip.size.x) * 0.5) <= 1.0,
		"status HUD is horizontally centered")
	gs.reset_profile()
	main.select_module(&"home")
	gs.day = 29
	gs.minute_of_day = 1439
	gs.heat = 4
	gs.contracts[0].deadline_at_minute = gs.current_minute() + 720
	var recovery_minute: int = gs.current_minute()
	gs.clock_changed.emit(gs.day, gs.minute_of_day)
	var recovery_home: Control = primary.get_child(0)
	var ground_button := _button(recovery_home, "GO TO GROUND // 24 HOURS // HEAT -1")
	check(ground_button != null, "Main Home wires the Go to Ground action")
	if ground_button != null:
		ground_button.pressed.emit()
	check(gs.current_minute() == recovery_minute + 1440 and gs.heat == 3
		and gs.credits == gs.START_CREDITS - 2000
		and gs.rent_status == &"current"
		and gs.get_contract(&"cold_chain_delivery").status == &"expired",
		"Home action advances time, settles rent and deadline, then lowers Heat")
	check(_text(recovery_home).contains("HEAT       3 // ELEVATED"),
		"Main refreshes Home after Go to Ground")
	var legacy_root := Node.new()
	root.add_child(legacy_root)
	var legacy_gs := GameStateScript.new()
	legacy_gs.name = "GameState"
	legacy_root.add_child(legacy_gs)
	var legacy_payload: Dictionary = legacy_gs._profile_payload()
	legacy_payload.active_module = &"alerts"
	legacy_payload.module_open = true
	legacy_gs._apply_profile(legacy_payload)
	var legacy_main := MainScene.instantiate()
	legacy_root.add_child(legacy_main)
	var legacy_primary: Control = legacy_main.get_node("Workspace/PrimaryHost")
	check(legacy_gs.active_module == &"home" and legacy_gs.module_open
		and legacy_primary.visible and legacy_primary.get_child_count() == 1
		and legacy_primary.get_child(0).name == "HomePanel",
		"legacy open Alerts profile starts with a visible Home panel")
	legacy_main.select_module(&"home")
	check(not legacy_gs.module_open and not legacy_primary.visible,
		"clicking the loaded Home icon still toggles its panel closed")
	legacy_root.queue_free()
	gs.reset_profile()


func _check_restored_workspace(id: StringName, open: bool, collapsed: bool,
		expected_id: StringName, expected_open: bool) -> void:
	var holder := Node.new()
	root.add_child(holder)
	var state := GameStateScript.new()
	state.name = "GameState"
	state.active_module = id
	state.module_open = open
	state.workspace_collapsed = collapsed
	holder.add_child(state)
	var shell := MainScene.instantiate()
	holder.add_child(shell)
	check(state.active_module == expected_id and state.module_open == expected_open
		and state.workspace_collapsed == collapsed
		and shell.primary_host.visible == (expected_open and not collapsed),
		"startup preserves workspace flags or falls back for %s" % id)
	holder.free()

func _button(control: Control, text: String) -> Button:
	for button: Button in control.find_children("*", "Button", true, false):
		if button.text == text:
			return button
	return null

func _text(control: Control) -> String:
	var out := ""
	for label: Label in control.find_children("*", "Label", true, false):
		out += label.text + "\n"
	return out
