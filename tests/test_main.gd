extends "res://tests/test_base.gd"

const GameStateScript := preload("res://autoload/game_state.gd")
const MainScene := preload("res://scenes/main/main.tscn")

func _run() -> void:
	var gs := GameStateScript.new()
	gs.name = "GameState"
	root.add_child(gs)

	var main := MainScene.instantiate()
	root.add_child(main)

	var workspace: Control = main.get_node("Workspace")
	var primary: Control = workspace.get_node("PrimaryHost")
	var context: Control = workspace.get_node("ContextHost")

	check(main.theme != null, "theme applied at Main root")
	check(primary.get_child_count() == 1, "home panel active on start")
	check(primary.visible, "home panel visible on start")
	check(gs.active_module == &"home", "active module is home")
	check(gs.module_open, "module starts open")
	var ws: Vector2 = workspace.size if workspace.size.x > 0 else Vector2(1920, 1080)
	check(primary.size.x < ws.x * 0.5, "home width is compact")
	check(primary.size.y < ws.y * 0.6, "home height is compact")

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

	# context opens alongside primary (primary keeps its class width)
	var primary_w: float = primary.size.x
	main.open_context(load("res://scenes/modules/contracts/contract_detail.tscn").instantiate())
	check(context.visible and context.get_child_count() == 1, "context opens with content")
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

	main.queue_free()
	gs.queue_free()
