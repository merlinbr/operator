extends Control
## Main: owns the environment, the workspace shell, module switching,
## context panel, and collapse behavior. GameState is the single source
## of truth for collapse state.

const GameStateScript := preload("res://autoload/game_state.gd")

const MODULE_SCENES := {
	&"home": preload("res://scenes/modules/home/home_panel.tscn"),
	&"comms": preload("res://scenes/modules/comms/comms_panel.tscn"),
	&"contracts": preload("res://scenes/modules/contracts/contracts_panel.tscn"),
}
const ContractDetailScene := preload("res://scenes/modules/contracts/contract_detail.tscn")
const EnvironmentScene := preload("res://scenes/main/environment.tscn")
const StatusChipScene := preload("res://scenes/ui/status_chip.tscn")
const IconRailScene := preload("res://scenes/ui/icon_rail.tscn")
const TickerBarScene := preload("res://scenes/ui/ticker_bar.tscn")
const PlaceholderContracts := preload("res://data/placeholder/placeholder_contracts.gd")
const PlaceholderMessages := preload("res://data/placeholder/placeholder_messages.gd")

const MARGIN := 16.0
const RAIL_WIDTH := 44.0
const RAIL_GAP := 16.0
const CHIP_TOP := 12.0
const CHIP_GAP := 14.0
const TICKER_HEIGHT := 30.0
const CONTEXT_SPLIT := 0.62
const CONTEXT_GAP := 12.0

var gs: Node
var workspace: Control
var status_chip: Control
var collapse_button: Button
var icon_rail: Control
var primary_host: Control
var context_host: Control
var ticker: Control

var _built := false

func _ready() -> void:
	_build_shell()
	if ticker != null:
		ticker.start_rotation()
	if is_inside_tree():
		await get_tree().process_frame
		_apply_layout()

## The headless test harness adds nodes to a root that is not yet inside the
## tree, so _enter_tree/_ready never fire there. NOTIFICATION_PARENTED does
## fire, and by then get_parent() is the root (with the GameState sibling), so
## build the shell here as well. Idempotent — _ready in the real game is a no-op.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PARENTED:
		_build_shell()

func _build_shell() -> void:
	if _built:
		return
	gs = _resolve_game_state()
	if gs == null:
		push_error("GameState autoload missing — cannot start")
		return
	_built = true
	theme = load("res://resources/operator_theme.tres")

	var environment := EnvironmentScene.instantiate()
	add_child(environment)

	workspace = Control.new()
	workspace.name = "Workspace"
	workspace.set_anchors_preset(Control.PRESET_FULL_RECT)
	workspace.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(workspace)

	_build_status_chip()
	_build_collapse_button()
	_build_rail()
	_build_panel_hosts()
	_build_ticker()

	gs.workspace_collapsed_changed.connect(_on_collapsed_changed)
	gs.ticker_message.connect(func(text: String, highlight: bool) -> void: ticker.push_message(text, highlight))
	icon_rail.module_selected.connect(select_module)
	collapse_button.pressed.connect(func() -> void: gs.toggle_workspace())

	select_module(&"home")
	_apply_layout()
	workspace.resized.connect(_apply_layout)

## Resolves the GameState autoload node. In the real game it lives at
## /root/GameState; in the headless harness it is a sibling added to the
## same root as Main (reached via get_parent() before Main enters the tree).
func _resolve_game_state() -> Node:
	if is_inside_tree():
		var g := get_node_or_null("/root/GameState")
		if g != null:
			return g
	if get_parent() != null:
		return get_parent().get_node_or_null("GameState")
	return null

func _build_status_chip() -> void:
	status_chip = StatusChipScene.instantiate()
	status_chip.name = "StatusChip"
	workspace.add_child(status_chip)
	status_chip.setup(gs)

func _build_collapse_button() -> void:
	collapse_button = Button.new()
	collapse_button.name = "CollapseToggle"
	collapse_button.text = "⧉"
	collapse_button.tooltip_text = "Collapse workspace"
	collapse_button.focus_mode = Control.FOCUS_NONE
	collapse_button.custom_minimum_size = Vector2(32, 32)
	workspace.add_child(collapse_button)

func _build_rail() -> void:
	icon_rail = IconRailScene.instantiate()
	icon_rail.name = "IconRail"
	workspace.add_child(icon_rail)
	icon_rail.setup(load("res://resources/module_registry.tres"))

func _build_panel_hosts() -> void:
	primary_host = Control.new()
	primary_host.name = "PrimaryHost"
	primary_host.clip_contents = true
	primary_host.mouse_filter = Control.MOUSE_FILTER_PASS
	workspace.add_child(primary_host)
	context_host = Control.new()
	context_host.name = "ContextHost"
	context_host.visible = false
	context_host.clip_contents = true
	context_host.mouse_filter = Control.MOUSE_FILTER_PASS
	workspace.add_child(context_host)

func _build_ticker() -> void:
	ticker = TickerBarScene.instantiate()
	ticker.name = "TickerBar"
	workspace.add_child(ticker)
	ticker.push_message("NEW MESSAGE // MARA", true)
	ticker.push_message("contract expiring: cold-chain delivery, Docks")
	ticker.push_message("rumor: corp sweep, Sector 9 tonight")

func select_module(id: StringName) -> void:
	if not MODULE_SCENES.has(id):
		return
	if gs.workspace_collapsed:
		gs.set_workspace_collapsed(false)
	for child in primary_host.get_children():
		primary_host.remove_child(child)
		child.queue_free()
	var panel: Control = MODULE_SCENES[id].instantiate()
	primary_host.add_child(panel)
	if id == &"contracts":
		panel.contract_selected.connect(_on_contract_selected)
		panel.setup(gs, PlaceholderContracts.all())
	else:
		panel.setup(gs, PlaceholderMessages.all() if id == &"comms" else null)
	if icon_rail.has_method("set_active"):
		icon_rail.set_active(id)
	_apply_layout()

func open_context(content: Control) -> void:
	for child in context_host.get_children():
		context_host.remove_child(child)
		child.queue_free()
	context_host.add_child(content)
	context_host.visible = true
	_apply_layout()

func close_context() -> void:
	for child in context_host.get_children():
		context_host.remove_child(child)
		child.queue_free()
	context_host.visible = false
	_apply_layout()

func set_collapsed(collapsed: bool) -> void:
	gs.set_workspace_collapsed(collapsed)

func _on_contract_selected(contract: Dictionary) -> void:
	var detail: Control = ContractDetailScene.instantiate()
	open_context(detail)
	detail.setup(gs, contract)

func _on_collapsed_changed(collapsed: bool) -> void:
	_apply_workspace_visibility(collapsed)
	_apply_layout()
	if collapsed:
		return
	if not is_inside_tree():
		return # headless: no SceneTree to create a tween against
	var tween := create_tween()
	primary_host.modulate.a = 0.0
	tween.tween_property(primary_host, "modulate:a", 1.0, 0.15)

func _apply_workspace_visibility(collapsed: bool) -> void:
	primary_host.visible = not collapsed
	context_host.visible = not collapsed and context_host.get_child_count() > 0
	collapse_button.tooltip_text = "Expand workspace" if collapsed else "Collapse workspace"

func _apply_layout() -> void:
	var ws_size: Vector2 = workspace.size if workspace.size.x > 0.0 else Vector2(1920, 1080)
	var chip_min: Vector2 = status_chip.get_combined_minimum_size()
	status_chip.position = Vector2((ws_size.x - chip_min.x) * 0.5, CHIP_TOP)
	status_chip.size = chip_min
	collapse_button.position = Vector2(ws_size.x - MARGIN - collapse_button.custom_minimum_size.x, CHIP_TOP)
	var content_top: float = CHIP_TOP + status_chip.size.y + CHIP_GAP
	var content_bottom: float = ws_size.y - TICKER_HEIGHT - MARGIN
	icon_rail.position = Vector2(MARGIN, content_top)
	icon_rail.size = Vector2(RAIL_WIDTH, content_bottom - content_top)
	ticker.position = Vector2(0.0, ws_size.y - TICKER_HEIGHT)
	ticker.size = Vector2(ws_size.x, TICKER_HEIGHT)
	var panel_left: float = MARGIN + RAIL_WIDTH + RAIL_GAP
	var available_right: float = ws_size.x - MARGIN
	var context_open: bool = context_host.visible
	var primary_right: float = available_right
	if context_open:
		primary_right = panel_left + (available_right - panel_left) * CONTEXT_SPLIT - CONTEXT_GAP * 0.5
	primary_host.position = Vector2(panel_left, content_top)
	primary_host.size = Vector2(primary_right - panel_left, content_bottom - content_top)
	if context_open:
		context_host.position = Vector2(primary_right + CONTEXT_GAP, content_top)
		context_host.size = Vector2(available_right - primary_right - CONTEXT_GAP, content_bottom - content_top)
	for panel in primary_host.get_children():
		panel.size = primary_host.size
	for panel in context_host.get_children():
		panel.size = context_host.size
