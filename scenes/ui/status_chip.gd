extends PanelContainer
## Compact always-visible status chip: credits over district/clock.

const GameStateScript := preload("res://autoload/game_state.gd")
const COLOR_AMBER := Color(1.0, 0.82353, 0.47843)

var _gs: Node
var _credits_label: Label
var _loc_label: Label

func _ready() -> void:
	_build_children()

## Builds the child controls. Normally invoked by _ready(), but also callable
## directly: headless tests add nodes without entering the tree, so _ready()
## may not have fired yet when setup() runs.
func _build_children() -> void:
	if _credits_label != null:
		return  # already built
	theme_type_variation = &"StatusChip"
	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vbox)
	_credits_label = Label.new()
	_credits_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_credits_label.add_theme_color_override("font_color", COLOR_AMBER)
	_loc_label = Label.new()
	_loc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_credits_label)
	vbox.add_child(_loc_label)

func setup(gs: Node) -> void:
	_build_children()
	_gs = gs
	_gs.credits_changed.connect(_on_credits)
	_gs.clock_changed.connect(_on_clock)
	_gs.district_changed.connect(_on_district)
	_on_credits(_gs.credits)
	_on_clock(_gs.day, _gs.minute_of_day)
	_on_district(_gs.district)

func _on_credits(value: int) -> void:
	_credits_label.text = GameStateScript.format_credits(value) + " CR"

func _on_clock(day: int, minute_of_day: int) -> void:
	_loc_label.text = "%s // %s" % [_gs.district, _gs.clock_text()]
	_loc_label.tooltip_text = "DAY %d" % day

func _on_district(new_district: String) -> void:
	_on_clock(_gs.day, _gs.minute_of_day)
