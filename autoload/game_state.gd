extends Node
## Central game state singleton (registered as autoload "GameState").
## Components receive this node via setup() injection — they never access
## the autoload global by name. No class_name on purpose (autoload name wins).

signal credits_changed(new_credits: int)
signal clock_changed(day: int, minute_of_day: int)
signal district_changed(new_district: String)
signal heat_changed(new_heat: int)
signal alerts_changed(new_alerts: int)
signal workspace_collapsed_changed(collapsed: bool)
signal active_module_changed(id: StringName)
signal module_open_changed(open: bool)
signal ticker_message(text: String, highlight: bool)

const START_CREDITS := 12480
const START_DISTRICT := "LOWER VESPER"
const START_DAY := 14
const START_MINUTE := 23 * 60 + 41

var credits: int = START_CREDITS:
	set(value):
		credits = maxi(value, 0)
		credits_changed.emit(credits)
var district: String = START_DISTRICT:
	set(value):
		district = value
		district_changed.emit(district)
var day: int = START_DAY
var minute_of_day: int = START_MINUTE
var heat: int = 2:
	set(value):
		heat = value
		heat_changed.emit(heat)
var alerts: int = 2:
	set(value):
		alerts = value
		alerts_changed.emit(alerts)
var workspace_collapsed := false
var active_module: StringName = &""
var module_open := false

func add_credits(delta_credits: int) -> void:
	credits += delta_credits

func advance_minutes(minutes: int) -> void:
	minute_of_day += minutes
	while minute_of_day >= 1440:
		minute_of_day -= 1440
		day += 1
	clock_changed.emit(day, minute_of_day)

func set_workspace_collapsed(collapsed: bool) -> void:
	if workspace_collapsed == collapsed:
		return
	workspace_collapsed = collapsed
	workspace_collapsed_changed.emit(collapsed)

func set_active_module(id: StringName) -> void:
	if active_module == id:
		return
	active_module = id
	active_module_changed.emit(id)

func set_module_open(open: bool) -> void:
	if module_open == open:
		return
	module_open = open
	module_open_changed.emit(open)

func toggle_workspace() -> void:
	set_workspace_collapsed(not workspace_collapsed)

func push_ticker(text: String, highlight: bool = false) -> void:
	ticker_message.emit(text, highlight)

func clock_text() -> String:
	return "%02d:%02d" % [floori(minute_of_day / 60.0), minute_of_day % 60]

static func format_credits(amount: int) -> String:
	var digits := str(amount)
	var out := ""
	while digits.length() > 3:
		out = "," + digits.substr(digits.length() - 3) + out
		digits = digits.substr(0, digits.length() - 3)
	return digits + out
