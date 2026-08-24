extends PanelContainer
## Home module: operator status summary.

const GameStateScript := preload("res://autoload/game_state.gd")
const COLOR_AMBER := Color(1.0, 0.82353, 0.47843)
const COLOR_DIM := Color(0.43529, 0.5451, 0.60392, 1)

var _gs: Node
var _summary: Label
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

func setup(gs: Node, data: Variant = null) -> void:
	_build_children()
	_gs = gs
	_gs.credits_changed.connect(_refresh)
	_gs.clock_changed.connect(_refresh)
	_gs.district_changed.connect(_refresh)
	_gs.heat_changed.connect(_refresh)
	_gs.alerts_changed.connect(_refresh)
	_refresh()

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
