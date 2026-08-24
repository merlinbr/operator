extends PanelContainer
## Contract detail — shown in the context panel next to the list.

const GameStateScript := preload("res://autoload/game_state.gd")
const COLOR_ALERT := Color(1.0, 0.35294, 0.47059)
const COLOR_AMBER := Color(1.0, 0.82353, 0.47843)
const COLOR_DIM := Color(0.43529, 0.5451, 0.60392, 1)

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

func setup(_gs: Node, data: Variant = null) -> void:
	_build_children()
	var c: Dictionary = data if data is Dictionary else {}
	if c.is_empty():
		_title.text = ""
		_body.text = ""
		return
	_title.text = c.title
	if c.encrypted:
		_body.add_theme_color_override("font_color", COLOR_ALERT)
		_body.text = "\n".join([
			"CLIENT      ?????",
			"REWARD      ?????",
			"RISK        ?????",
			"DISTRICT    ?????",
			"",
			"> OFFER ENCRYPTED — a trusted contact is required to decrypt",
		])
	else:
		_body.add_theme_color_override("font_color", COLOR_DIM)
		_body.text = "\n".join([
			"CLIENT      " + c.client,
			"REWARD      " + GameStateScript.format_credits(c.reward_credits) + " CR",
			"RISK        " + c.risk,
			"DISTRICT    " + c.district,
		])
