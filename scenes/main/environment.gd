extends Control

const ART_SIZE := Vector2(1672.0, 941.0)
const WINDOW_UV_RECT := Rect2(0.555, 0.136, 0.219, 0.435)
const CYAN_SPILL_UV_RECT := Rect2(0.43, 0.43, 0.24, 0.26)
const MAGENTA_SPILL_UV_RECT := Rect2(0.68, 0.46, 0.22, 0.28)
const ROOM_FLASH_UV_RECT := Rect2(0.16, 0.08, 0.72, 0.82)
const ApartmentTexture := preload("res://assets/tier-1-appartment.png")

const RainShader := preload("res://scenes/main/rain.gdshader")

var _background: TextureRect
var _window_rain: ColorRect
var _exterior_light: Control
var _cyan_spill: TextureRect
var _magenta_spill: TextureRect
var _lightning: Control
var _window_flash: ColorRect
var _room_flash: ColorRect
var _lightning_timer: Timer
var _flash_tween: Tween
var _light_time := 0.0
var _light_rng := RandomNumberGenerator.new()

const CYAN_PERIOD := 13.0
const MAGENTA_PERIOD := 19.0

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

	_exterior_light = Control.new()
	_exterior_light.name = "ExteriorLight"
	_exterior_light.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_exterior_light.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cyan_spill = _make_spill("CyanSpill", Color("#39e6ff"), 0.11)
	_magenta_spill = _make_spill("MagentaSpill", Color("#f25dff"), 0.09)
	_exterior_light.add_child(_cyan_spill)
	_exterior_light.add_child(_magenta_spill)
	add_child(_exterior_light)

	_lightning = Control.new()
	_lightning.name = "Lightning"
	_lightning.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lightning.set_anchors_preset(Control.PRESET_FULL_RECT)
	_window_flash = ColorRect.new()
	_window_flash.name = "WindowFlash"
	_window_flash.color = Color(0.62, 0.84, 1.0, 1.0)
	_window_flash.modulate.a = 0.0
	_window_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_room_flash = ColorRect.new()
	_room_flash.name = "RoomFlash"
	_room_flash.color = Color(0.53, 0.70, 1.0, 1.0)
	_room_flash.modulate.a = 0.0
	_room_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lightning.add_child(_window_flash)
	_lightning.add_child(_room_flash)
	_lightning_timer = Timer.new()
	_lightning_timer.name = "LightningTimer"
	_lightning_timer.one_shot = true
	_lightning_timer.timeout.connect(_on_lightning_timeout)
	_lightning.add_child(_lightning_timer)
	add_child(_lightning)

	_light_rng.randomize()
	_schedule_next_lightning()

	resized.connect(apply_environment_layout)
	# First layout: _ready may run before the parent assigns our final size.
	await get_tree().process_frame
	apply_environment_layout()

func _process(delta: float) -> void:
	_light_time += delta
	_cyan_spill.modulate.a = 0.09 + 0.02 * sin(_light_time * TAU / CYAN_PERIOD)
	_magenta_spill.modulate.a = 0.075 + 0.018 * sin(_light_time * TAU / MAGENTA_PERIOD + 1.4)

func _make_spill(spill_name: String, color: Color, center_alpha: float) -> TextureRect:
	var spill := TextureRect.new()
	spill.name = spill_name
	spill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spill.stretch_mode = TextureRect.STRETCH_SCALE
	var texture := GradientTexture2D.new()
	texture.gradient = _make_gradient(color)
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	spill.texture = texture
	spill.modulate = Color(1.0, 1.0, 1.0, center_alpha)
	return spill

func _make_gradient(color: Color) -> Gradient:
	var gradient := Gradient.new()
	var edge_color := color
	edge_color.a = 0.0
	gradient.set_color(0, color)
	gradient.set_color(1, edge_color)
	return gradient

func _art_space_rect_for(viewport_size: Vector2, normalized_rect: Rect2) -> Rect2:
	var art_rect := art_rect_for(viewport_size)
	return Rect2(
		art_rect.position + art_rect.size * normalized_rect.position,
		art_rect.size * normalized_rect.size)

func _schedule_next_lightning() -> void:
	if not is_inside_tree():
		return
	_lightning_timer.start(_light_rng.randf_range(45.0, 150.0))

func _on_lightning_timeout() -> void:
	if not is_inside_tree():
		return
	_trigger_lightning()
	_schedule_next_lightning()
	if _light_rng.randf() < 0.25:
		_trigger_delayed_secondary()

func _trigger_delayed_secondary() -> void:
	await get_tree().create_timer(0.18).timeout
	if is_inside_tree():
		_trigger_lightning(0.35)

func _trigger_lightning(strength: float = 1.0) -> void:
	var safe_strength := strength
	if not is_finite(safe_strength):
		safe_strength = 0.0
	safe_strength = clampf(safe_strength, 0.0, 1.0)
	_window_flash.modulate.a = 0.18 * safe_strength
	_room_flash.modulate.a = 0.07 * safe_strength
	if _flash_tween != null:
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.set_parallel()
	_flash_tween.tween_property(_window_flash, "modulate:a", 0.0, 0.16)
	_flash_tween.tween_property(_room_flash, "modulate:a", 0.0, 0.20)

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
	var cyan_rect := _art_space_rect_for(size, CYAN_SPILL_UV_RECT)
	_cyan_spill.position = cyan_rect.position
	_cyan_spill.size = cyan_rect.size
	var magenta_rect := _art_space_rect_for(size, MAGENTA_SPILL_UV_RECT)
	_magenta_spill.position = magenta_rect.position
	_magenta_spill.size = magenta_rect.size
	var room_flash_rect := _art_space_rect_for(size, ROOM_FLASH_UV_RECT)
	_room_flash.position = room_flash_rect.position
	_room_flash.size = room_flash_rect.size
	_window_flash.position = window_rect.position
	_window_flash.size = window_rect.size
