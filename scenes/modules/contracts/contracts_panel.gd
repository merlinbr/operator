extends PanelContainer
## Contracts module: the contract network list.

signal contract_selected(contract: Dictionary)

const GameStateScript := preload("res://autoload/game_state.gd")
const COLOR_DIM := Color(0.43529, 0.5451, 0.60392, 1)

var _rows_box: VBoxContainer
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
	vbox.add_theme_constant_override("separation", 8)
	add_child(vbox)
	var title := Label.new()
	title.text = "CONTRACT NETWORK"
	title.add_theme_font_override("font", load("res://assets/fonts/JetBrainsMono-Bold.ttf"))
	title.add_theme_font_size_override("font_size", 17)
	vbox.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Local          Private"
	subtitle.add_theme_color_override("font_color", COLOR_DIM)
	vbox.add_child(subtitle)
	_rows_box = VBoxContainer.new()
	_rows_box.add_theme_constant_override("separation", 4)
	vbox.add_child(_rows_box)

func setup(_gs: Node, data: Variant = null) -> void:
	_build_children()
	var contracts: Array = data if data is Array else []
	for child in _rows_box.get_children():
		child.queue_free()
	for contract: Dictionary in contracts:
		var btn := Button.new()
		btn.text = _row_text(contract)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(_on_row.bind(contract))
		_rows_box.add_child(btn)

func _row_text(contract: Dictionary) -> String:
	var reward := "?????" if contract.encrypted else GameStateScript.format_credits(contract.reward_credits) + " CR"
	return "%s   %s" % [contract.title, reward]

func _on_row(contract: Dictionary) -> void:
	if contract.encrypted:
		return # cannot open an encrypted offer yet
	contract_selected.emit(contract)
