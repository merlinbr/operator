extends PanelContainer
## Home module: operator status summary.

const GameStateScript := preload("res://autoload/game_state.gd")
const ResidenceCatalog := preload("res://data/housing/residence_catalog.gd")
const COLOR_AMBER := Color(1.0, 0.82353, 0.47843)
const COLOR_DIM := Color(0.43529, 0.5451, 0.60392, 1)
const MASTER_DEFAULT := 80.0

const CONFIRMATION_MIN_HEIGHT := 520.0

signal residence_layout_changed
signal rest_requested
signal rent_payment_requested
signal move_requested(id: StringName)
signal buyout_requested

var _gs: Node
var _summary: Label
var _residence_name: Label
var _residence_status: Label
var _residence_rent: Label
var _residence_due: Label
var _rest_button: Button
var _pay_rent_button: Button
var _move_button: Button
var _buyout_button: Button
var _confirm_box: VBoxContainer
var _confirm_label: Label
var _confirm_button: Button
var _cancel_button: Button
var _pending_move_id: StringName = &""
var _pending_buyout := false
var _master_slider: HSlider
var _ambience_slider: HSlider
var _sfx_slider: HSlider
var _master_value: Label
var _ambience_value: Label
var _sfx_value: Label
var _mute_button: Button
var _master_before_mute := MASTER_DEFAULT
var _built := false
var _signals_connected := false

func _ready() -> void:
	_build_children()

## Builds the child controls. Normally invoked by _ready(), but also callable
## directly: headless tests add nodes without entering the tree, so _ready()
## may not have fired yet when setup() runs. Idempotent.
func _build_children() -> void:
	if _built:
		return # already built
	_built = true
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	add_child(vbox)
	var title := Label.new()
	title.text = "OPERATIONS TERMINAL v0.1"
	title.add_theme_font_override("font", load("res://assets/fonts/JetBrainsMono-Bold.ttf"))
	title.add_theme_font_size_override("font_size", 17)
	vbox.add_child(title)
	_summary = Label.new()
	vbox.add_child(_summary)
	_build_residence(vbox)
	var audio_title := Label.new()
	audio_title.text = "AUDIO"
	audio_title.add_theme_color_override("font_color", COLOR_AMBER)
	vbox.add_child(audio_title)
	var master_row := _make_audio_row("MASTER", "MasterSlider", "MasterValue")
	_master_slider = master_row.slider
	_master_value = master_row.value_label
	_mute_button = Button.new()
	_mute_button.name = "MuteButton"
	_mute_button.text = "MUTE"
	_mute_button.pressed.connect(_on_mute_pressed)
	master_row.row.add_child(_mute_button)
	vbox.add_child(master_row.row)
	var ambience_row := _make_audio_row("AMBIENCE", "AmbienceSlider", "AmbienceValue")
	_ambience_slider = ambience_row.slider
	_ambience_value = ambience_row.value_label
	vbox.add_child(ambience_row.row)
	var sfx_row := _make_audio_row("SFX", "SfxSlider", "SfxValue")
	_sfx_slider = sfx_row.slider
	_sfx_value = sfx_row.value_label
	vbox.add_child(sfx_row.row)

func _build_residence(parent: VBoxContainer) -> void:
	var residence_title := Label.new()
	residence_title.text = "RESIDENCE"
	residence_title.add_theme_color_override("font_color", COLOR_AMBER)
	parent.add_child(residence_title)
	_residence_name = Label.new()
	_residence_name.name = "ResidenceName"
	parent.add_child(_residence_name)
	_residence_status = Label.new()
	_residence_status.name = "ResidenceStatus"
	parent.add_child(_residence_status)
	_residence_rent = Label.new()
	_residence_rent.name = "ResidenceRent"
	parent.add_child(_residence_rent)
	_residence_due = Label.new()
	_residence_due.name = "ResidenceDue"
	parent.add_child(_residence_due)

	var actions := HBoxContainer.new()
	actions.name = "ResidenceActions"
	actions.add_theme_constant_override("separation", 8)
	_rest_button = Button.new()
	_rest_button.name = "RestButton"
	_rest_button.pressed.connect(_on_rest_pressed)
	actions.add_child(_rest_button)
	_pay_rent_button = Button.new()
	_pay_rent_button.name = "PayRentButton"
	_pay_rent_button.text = "PAY RENT"
	_pay_rent_button.pressed.connect(_on_pay_rent_pressed)
	actions.add_child(_pay_rent_button)
	_move_button = Button.new()
	_move_button.name = "MoveButton"
	_move_button.pressed.connect(_on_move_pressed)
	actions.add_child(_move_button)
	_buyout_button = Button.new()
	_buyout_button.name = "BuyoutButton"
	_buyout_button.text = "BUY OUT"
	_buyout_button.pressed.connect(_on_buyout_pressed)
	actions.add_child(_buyout_button)
	parent.add_child(actions)

	_confirm_box = VBoxContainer.new()
	_confirm_box.name = "ResidenceConfirmation"
	_confirm_label = Label.new()
	_confirm_label.name = "ResidenceConfirmLabel"
	_confirm_box.add_child(_confirm_label)
	var confirm_actions := HBoxContainer.new()
	_confirm_button = Button.new()
	_confirm_button.name = "ConfirmResidenceButton"
	_confirm_button.pressed.connect(_on_confirm_pressed)
	confirm_actions.add_child(_confirm_button)
	_cancel_button = Button.new()
	_cancel_button.name = "CancelResidenceButton"
	_cancel_button.text = "CANCEL"
	_cancel_button.pressed.connect(_clear_confirmation)
	confirm_actions.add_child(_cancel_button)
	_confirm_box.add_child(confirm_actions)
	_confirm_box.visible = false
	parent.add_child(_confirm_box)

func setup(gs: Node, data: Variant = null) -> void:
	_build_children()
	_gs = gs
	if not _signals_connected:
		_gs.credits_changed.connect(_refresh)
		_gs.clock_changed.connect(_refresh)
		_gs.district_changed.connect(_refresh)
		_gs.heat_changed.connect(_refresh)
		_gs.alerts_changed.connect(_refresh)
		_gs.residence_changed.connect(_refresh)
		_gs.rent_changed.connect(_refresh)
		_gs.contracts_changed.connect(_refresh)
		_signals_connected = true
	_setup_audio()
	_refresh()

func refresh() -> void:
	_refresh()

func layout_minimum_height() -> float:
	return CONFIRMATION_MIN_HEIGHT if _confirm_box.visible else 0.0

func _make_audio_row(channel_name: String, slider_name: String, value_name: String) -> Dictionary:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var channel := Label.new()
	channel.custom_minimum_size.x = 100.0
	channel.text = channel_name
	row.add_child(channel)
	var slider := HSlider.new()
	slider.name = slider_name
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	slider.focus_mode = Control.FOCUS_ALL
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)
	var value_label := Label.new()
	value_label.name = value_name
	value_label.custom_minimum_size.x = 45.0
	row.add_child(value_label)
	match slider_name:
		"MasterSlider":
			slider.value_changed.connect(_on_master_changed)
		"AmbienceSlider":
			slider.value_changed.connect(_on_ambience_changed)
		"SfxSlider":
			slider.value_changed.connect(_on_sfx_changed)
	return {"row": row, "slider": slider, "value_label": value_label}

func _setup_audio() -> void:
	_set_slider_from_bus(_master_slider, _master_value, &"Master")
	_set_slider_from_bus(_ambience_slider, _ambience_value, &"Ambience")
	_set_slider_from_bus(_sfx_slider, _sfx_value, &"SFX")
	var master_index := AudioServer.get_bus_index(&"Master")
	if master_index >= 0:
		var master_percent := db_to_linear(AudioServer.get_bus_volume_db(master_index)) * 100.0
		if master_percent > 0.0:
			_master_before_mute = master_percent
		else:
			_master_before_mute = MASTER_DEFAULT
		_mute_button.text = "UNMUTE" if AudioServer.is_bus_mute(master_index) else "MUTE"

func _set_slider_from_bus(slider: HSlider, value_label: Label, bus_name: StringName) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		push_error("Audio bus unavailable: " + String(bus_name))
		return
	var percent := db_to_linear(AudioServer.get_bus_volume_db(bus_index)) * 100.0
	if AudioServer.is_bus_mute(bus_index):
		percent = 0.0
	slider.set_value_no_signal(clamp(percent, 0.0, 100.0))
	value_label.text = "%d%%" % roundi(slider.value)

func _apply_bus_percent(bus_name: StringName, percent: float) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		push_error("Audio bus unavailable: " + String(bus_name))
		return
	AudioServer.set_bus_mute(bus_index, percent <= 0.0)
	if percent > 0.0:
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(percent / 100.0))

func _on_master_changed(value: float) -> void:
	_master_value.text = "%d%%" % roundi(value)
	if value > 0.0:
		_master_before_mute = value
		_mute_button.text = "MUTE"
	else:
		_mute_button.text = "UNMUTE"
	_apply_bus_percent(&"Master", value)

func _on_ambience_changed(value: float) -> void:
	_ambience_value.text = "%d%%" % roundi(value)
	_apply_bus_percent(&"Ambience", value)

func _on_sfx_changed(value: float) -> void:
	_sfx_value.text = "%d%%" % roundi(value)
	_apply_bus_percent(&"SFX", value)

func _residence(id: StringName) -> Dictionary:
	for residence: Dictionary in ResidenceCatalog.all():
		if residence.id == id:
			return residence
	return {}

func _on_rest_pressed() -> void:
	if _rest_button.disabled:
		return
	rest_requested.emit()

func _on_pay_rent_pressed() -> void:
	if not _pay_rent_button.visible:
		return
	rent_payment_requested.emit()

func _on_move_pressed() -> void:
	if _gs == null:
		return
	var target_id: StringName = &"sector_9_loft" if _gs.current_residence_id == &"lower_vesper_studio" else &"lower_vesper_studio"
	var target := _residence(target_id)
	var current := _residence(_gs.current_residence_id)
	if target.is_empty() or current.is_empty() or target_id == _gs.current_residence_id \
			or _gs.active_contract_id != &"" or _gs.rent_status != &"current" \
			or _gs.credits < int(target.move_in_cost):
		return
	_pending_move_id = target_id
	_pending_buyout = false
	_confirm_label.text = _confirmation_text("MOVE", target, int(target.move_in_cost),
		_residence_rent_text(current, _gs.rent_status))
	_confirm_button.name = "ConfirmMoveButton"
	_confirm_button.text = "CONFIRM MOVE"
	_set_confirmation_visible(true)
	_update_residence_actions()

func _on_buyout_pressed() -> void:
	if _gs == null:
		return
	var residence := _residence(_gs.current_residence_id)
	if residence.is_empty() or int(residence.buyout_cost) <= 0 \
			or _gs.owned_residence_ids.has(residence.id) or _gs.active_contract_id != &"" \
			or _gs.rent_status != &"current" or _gs.credits < int(residence.buyout_cost):
		return
	_pending_move_id = &""
	_pending_buyout = true
	_confirm_label.text = _confirmation_text("BUYOUT", residence, int(residence.buyout_cost),
		_residence_rent_text(residence, _gs.rent_status))
	_confirm_button.name = "ConfirmBuyoutButton"
	_confirm_button.text = "CONFIRM BUYOUT"
	_set_confirmation_visible(true)
	_update_residence_actions()


func _confirmation_text(action: String, target: Dictionary, cost: int, current_rent: String) -> String:
	var resulting_rent := "RENT FREE" if action == "BUYOUT" else _residence_rent_text(target, &"current")
	return "\n".join([
		"CONFIRM %s // %s" % [action, target.name.to_upper()],
		"CREDITS       %s CR" % GameStateScript.format_credits(_gs.credits),
		"EXACT COST    %s CR" % GameStateScript.format_credits(cost),
		"CURRENT RENT  " + current_rent,
		"RESULTING RENT " + resulting_rent,
	])

func _on_confirm_pressed() -> void:
	if not _pending_action_valid():
		return
	if _pending_buyout:
		buyout_requested.emit()
	elif _pending_move_id != &"":
		move_requested.emit(_pending_move_id)
	_clear_confirmation()

func _pending_action_valid() -> bool:
	if _gs == null or _gs.active_contract_id != &"" or _gs.rent_status != &"current":
		return false
	if _pending_buyout:
		var residence := _residence(_gs.current_residence_id)
		return not residence.is_empty() and int(residence.buyout_cost) > 0 \
				and not _gs.owned_residence_ids.has(residence.id) \
				and _gs.credits >= int(residence.buyout_cost)
	if _pending_move_id == &"":
		return false
	var current := _residence(_gs.current_residence_id)
	var target := _residence(_pending_move_id)
	return not current.is_empty() and not target.is_empty() \
			and current.id != target.id and _gs.credits >= int(target.move_in_cost)

func _clear_confirmation() -> void:
	_pending_move_id = &""
	_pending_buyout = false
	_set_confirmation_visible(false)
	_update_residence_actions()

func _set_confirmation_visible(visible: bool) -> void:
	if _confirm_box.visible == visible:
		return
	_confirm_box.visible = visible
	custom_minimum_size = Vector2(0.0, CONFIRMATION_MIN_HEIGHT if visible else 0.0)
	residence_layout_changed.emit()

func _residence_rent_text(residence: Dictionary, status: StringName) -> String:
	if status == &"current" and _gs.owned_residence_ids.has(residence.id):
		return "RENT FREE"
	return "%s CR / 30 DAYS" % GameStateScript.format_credits(int(residence.monthly_rent))

func _update_residence_actions() -> void:
	if _gs == null:
		return
	var residence := _residence(_gs.current_residence_id)
	if residence.is_empty():
		return
	var active_work: bool = _gs.active_contract_id != &""
	var has_due: bool = _gs.rent_status == &"due" or _gs.rent_status == &"overdue"
	var target_id: StringName = &"sector_9_loft" if residence.id == &"lower_vesper_studio" else &"lower_vesper_studio"
	var target := _residence(target_id)
	var can_manage: bool = not active_work and _gs.rent_status == &"current"
	_rest_button.disabled = active_work
	_rest_button.visible = not _confirm_box.visible
	_pay_rent_button.visible = not _confirm_box.visible and has_due and _gs.credits >= _gs.rent_due_amount
	_move_button.visible = not _confirm_box.visible and can_manage and not target.is_empty() \
			and _gs.credits >= int(target.move_in_cost)
	_buyout_button.visible = not _confirm_box.visible and can_manage \
			and int(residence.buyout_cost) > 0 and not _gs.owned_residence_ids.has(residence.id) \
			and _gs.credits >= int(residence.buyout_cost)

func _refresh(_signal_value: Variant = null, _signal_value2: Variant = null,
		_signal_value3: Variant = null) -> void:
	if _gs == null:
		return
	var residence := _residence(_gs.current_residence_id)
	if residence.is_empty():
		return
	_summary.add_theme_color_override("font_color", COLOR_DIM)
	_summary.text = "\n".join([
		"CREDITS    " + GameStateScript.format_credits(_gs.credits) + " CR",
		"DISTRICT   " + _gs.district,
		"TIME       DAY %d  %s" % [_gs.day, _gs.clock_text()],
		"HEAT       " + "▲".repeat(int(_gs.heat)),
		"ALERTS     %d" % _gs.alerts,
		"",
		"> select CONTRACTS on the rail to view work",
	])
	_residence_name.text = residence.name.to_upper()
	_residence_status.text = "OWNED" if _gs.owned_residence_ids.has(residence.id) else "LEASED"
	_residence_rent.text = "RENT       " + _residence_rent_text(residence, _gs.rent_status)
	match _gs.rent_status:
		&"due":
			_residence_due.text = "RENT DUE   // %s CR" % GameStateScript.format_credits(_gs.rent_due_amount)
		&"overdue":
			_residence_due.text = "RENT OVERDUE // %s CR" % GameStateScript.format_credits(_gs.rent_due_amount)
		_:
			_residence_due.text = "NEXT DUE   // DAY %d" % _gs.next_rent_due_day \
					if not _gs.owned_residence_ids.has(residence.id) else "NO RENT DUE"
	_rest_button.text = "REST // ADVANCE TO DAY %d" % (_gs.day + 1)
	_move_button.text = "MOVE TO " + ("SECTOR 9 LOFT" if residence.id == &"lower_vesper_studio" else "LOWER VESPER STUDIO")
	_update_residence_actions()


func _on_mute_pressed() -> void:
	if _master_slider.value > 0.0:
		_master_before_mute = _master_slider.value
		_set_master_value(0.0)
		_mute_button.text = "UNMUTE"
	else:
		_set_master_value(_master_before_mute if _master_before_mute > 0.0 else MASTER_DEFAULT)
		_mute_button.text = "MUTE"

func _set_master_value(value: float) -> void:
	_master_slider.set_value_no_signal(value)
	_on_master_changed(value)


