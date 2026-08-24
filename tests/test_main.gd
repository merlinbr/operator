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

	main.select_module(&"contracts")
	check(primary.get_child(0).name == "ContractsPanel", "module switching swaps panel")

	var wide: float = primary.size.x
	main.open_context(load("res://scenes/modules/contracts/contract_detail.tscn").instantiate())
	check(context.visible and context.get_child_count() == 1, "context opens with content")
	check(primary.size.x < wide, "primary shrinks when context opens")

	main.close_context()
	check(not context.visible, "context closes")

	gs.set_workspace_collapsed(true)
	check(not primary.visible, "collapse hides primary panel")
	check(not context.visible, "collapse hides context panel")
	check(workspace.get_node("StatusChip").visible, "chip survives collapse")
	check(workspace.get_node("IconRail").visible, "rail survives collapse")
	check(workspace.get_node("TickerBar").visible, "ticker survives collapse")

	main.select_module(&"comms")
	check(not gs.workspace_collapsed, "selecting a module un-collapses")
	check(primary.visible and primary.get_child(0).name == "CommsPanel", "comms open after un-collapse")

	main.queue_free()
	gs.queue_free()
