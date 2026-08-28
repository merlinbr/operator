extends PanelContainer
## Home module: operator status summary.

const GameStateScript := preload("res://autoload/game_state.gd")
const COLOR_AMBER := Color(1.0, 0.82353, 0.47843)
const COLOR_DIM := Color(0.43529, 0.5451, 0.60392, 1)
const MASTER_DEFAULT := 80.0

var _gs: Node
var _summary: Label
var _master_slider: HSlider
var _ambience_slider: HSlider
var _sfx_slider: HSlider
var _master_value: Label
var _ambience_value: Label
var _sfx_value: Label
var _mute_button: Button
var _master_before_mute := MASTER_DEFAULT
var _built := false

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
func setup(gs: Node, data: Variant = null) -> void:
	_build_children()
	_gs = gs
	_gs.credits_changed.connect(_refresh)
	_gs.clock_changed.connect(_refresh)
	_gs.district_changed.connect(_refresh)
	_gs.heat_changed.connect(_refresh)
	_gs.alerts_changed.connect(_refresh)
	_setup_audio()
	_refresh()

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

func _refresh(_signal_value: Variant = null, _signal_value2: Variant = null) -> void:
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
