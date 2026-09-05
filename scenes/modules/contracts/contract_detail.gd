extends PanelContainer
## Contract detail — shown in the context panel next to the list.

const GameStateScript := preload("res://autoload/game_state.gd")
const COLOR_ALERT := Color(1.0, 0.35294, 0.47059)
const COLOR_DIM := Color(0.43529, 0.5451, 0.60392, 1)

signal accept_requested(contract_id: StringName)
signal proceed_requested(contract_id: StringName)
signal resolution_requested(contract_id: StringName, choice_id: StringName)
signal close_requested
signal acknowledge_requested

var _actions: VBoxContainer
var _contract_id: StringName = &""
var _title: Label
var _body: Label
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
	vbox.add_theme_constant_override("separation", 10)
	add_child(vbox)
	_title = Label.new()
	_title.add_theme_font_override("font", load("res://assets/fonts/JetBrainsMono-Bold.ttf"))
	_title.add_theme_font_size_override("font_size", 16)
	vbox.add_child(_title)
	_body = Label.new()
	vbox.add_child(_body)
	_actions = VBoxContainer.new()
	_actions.add_theme_constant_override("separation", 4)
	vbox.add_child(_actions)

func _clear_actions() -> void:
	for child in _actions.get_children():
		_actions.remove_child(child)
		child.queue_free()

func _add_preview(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", COLOR_DIM)
	_actions.add_child(label)
func _add_action(text: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	_actions.add_child(button)

func setup(gs: Node, data: Variant = null) -> void:
	_build_children()
	_clear_actions()
	var c: Dictionary = data if data is Dictionary else {}
	if c.is_empty():
		_contract_id = &""
		_title.text = ""
		_body.text = ""
		return
	_contract_id = c.id
	match c.phase:
		&"offer":
			_render_offer(gs, c)
		&"ready_to_proceed":
			_render_ready(gs, c)
		&"customs_hold":
			_render_customs(c)
		&"resolved":
			_render_resolved(c)

func _render_offer(gs: Node, c: Dictionary) -> void:
	_title.text = "CONTRACT // " + c.code
	_body.add_theme_color_override("font_color", COLOR_ALERT if c.get("encrypted", false) else COLOR_DIM)
	_body.text = "\n".join([
		c.title, "", "CLIENT      " + c.client, "DESTINATION " + c.destination,
		_deadline_text(c),
		"EXECUTION   %d MIN" % c.proceed_minutes,
		"RISK        " + c.risk, "REWARD      " + GameStateScript.format_credits(c.reward_credits) + " CR",
	])
	_render_timing_warning(gs, c)
	_add_action("ACCEPT", func() -> void: accept_requested.emit(_contract_id))
	_add_action("CLOSE", func() -> void: close_requested.emit())

func _render_ready(gs: Node, c: Dictionary) -> void:
	_body.add_theme_color_override("font_color", COLOR_DIM)
	_title.text = "ACTIVE // " + c.code
	_body.text = "\n".join([
		c.title, "", "DESTINATION " + c.destination,
		_deadline_text(c),
		"EXECUTION   %d MIN" % c.proceed_minutes,
		"STATUS      CARGO IN TRANSIT",
	])
	_render_timing_warning(gs, c)
	_add_action("PROCEED TO " + c.proceed_label,
		func() -> void: proceed_requested.emit(_contract_id))
	_add_action("CLOSE", func() -> void: close_requested.emit())

func _deadline_text(c: Dictionary) -> String:
	var cutoff := int(c.deadline_at_minute)
	if cutoff < 0:
		return "DEADLINE    NOT PUBLISHED"
	var due_day: int = cutoff / 1440 + 1
	var due_minute := cutoff % 1440
	return "DEADLINE    DAY %d // %02d:%02d" % [
		due_day, floori(due_minute / 60.0), due_minute % 60,
	]

func _render_timing_warning(gs: Node, c: Dictionary) -> void:
	if gs.current_minute() + int(c.proceed_minutes) >= int(c.deadline_at_minute):
		_add_preview("WARNING // PROCEEDING WILL MISS THE DEADLINE")

func _choice(c: Dictionary, choice_id: StringName) -> Dictionary:
	for choice: Dictionary in c.complication.choices:
		if choice.id == choice_id:
			return choice
	return {}

func _render_customs(c: Dictionary) -> void:
	_body.add_theme_color_override("font_color", COLOR_DIM)
	_title.text = c.complication.title
	_body.text = c.complication.body
	for choice: Dictionary in c.complication.choices:
		var choice_id: StringName = choice.id
		_add_preview(choice.preview)
		_add_action(choice.label, _emit_resolution.bind(choice_id))

func _emit_resolution(choice_id: StringName) -> void:
	resolution_requested.emit(_contract_id, choice_id)

func _render_resolved(c: Dictionary) -> void:
	if c.resolution_id == &"deadline_missed":
		_render_deadline_result(c)
		return
	_body.add_theme_color_override("font_color", COLOR_DIM)
	var choice := _choice(c, c.resolution_id)
	_title.text = "CONTRACT COMPLETE" if c.status == &"completed" else "CONTRACT FAILED"
	_body.text = "\n".join([
		c.title,
		"RESULT      " + choice.result,
		"CREDITS     " + _credit_delta_text(choice.credit_delta) + " CR",
		"HEAT        %+d" % choice.heat_delta,
	])
	_add_action("ACKNOWLEDGE", func() -> void: acknowledge_requested.emit())

func _render_deadline_result(c: Dictionary) -> void:
	_body.add_theme_color_override("font_color", COLOR_DIM)
	_title.text = "OFFER EXPIRED" if c.status == &"expired" else "CONTRACT FAILED"
	_body.text = "\n".join([
		c.title,
		"RESULT      DEADLINE MISSED",
		_deadline_text(c),
		"CREDITS     +0 CR",
		"HEAT        +0",
	])
	_add_action("ACKNOWLEDGE", func() -> void: acknowledge_requested.emit())

func _credit_delta_text(delta: int) -> String:
	var sign := "+" if delta >= 0 else "-"
	return sign + GameStateScript.format_credits(absi(delta))
