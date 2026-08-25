extends PanelContainer
## Compact always-visible status and workspace action HUD.

signal collapse_requested

const GameStateScript := preload("res://autoload/game_state.gd")
const COLOR_AMBER := Color(1.0, 0.82353, 0.47843)
const STATUS_DIVIDER_MARGIN := 16

var _gs: Node
var _credits_label: Label
var _district_label: Label
var _day_label: Label
var _time_label: Label
var _collapse_button: Button

func _ready() -> void:
	_build_children()

## Builds the child controls. Normally invoked by _ready(), but also callable
## directly: headless tests add nodes without entering the tree, so _ready()
## may not have fired yet when setup() runs.
func _build_children() -> void:
	if _credits_label != null:
		return  # already built
	theme_type_variation = &"StatusChip"
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	_credits_label = Label.new()
	_credits_label.add_theme_color_override("font_color", COLOR_AMBER)
	_district_label = Label.new()
	_day_label = Label.new()
	_time_label = Label.new()
	row.add_child(_credits_label)
	_add_status_divider(row)
	row.add_child(_district_label)
	_add_status_divider(row)
	row.add_child(_day_label)
	_add_status_divider(row)
	row.add_child(_time_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	row.add_child(VSeparator.new())
	_collapse_button = Button.new()
	_collapse_button.name = "WorkspaceAction"
	_collapse_button.flat = true
	_collapse_button.focus_mode = Control.FOCUS_ALL
	_collapse_button.pressed.connect(_on_workspace_action_pressed)
	row.add_child(_collapse_button)

func _add_status_divider(row: HBoxContainer) -> void:
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", STATUS_DIVIDER_MARGIN)
	margin.add_theme_constant_override("margin_right", STATUS_DIVIDER_MARGIN)
	var divider := VSeparator.new()
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(divider)
	row.add_child(margin)

func setup(gs: Node) -> void:
	_build_children()
	_gs = gs
	_gs.credits_changed.connect(_on_credits)
	_gs.clock_changed.connect(_on_clock)
	_gs.district_changed.connect(_on_district)
	_gs.workspace_collapsed_changed.connect(_on_workspace_collapsed)
	_on_credits(_gs.credits)
	_on_clock(_gs.day, _gs.minute_of_day)
	_on_district(_gs.district)
	_on_workspace_collapsed(_gs.workspace_collapsed)

func _on_credits(value: int) -> void:
	_credits_label.text = GameStateScript.format_credits(value) + " CR"

func _on_clock(day: int, _minute_of_day: int) -> void:
	_day_label.text = "DAY %d" % day
	_time_label.text = _gs.clock_text()

func _on_district(new_district: String) -> void:
	_district_label.text = new_district

func _on_workspace_action_pressed() -> void:
	collapse_requested.emit()


func _on_workspace_collapsed(collapsed: bool) -> void:
	if collapsed:
		_collapse_button.text = "EXPAND ▼"
		_collapse_button.tooltip_text = "Expand workspace"
	else:
		_collapse_button.text = "COLLAPSE ▲"
		_collapse_button.tooltip_text = "Collapse workspace"
