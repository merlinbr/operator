extends Control

signal enter_requested

const MainScene := preload("res://scenes/main/main.tscn")
const ENTRY_SFX_PATH := "res://assets/audio/ui/terminal_enter.ogg"
const REVEAL_SECONDS := 0.9
const FADE_SECONDS := 0.2
const DIAGNOSTICS := [
	"NODE       LOWER VESPER",
	"UPLINK     SECURE",
	"LOCAL TIME DAY 14 // 23:41",
	"WORK QUEUE 01 AVAILABLE",
	"MESSAGE    MARA // UNREAD",
]

var _panel: PanelContainer
var _diagnostics: Array[Label] = []
var _timer: Timer
var _boot_sfx: AudioStreamPlayer
var _entering := false
var _revealed := 0
var _fade_tween: Tween
var _initialized := false

func _notification(what: int) -> void:
	if what == NOTIFICATION_PARENTED:
		_initialize()

func _ready() -> void:
	_initialize()
	if not _entering and _timer.is_stopped():
		_timer.start()

func _initialize() -> void:
	if _initialized:
		return
	_initialized = true
	theme = load("res://resources/operator_theme.tres")
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_children()
	enter_requested.connect(_on_enter_requested)
	if is_inside_tree():
		_timer.start()

func _build_children() -> void:
	var background := ColorRect.new()
	background.name = "Background"
	background.color = Color(0.012, 0.020, 0.031, 1.0)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var center := CenterContainer.new()
	center.name = "Center"
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_panel = PanelContainer.new()
	_panel.name = "BootPanel"
	_panel.custom_minimum_size.x = 480.0
	center.add_child(_panel)

	var content := VBoxContainer.new()
	content.name = "Content"
	content.add_theme_constant_override("separation", 10)
	_panel.add_child(content)

	var title := Label.new()
	title.name = "Title"
	title.text = "OPERATOR // LOCAL TERMINAL"
	title.add_theme_font_override("font", load("res://assets/fonts/JetBrainsMono-Bold.ttf"))
	title.add_theme_font_size_override("font_size", 18)
	content.add_child(title)

	var divider := HSeparator.new()
	content.add_child(divider)

	var diagnostics := VBoxContainer.new()
	diagnostics.name = "Diagnostics"
	diagnostics.add_theme_constant_override("separation", 4)
	content.add_child(diagnostics)
	for text: String in DIAGNOSTICS:
		var line := Label.new()
		line.text = text
		line.visible = false
		diagnostics.add_child(line)
		_diagnostics.append(line)

	var enter := Button.new()
	enter.name = "EnterOperations"
	enter.text = "ENTER OPERATIONS"
	enter.focus_mode = Control.FOCUS_ALL
	enter.pressed.connect(_enter_operations)
	content.add_child(enter)

	_timer = Timer.new()
	_timer.name = "DiagnosticTimer"
	_timer.wait_time = REVEAL_SECONDS
	_timer.timeout.connect(_reveal_next_line)
	add_child(_timer)
	var boot_sfx := AudioStreamPlayer.new()
	boot_sfx.name = "BootSfx"
	boot_sfx.bus = &"SFX"
	boot_sfx.volume_db = linear_to_db(0.25)
	boot_sfx.stream = _load_stream(ENTRY_SFX_PATH)
	_boot_sfx = boot_sfx
	add_child(boot_sfx)

func _load_stream(path: String) -> AudioStream:
	var stream := load(path) as AudioStream
	if stream == null:
		push_error("Audio stream unavailable: " + path)
	return stream

func _reveal_next_line() -> void:
	if _revealed >= _diagnostics.size():
		_timer.stop()
		return
	_diagnostics[_revealed].visible = true
	_revealed += 1
	if _revealed == _diagnostics.size():
		_timer.stop()

func _enter_operations() -> void:
	if _entering:
		return
	_entering = true
	if _boot_sfx.stream != null:
		_boot_sfx.play()
	_timer.stop()
	for line in _diagnostics:
		line.visible = true
	_revealed = _diagnostics.size()
	enter_requested.emit()

func _on_enter_requested() -> void:
	_fade_tween = create_tween()
	_fade_tween.tween_property(_panel, "modulate:a", 0.0, FADE_SECONDS)
	_fade_tween.tween_callback(func() -> void:
		get_tree().change_scene_to_packed(MainScene))

func _on_unhandled_input(event: InputEvent) -> void:
	if _entering:
		return
	if event.is_action_pressed(&"ui_accept") or event.is_action_pressed(&"ui_cancel"):
		_enter_operations()
		if is_inside_tree():
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		_enter_operations()
		if is_inside_tree():
			get_viewport().set_input_as_handled()

