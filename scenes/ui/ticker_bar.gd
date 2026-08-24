extends PanelContainer
## Bottom ticker strip: contextual messages and world events, rotating.

const COLOR_ACCENT := Color(0.22353, 0.81569, 1.0)
const COLOR_DIM := Color(0.43529, 0.5451, 0.60392)
const ROTATE_SECONDS := 6.0

var _messages: Array[Dictionary] = [] # {text: String, highlight: bool}
var _index := 0
var _label: Label
var _timer: Timer
var _built := false

func _ready() -> void:
	_build_children()

## Builds the label and the rotation timer. Normally invoked by _ready(),
## but also callable directly: headless tests add nodes without entering the
## tree, so _ready() may not have fired yet when push_message() runs.
## Idempotent.
func _build_children() -> void:
	if _built:
		return # already built
	_built = true
	_label = Label.new()
	_label.text = ""
	add_child(_label)
	_timer = Timer.new()
	_timer.wait_time = ROTATE_SECONDS
	_timer.timeout.connect(_advance)
	add_child(_timer)

func push_message(text: String, highlight: bool = false) -> void:
	_build_children()
	_messages.append({"text": text, "highlight": highlight})
	if _messages.size() == 1:
		_index = 0
		_show_current()

## Starts the rotation timer. Called by Main after the node is in the tree;
## safe to call any time (the Timer only ticks once inside the tree).
func start_rotation() -> void:
	_build_children()
	_timer.start()

func current_is_highlight() -> bool:
	return not _messages.is_empty() and _messages[_index].highlight

func _advance() -> void:
	if _messages.is_empty():
		return
	_index = (_index + 1) % _messages.size()
	_show_current()

func _show_current() -> void:
	var m: Dictionary = _messages[_index]
	_label.text = ">> " + m.text
	_label.add_theme_color_override("font_color",
		COLOR_ACCENT if m.highlight else COLOR_DIM)
