extends PanelContainer

const COLOR_AMBER := Color(1.0, 0.82353, 0.47843)
const COLOR_DIM := Color(0.43529, 0.5451, 0.60392, 1)

var _content: VBoxContainer

func _ready() -> void:
	_build_children()

func _build_children() -> void:
	if _content != null:
		return
	var scroll := ScrollContainer.new()
	scroll.name = "DossierScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.follow_focus = true
	scroll.focus_mode = Control.FOCUS_ALL
	scroll.get_v_scroll_bar().focus_mode = Control.FOCUS_ALL
	add_child(scroll)
	_content = VBoxContainer.new()
	_content.name = "DossierContent"
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 8)
	scroll.add_child(_content)

func _add_label(text: String, heading: bool = false) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if heading:
		label.add_theme_color_override("font_color", COLOR_AMBER)
	_content.add_child(label)

func setup(gs: Node, data: Variant = null) -> void:
	_build_children()
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	var snapshot: Dictionary = data if data is Dictionary else gs.dossier_snapshot()
	_add_label("DOSSIER", true)
	var title := _content.get_child(0) as Label
	title.add_theme_font_override("font", load("res://assets/fonts/JetBrainsMono-Bold.ttf"))
	title.add_theme_font_size_override("font_size", 17)
	_add_label("WORK SIGNATURE", true)
	var signature: Dictionary = snapshot.signature
	_add_label("CLEAN %d // AGGRESSIVE %d // COMMUNITY %d" % [
		signature.clean, signature.aggressive, signature.community])
	_add_label("Clean: no added Heat. Aggressive: Heat-generating route. "
		+ "Community: completed clinic work; overlaps either route.")
	var explanation := _content.get_child(_content.get_child_count() - 1) as Label
	explanation.add_theme_color_override("font_color", COLOR_DIM)
	if int(signature.clean) + int(signature.aggressive) == 0:
		_add_label("NO COMPLETED OPERATIONS YET")
	_add_label("EXPOSURE", true)
	_add_label("HEAT %d // %s" % [snapshot.heat, snapshot.heat_band])
	_add_label("RELATIONSHIPS", true)
	for contact: Dictionary in snapshot.contacts:
		var text := "%s // %s" % [contact.display_name, contact.standing_label]
		if contact.has("favor_label"):
			text += " // " + String(contact.favor_label)
		_add_label(text)
	_add_label("OPERATIONS RECORD", true)
	if snapshot.operations.is_empty():
		_add_label("NO RESOLVED OPERATIONS YET")
	for operation: Dictionary in snapshot.operations:
		_add_label("%s // %s // %s\n%s" % [operation.code, operation.title,
			String(operation.status).to_upper(), operation.outcome])
	if not snapshot.expired_offers.is_empty():
		_add_label("EXPIRED OFFERS", true)
		for offer: Dictionary in snapshot.expired_offers:
			_add_label("%s // %s" % [offer.code, offer.title])
