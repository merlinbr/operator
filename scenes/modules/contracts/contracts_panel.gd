extends PanelContainer
## Contracts module: the contract network list.

signal contract_selected(contract_id: StringName)

const GameStateScript := preload("res://autoload/game_state.gd")
const ContactCatalog := preload("res://data/contacts/contact_catalog.gd")
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

func setup(gs: Node, data: Variant = null) -> void:
	_build_children()
	var contracts: Array = data if data is Array else []
	for child in _rows_box.get_children():
		child.free()
	for contract: Dictionary in contracts:
		var btn := Button.new()
		btn.text = _row_text(contract, gs)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.focus_mode = Control.FOCUS_NONE
		var selectable: bool = contract.status == &"active" or gs.is_contract_available(contract)
		btn.disabled = not selectable
		if selectable:
			btn.pressed.connect(_on_row.bind(contract.id))
		_rows_box.add_child(btn)

func _row_text(contract: Dictionary, gs: Node) -> String:
	if not contract.is_playable:
		return "%s   NETWORK OFFLINE" % contract.title
	if contract.status == &"available" and not gs.is_contract_available(contract):
		var contact := ContactCatalog.by_id(contract.contact_id)
		return "%s // %s REQUIRED" % [
			contact.display_name,
			ContactCatalog.standing_label(int(contract.minimum_contact_standing)),
		]
	match contract.status:
		&"active":
			return "ACTIVE // " + contract.title
		&"completed":
			return "COMPLETED // " + contract.title
		&"failed":
			return "FAILED // " + contract.title
		&"expired":
			return "EXPIRED // " + contract.title
		_:
			return "%s   %s CR" % [contract.title, GameStateScript.format_credits(contract.reward_credits)]

func _on_row(contract_id: StringName) -> void:
	contract_selected.emit(contract_id)
