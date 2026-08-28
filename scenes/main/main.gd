extends Control
## Main: owns the environment, the workspace shell, module switching,
## context panel, and collapse behavior. GameState is the single source
## of truth for collapse state.

const GameStateScript := preload("res://autoload/game_state.gd")
const AMBIENCE_PATH := "res://assets/audio/ambience/lower_vesper_apartment.ogg"
const CONTRACT_ACCEPTED_SFX_PATH := "res://assets/audio/ui/contract_accepted.ogg"
const CONTRACT_PROCEEDED_SFX_PATH := "res://assets/audio/ui/contract_proceeded.ogg"
const CONTRACT_COMPLETED_SFX_PATH := "res://assets/audio/ui/contract_completed.ogg"
const CONTRACT_FAILED_SFX_PATH := "res://assets/audio/ui/contract_failed.ogg"
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

const MARGIN := 16.0
const RAIL_WIDTH := 44.0
const RAIL_GAP := 16.0
const CHIP_TOP := 12.0
const CHIP_GAP := 24.0
const TICKER_HEIGHT := 30.0
const TICKER_TOP_GAP := 4.0
const TICKER_BOTTOM_GAP := 0.0
const CONTEXT_GAP := 12.0
const SIZE_CLASSES := {
	&"compact": Vector2(0.34, 0.46),
	&"narrow": Vector2(0.44, 0.68),
	&"normal": Vector2(0.60, 0.72),
	&"wide": Vector2(0.78, 0.82),
	&"context": Vector2(0.31, 0.0), # height mirrors the primary
}
const PANEL_INSET := 18.0

var gs: Node
var workspace: Control
var status_chip: Control
var icon_rail: Control
var primary_host: Control
var context_host: Control
var ticker: Control
var _ambience: AudioStreamPlayer
var _contract_sfx: AudioStreamPlayer
var _missing_audio_paths := {}

var _built := false
var _selected_contract_id: StringName = &""

func _ready() -> void:
	_build_shell()
	if _ambience != null and _ambience.stream != null:
		_ambience.play()
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
	environment.setup(gs)
	var ambience := AudioStreamPlayer.new()
	ambience.name = "Ambience"
	ambience.bus = &"Ambience"
	ambience.volume_db = -18.0
	ambience.stream = _load_audio_stream(AMBIENCE_PATH)
	_ambience = ambience
	add_child(ambience)
	var contract_sfx := AudioStreamPlayer.new()
	contract_sfx.name = "ContractSfx"
	contract_sfx.bus = &"SFX"
	contract_sfx.volume_db = linear_to_db(0.5)
	_contract_sfx = contract_sfx
	add_child(contract_sfx)

	workspace = Control.new()
	workspace.name = "Workspace"
	workspace.set_anchors_preset(Control.PRESET_FULL_RECT)
	workspace.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(workspace)

	_build_status_chip()
	_build_rail()
	_build_panel_hosts()
	_build_ticker()
	gs.workspace_collapsed_changed.connect(_on_collapsed_changed)
	gs.contracts_changed.connect(_on_contracts_changed)
	gs.contract_accepted.connect(_on_contract_accepted)
	gs.contract_proceeded.connect(_on_contract_proceeded)
	gs.contract_resolved.connect(_on_contract_resolved)
	gs.active_module_changed.connect(func(_id: StringName) -> void: _apply_visibility())
	gs.module_open_changed.connect(func(_open: bool) -> void: _apply_visibility())
	gs.ticker_message.connect(func(text: String, highlight: bool) -> void: ticker.push_message(text, highlight))


	icon_rail.module_selected.connect(select_module)
	status_chip.collapse_requested.connect(gs.toggle_workspace)

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
		return # scene-less module (e.g. alerts): no-op
	var was_collapsed: bool = gs.workspace_collapsed
	if was_collapsed:
		gs.set_workspace_collapsed(false)
	if not was_collapsed and gs.active_module == id and gs.module_open:
		gs.set_module_open(false) # toggle closed - active_module stays set
		close_context()
		return
	gs.set_active_module(id)
	gs.set_module_open(true)
	_build_primary_module(id)

func _build_primary_module(id: StringName) -> void:
	close_context()
	for child in primary_host.get_children():
		primary_host.remove_child(child)
		child.queue_free()
	var panel: Control = MODULE_SCENES[id].instantiate()
	primary_host.add_child(panel)
	if id == &"contracts":
		panel.contract_selected.connect(_on_contract_selected)
		panel.setup(gs, gs.contracts)
	else:
		panel.setup(gs, gs.messages if id == &"comms" else null)
	_apply_visibility()

func close_topmost() -> void:
	if gs.workspace_collapsed:
		return # nothing visible to close
	if context_host.visible and context_host.get_child_count() > 0:
		close_context()
	elif gs.module_open:
		gs.set_module_open(false)
		_apply_visibility()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		close_topmost()
		get_viewport().set_input_as_handled()

func open_context(content: Control) -> void:
	for child in context_host.get_children():
		context_host.remove_child(child)
		child.queue_free()
	context_host.add_child(content)
	_apply_visibility()

func close_context() -> void:
	_selected_contract_id = &""
	for child in context_host.get_children():
		context_host.remove_child(child)
		child.queue_free()
	_apply_visibility()

func set_collapsed(collapsed: bool) -> void:
	gs.set_workspace_collapsed(collapsed)

func _on_contract_selected(contract_id: StringName) -> void:
	_selected_contract_id = contract_id
	var detail: Control = ContractDetailScene.instantiate()
	detail.accept_requested.connect(_on_contract_accept)
	detail.proceed_requested.connect(_on_contract_proceed)
	detail.resolution_requested.connect(_on_contract_resolution)
	detail.close_requested.connect(_close_contract_detail)
	detail.acknowledge_requested.connect(_close_contract_detail)
	open_context(detail)
	detail.setup(gs, gs.get_contract(contract_id))

func _on_contract_accept(id: StringName) -> void:
	gs.accept_contract(id)

func _on_contract_proceed(id: StringName) -> void:
	gs.proceed_contract(id)

func _on_contract_resolution(id: StringName, choice_id: StringName) -> void:
	gs.resolve_contract(id, choice_id)
func _load_audio_stream(path: String) -> AudioStream:
	var stream := load(path) as AudioStream
	if stream == null and not _missing_audio_paths.has(path):
		_missing_audio_paths[path] = true
		push_error("Audio stream unavailable: " + path)
	return stream

func _play_contract_sfx(path: String) -> void:
	var stream := _load_audio_stream(path)
	if stream == null:
		return
	_contract_sfx.stream = stream
	_contract_sfx.play()

func _on_contract_accepted(_id: StringName) -> void:
	_play_contract_sfx(CONTRACT_ACCEPTED_SFX_PATH)

func _on_contract_proceeded(_id: StringName) -> void:
	_play_contract_sfx(CONTRACT_PROCEEDED_SFX_PATH)

func _on_contract_resolved(_id: StringName, status: StringName) -> void:
	if status == &"completed":
		_play_contract_sfx(CONTRACT_COMPLETED_SFX_PATH)
	elif status == &"failed":
		_play_contract_sfx(CONTRACT_FAILED_SFX_PATH)


func _on_contracts_changed() -> void:
	if gs.active_module != &"contracts" or not gs.module_open:
		return
	var panel := primary_host.get_child(0)
	panel.setup(gs, gs.contracts)
	if _selected_contract_id != &"" and context_host.get_child_count() > 0:
		context_host.get_child(0).setup(gs, gs.get_contract(_selected_contract_id))

func _close_contract_detail() -> void:
	_selected_contract_id = &""
	close_context()

func _on_collapsed_changed(collapsed: bool) -> void:
	_apply_visibility()
	if collapsed:
		return
	if not is_inside_tree():
		return # headless: no SceneTree to create a tween against
	var tween := create_tween()
	primary_host.modulate.a = 0.0
	tween.tween_property(primary_host, "modulate:a", 1.0, 0.15)

func _apply_visibility() -> void:
	var collapsed: bool = gs.workspace_collapsed
	primary_host.visible = not collapsed and gs.module_open
	context_host.visible = not collapsed and gs.module_open and context_host.get_child_count() > 0
	if icon_rail.has_method("set_active"):
		icon_rail.set_active(gs.active_module, gs.module_open and not collapsed)
	_apply_layout()

func _size_class(id: StringName) -> Vector2:
	var reg := load("res://resources/module_registry.tres") as ModuleRegistry
	var def := reg.get_module(id) if reg != null else null
	var cls: StringName = def.size_class if def != null else &"normal"
	return SIZE_CLASSES.get(cls, SIZE_CLASSES[&"normal"])

func _apply_layout() -> void:
	var ws_size: Vector2 = workspace.size if workspace.size.x > 0.0 else Vector2(1920, 1080)
	var chip_min: Vector2 = status_chip.get_combined_minimum_size()
	if chip_min.x <= 0.0 or chip_min.y <= 0.0:
		chip_min = status_chip.get_minimum_size()
	status_chip.position = Vector2((ws_size.x - chip_min.x) * 0.5, CHIP_TOP)
	status_chip.size = chip_min
	var content_top: float = CHIP_TOP + status_chip.size.y + CHIP_GAP
	var content_bottom: float = ws_size.y - TICKER_HEIGHT - TICKER_BOTTOM_GAP - TICKER_TOP_GAP
	icon_rail.position = Vector2(MARGIN, content_top)
	icon_rail.size = Vector2(RAIL_WIDTH, content_bottom - content_top)
	ticker.position = Vector2(0.0, ws_size.y - TICKER_HEIGHT - TICKER_BOTTOM_GAP)
	ticker.size = Vector2(ws_size.x, TICKER_HEIGHT)

	var r_left: float = MARGIN + RAIL_WIDTH + RAIL_GAP
	var r_top: float = content_top
	var r_right: float = ws_size.x - MARGIN - PANEL_INSET
	var r_bottom: float = content_bottom - PANEL_INSET
	var r_w: float = r_right - r_left
	var r_h: float = r_bottom - r_top

	var p_class: Vector2 = _size_class(gs.active_module)
	var p_w: float = r_w * p_class.x
	var p_h: float = r_h * p_class.y
	primary_host.position = Vector2(r_left, r_top)
	primary_host.size = Vector2(maxf(p_w, 0.0), maxf(p_h, 0.0))

	var ctx_open: bool = context_host.visible and context_host.get_child_count() > 0
	if ctx_open:
		var c_class: Vector2 = SIZE_CLASSES[&"context"]
		var c_w: float = r_w * c_class.x
		context_host.position = Vector2(r_left + primary_host.size.x + CONTEXT_GAP, r_top)
		context_host.size = Vector2(c_w, primary_host.size.y) # height mirrors primary
	for panel in primary_host.get_children():
		panel.size = primary_host.size
	for panel in context_host.get_children():
		panel.size = context_host.size
