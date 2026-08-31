extends PanelContainer
## Comms module: message list.

const COLOR_ACCENT := Color(0.22353, 0.81569, 1.0)
const COLOR_DIM := Color(0.43529, 0.5451, 0.60392, 1)

var _rows_box: VBoxContainer
var _contacts_box: VBoxContainer
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
	title.text = "COMMS"
	title.add_theme_font_override("font", load("res://assets/fonts/JetBrainsMono-Bold.ttf"))
	title.add_theme_font_size_override("font_size", 17)
	vbox.add_child(title)
	var contacts_title := Label.new()
	contacts_title.text = "CONTACTS"
	contacts_title.add_theme_color_override("font_color", COLOR_DIM)
	vbox.add_child(contacts_title)
	_contacts_box = VBoxContainer.new()
	_contacts_box.add_theme_constant_override("separation", 4)
	vbox.add_child(_contacts_box)
	_rows_box = VBoxContainer.new()
	_rows_box.add_theme_constant_override("separation", 4)
	vbox.add_child(_rows_box)

func setup(_gs: Node, data: Variant = null) -> void:
	_build_children()
	var snapshot: Dictionary = data if data is Dictionary else {}
	for child in _contacts_box.get_children():
		child.queue_free()
	for contact: Dictionary in snapshot.get("contacts", []):
		_contacts_box.add_child(_make_contact_row(contact))
	for child in _rows_box.get_children():
		child.queue_free()
	for i in snapshot.get("messages", []).size():
		_rows_box.add_child(_make_row(snapshot.messages[i], i))

func _make_contact_row(contact: Dictionary) -> Label:
	var label := Label.new()
	label.text = "%s // %s" % [contact.display_name, contact.standing_label]
	return label

func _make_row(message: Dictionary, index: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "Row%d" % index
	row.add_theme_constant_override("separation", 12)
	var sender := Label.new()
	sender.custom_minimum_size.x = 110.0
	sender.text = ("● " if message.unread else "") + message.sender
	if message.unread:
		sender.add_theme_color_override("font_color", COLOR_ACCENT)
	var preview := Label.new()
	preview.text = message.preview
	preview.add_theme_color_override("font_color", COLOR_DIM)
	preview.clip_text = true
	preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sender)
	row.add_child(preview)
	return row
