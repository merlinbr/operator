extends "res://tests/test_base.gd"

const EnvironmentScene := preload("res://scenes/main/environment.tscn")
const ApartmentTexture := preload("res://assets/tier-1-appartment.png")
const ART_SIZE := Vector2(1672.0, 941.0)
const WINDOW_UV_RECT := Rect2(0.555, 0.136, 0.219, 0.435)

func _init() -> void:
	# SceneTree children receive _ready after the base SceneTree is initialized.
	call_deferred("_run_after_ready")

func _run_after_ready() -> void:
	await _run()
	finish()

func _run() -> void:
	var environment: Control = EnvironmentScene.instantiate()
	root.add_child(environment)
	environment.size = Vector2(1920.0, 1080.0)
	environment.apply_environment_layout()
	# Exercise the deferred first layout scheduled by EnvironmentLayer._ready.
	await process_frame

	check(environment.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"environment root ignores pointer input")
	var art_16x9: Rect2 = environment.art_rect_for(Vector2(1920.0, 1080.0))
	check(art_16x9.position.length() <= 1.0
		and art_16x9.size.distance_to(Vector2(1920.0, 1080.0)) <= 1.0,
		"16:9 art occupies the viewport")
	var background: TextureRect = environment.get_node("ApartmentBackground")
	check(background.position.is_equal_approx(art_16x9.position)
		and background.size.is_equal_approx(art_16x9.size),
		"background follows the fitted artwork rectangle")
	check(background.texture == ApartmentTexture
		and background.texture.resource_path == "res://assets/tier-1-appartment.png",
		"Tier 1 apartment texture is assigned from the required path")
	check(background.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_COVERED,
		"background uses aspect-preserving cover crop")
	check(background.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"background ignores pointer input")

	var window_rain: Control = environment.get_node("WindowRain")
	var expected_window_16x9: Rect2 = environment.window_rect_for(environment.size)
	check(window_rain is ColorRect, "window rain is a ColorRect")
	check(window_rain.position.is_equal_approx(expected_window_16x9.position)
		and window_rain.size.is_equal_approx(expected_window_16x9.size),
		"window rain follows the mapped window rectangle")
	check(window_rain.material is ShaderMaterial,
		"window rain uses a ShaderMaterial")
	check(window_rain.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"window rain ignores pointer input")
	check(window_rain.size.x < environment.size.x
		and window_rain.size.y < environment.size.y,
		"window rain is smaller than the environment viewport")

	check(environment.get_child_count() == 4
		and environment.get_child(0).name == "ApartmentBackground"
		and environment.get_child(1).name == "WindowRain"
		and environment.get_child(2).name == "ExteriorLight"
		and environment.get_child(3).name == "Lightning",
		"environment layers have the required direct-child order")

	var exterior_light: Control = environment.get_node("ExteriorLight")
	var cyan_spill: TextureRect = exterior_light.get_node("CyanSpill")
	var magenta_spill: TextureRect = exterior_light.get_node("MagentaSpill")
	check(exterior_light.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and cyan_spill.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and magenta_spill.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and cyan_spill is TextureRect
		and magenta_spill is TextureRect,
		"exterior light and both spills ignore pointer input")
	var cyan_texture := cyan_spill.texture as GradientTexture2D
	var magenta_texture := magenta_spill.texture as GradientTexture2D
	check(cyan_texture != null and magenta_texture != null
		and cyan_texture.fill == GradientTexture2D.FILL_RADIAL
		and magenta_texture.fill == GradientTexture2D.FILL_RADIAL
		and cyan_spill.stretch_mode == TextureRect.STRETCH_SCALE
		and magenta_spill.stretch_mode == TextureRect.STRETCH_SCALE,
		"spills use radial gradient textures and scaled stretching")
	check(cyan_texture.gradient.get_color(0).a > 0.0
		and cyan_texture.gradient.get_color(1).a == 0.0
		and magenta_texture.gradient.get_color(0).a > 0.0
		and magenta_texture.gradient.get_color(1).a == 0.0
		and cyan_spill.modulate.a > 0.0 and cyan_spill.modulate.a <= 0.12
		and magenta_spill.modulate.a > 0.0 and magenta_spill.modulate.a <= 0.10,
		"spills have colored centers, transparent edges, and faint alpha")
	var cyan_center: Color = cyan_texture.gradient.get_color(0)
	var magenta_center: Color = magenta_texture.gradient.get_color(0)
	check(cyan_center.g > cyan_center.r and cyan_center.b > cyan_center.r
		and magenta_center.r > magenta_center.g
		and magenta_center.b > magenta_center.g,
		"spill centers retain distinct cyan and magenta colors")
	var expected_cyan: Rect2 = environment._art_space_rect_for(
		environment.size, Rect2(0.43, 0.43, 0.24, 0.26))
	var expected_magenta: Rect2 = environment._art_space_rect_for(
		environment.size, Rect2(0.68, 0.46, 0.22, 0.28))
	check(cyan_spill.position.is_equal_approx(expected_cyan.position)
		and cyan_spill.size.is_equal_approx(expected_cyan.size)
		and magenta_spill.position.is_equal_approx(expected_magenta.position)
		and magenta_spill.size.is_equal_approx(expected_magenta.size)
		and cyan_spill.size.x < environment.size.x
		and cyan_spill.size.y < environment.size.y
		and magenta_spill.size.x < environment.size.x
		and magenta_spill.size.y < environment.size.y,
		"spills stay localized to normalized artwork rectangles")

	var lightning: Control = environment.get_node("Lightning")
	var lightning_timer: Timer = lightning.get_node("LightningTimer")
	var window_flash: ColorRect = lightning.get_node("WindowFlash")
	var room_flash: ColorRect = lightning.get_node("RoomFlash")
	check(lightning.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and lightning_timer.get_parent() == lightning
		and lightning_timer.one_shot
		and lightning_timer.wait_time >= 45.0
		and lightning_timer.wait_time <= 150.0
		and lightning_timer.time_left > 0.0,
		"lightning ignores input and owns a scheduled one-shot timer")
	check(window_flash.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and room_flash.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and is_zero_approx(window_flash.modulate.a)
		and is_zero_approx(room_flash.modulate.a),
		"lightning flashes ignore input and start transparent")
	check(window_flash.position.is_equal_approx(expected_window_16x9.position)
		and window_flash.size.is_equal_approx(expected_window_16x9.size)
		and room_flash.size.x < environment.size.x
		and room_flash.size.y < environment.size.y,
		"window flash maps to the window and room flash stays local")
	environment._trigger_lightning()
	check(window_flash.modulate.a > 0.0 and room_flash.modulate.a > 0.0,
		"lightning trigger raises both flash alphas immediately")
	await create_timer(0.30).timeout
	check(window_flash.modulate.a <= 0.01 and room_flash.modulate.a <= 0.01,
		"lightning flashes decay back to transparent")

	var square_size := Vector2(1000.0, 1000.0)
	var square_scale := maxf(square_size.x / ART_SIZE.x, square_size.y / ART_SIZE.y)
	var square_art_size := ART_SIZE * square_scale
	var expected_square := Rect2((square_size - square_art_size) * 0.5, square_art_size)
	var art_square: Rect2 = environment.art_rect_for(square_size)
	check(art_square.position.is_equal_approx(expected_square.position)
		and art_square.size.is_equal_approx(expected_square.size),
		"square viewport uses exact horizontal cover crop")

	var expected_window := Rect2(
		expected_square.position + expected_square.size * WINDOW_UV_RECT.position,
		expected_square.size * WINDOW_UV_RECT.size)
	var window_square: Rect2 = environment.window_rect_for(square_size)
	check(window_square.position.is_equal_approx(expected_window.position)
		and window_square.size.is_equal_approx(expected_window.size),
		"window rectangle maps through cropped artwork geometry")
	check(environment.window_rect_for(Vector2.ZERO) == Rect2()
		and environment.window_rect_for(Vector2(-1.0, 10.0)) == Rect2(),
		"window rectangle is empty for zero or negative dimensions")

	# The resized signal must apply the same mapping without an explicit call.
	environment.size = square_size
	check(background.position.is_equal_approx(expected_square.position)
		and background.size.is_equal_approx(expected_square.size),
		"resize signal reapplies cropped background layout")

	environment.apply_environment_layout()
	check(window_rain.position.is_equal_approx(expected_window.position)
		and window_rain.size.is_equal_approx(expected_window.size),
		"window rain follows mapped window after non-16:9 resize")

	environment.size = Vector2.ZERO
	environment.apply_environment_layout()
	check(background.size.x >= 0.0 and background.size.y >= 0.0,
		"zero-size layout does not create invalid background geometry")
	check(environment.art_rect_for(Vector2.ZERO) == Rect2()
		and environment.art_rect_for(Vector2(-1.0, -1.0)) == Rect2(),
		"art rectangle is empty for zero or negative dimensions")

	environment.queue_free()
