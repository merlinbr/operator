extends VBoxContainer
## Slim floating module rail. Renders from the ModuleRegistry resource.
## Locked modules stay visible (greyed, lock tooltip) so the player sees
## the terminal grow; late-game modules are absent from the registry.

signal module_selected(id: StringName)

const COLOR_ACCENT := Color(0.22353, 0.81569, 1.0)
const COLOR_LOCKED_DIM := Color(1.0, 1.0, 1.0, 0.4)

var _registry: ModuleRegistry
var _buttons := {} # StringName -> Button
var _active: StringName = &""
var _built := false

func _ready() -> void:
	_build_children()

func setup(registry: ModuleRegistry) -> void:
	_build_children()
	_registry = registry
	_rebuild()

func get_button(id: StringName) -> Button:
	return _buttons.get(id)

func set_active(id: StringName, lit: bool) -> void:
	_active = id
	for btn_id: StringName in _buttons:
		var btn: Button = _buttons[btn_id]
		if btn.disabled:
			btn.modulate = COLOR_LOCKED_DIM
		elif btn_id == _active and lit:
			btn.modulate = COLOR_ACCENT
		else:
			btn.modulate = Color.WHITE

## Builds the static chrome (layout constants). Normally invoked by _ready(),
## but also callable directly: headless tests add nodes without entering the
## tree, so _ready() may not have fired yet when setup() runs. Idempotent.
func _build_children() -> void:
	if _built:
		return # already built
	_built = true
	add_theme_constant_override("separation", 8)

func _rebuild() -> void:
	for child in get_children():
		child.queue_free()
	_buttons.clear()
	var last_group := &""
	for def: ModuleDef in _registry.rail_order():
		if last_group != &"" and def.group != last_group:
			add_child(HSeparator.new())
		last_group = def.group
		var btn := Button.new()
		btn.text = def.glyph
		btn.tooltip_text = def.display_name if def.unlocked else def.display_name + " (LOCKED)"
		btn.disabled = not def.unlocked
		btn.focus_mode = Control.FOCUS_NONE
		btn.custom_minimum_size = Vector2(44, 40)
		btn.add_theme_font_size_override("font_size", 18)
		if not def.unlocked:
			btn.modulate = COLOR_LOCKED_DIM
		btn.pressed.connect(_on_pressed.bind(def.id))
		add_child(btn)
		_buttons[def.id] = btn

func _on_pressed(id: StringName) -> void:
	module_selected.emit(id)
