extends Control

const ART_SIZE := Vector2(1672.0, 941.0)
const WINDOW_UV_RECT := Rect2(0.555, 0.136, 0.219, 0.435)
const ApartmentTexture := preload("res://assets/tier-1-appartment.png")

var _background: TextureRect
var _window_rain: ColorRect

const RainShader := preload("res://scenes/main/rain.gdshader")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)

	_background = TextureRect.new()
	_background.name = "ApartmentBackground"
	_background.texture = ApartmentTexture
	_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_background)

	_window_rain = ColorRect.new()
	_window_rain.name = "WindowRain"
	_window_rain.color = Color.WHITE
	_window_rain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rain_material := ShaderMaterial.new()
	rain_material.shader = RainShader
	_window_rain.material = rain_material
	add_child(_window_rain)

	resized.connect(apply_environment_layout)
	# First layout: _ready may run before the parent assigns our final size.
	await get_tree().process_frame
	apply_environment_layout()

func art_rect_for(viewport_size: Vector2) -> Rect2:
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return Rect2()
	var scale := maxf(viewport_size.x / ART_SIZE.x, viewport_size.y / ART_SIZE.y)
	var art_size := ART_SIZE * scale
	var origin := (viewport_size - art_size) * 0.5
	return Rect2(origin, art_size)

func window_rect_for(viewport_size: Vector2) -> Rect2:
	var art_rect := art_rect_for(viewport_size)
	return Rect2(
		art_rect.position + Vector2(
			art_rect.size.x * WINDOW_UV_RECT.position.x,
			art_rect.size.y * WINDOW_UV_RECT.position.y),
		Vector2(
			art_rect.size.x * WINDOW_UV_RECT.size.x,
			art_rect.size.y * WINDOW_UV_RECT.size.y))

func apply_environment_layout() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var art_rect := art_rect_for(size)
	_background.position = art_rect.position
	_background.size = art_rect.size
	var window_rect := window_rect_for(size)
	_window_rain.position = window_rect.position
	_window_rain.size = window_rect.size
