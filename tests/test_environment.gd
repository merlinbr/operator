extends "res://tests/test_base.gd"

const EnvironmentScene := preload("res://scenes/main/environment.tscn")
const ApartmentTexture := preload("res://assets/tier-1-appartment.png")
const LoftTexture := preload("res://assets/tier-2-appartment-update.png")
const ART_SIZE := Vector2(1672.0, 941.0)
const WINDOW_UV_RECT := Rect2(0.555, 0.136, 0.219, 0.435)
const GlintShader := preload("res://scenes/main/glints.gdshader")

const GameStateScript := preload("res://autoload/game_state.gd")
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
	var rain_material := window_rain.material as ShaderMaterial
	check(rain_material != null
		and rain_material.shader != null
		and rain_material.shader.resource_path == "res://scenes/main/rain.gdshader",
		"window rain references the exact local rain shader")
	check(window_rain.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"window rain ignores pointer input")
	check(window_rain.size.x < environment.size.x
		and window_rain.size.y < environment.size.y,
		"window rain is smaller than the environment viewport")

	var layer_names: Array[StringName] = []
	for child in environment.get_children():
		layer_names.append(child.name)
	check(layer_names == [&"ApartmentBackground", &"WindowRain", &"ExteriorLight", &"Lightning"],
		"environment visual layers keep their rendering order")

	var exterior_light: Control = environment.get_node("ExteriorLight")
	var ambient_grade: ColorRect = exterior_light.get_node("AmbientGrade")
	var expected_room_grade: Rect2 = environment._art_space_rect_for(
		environment.size, environment.ROOM_FLASH_UV_RECT)
	check(ambient_grade.get_index() == 0 and ambient_grade.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"ambient grade is the input-safe first exterior-light child")
	check(ambient_grade.position.is_equal_approx(expected_room_grade.position)
		and ambient_grade.size.is_equal_approx(expected_room_grade.size),
		"ambient grade follows the existing room art rectangle")
	check(not environment.get_children().has(ambient_grade),
		"ambient grade is nested and preserves the four direct environment layers")
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
	var monitor_glints: ColorRect = exterior_light.get_node("MonitorGlints")
	var neon_glints: ColorRect = exterior_light.get_node("NeonGlints")
	var kitchen_glints: ColorRect = exterior_light.get_node("KitchenGlints")
	check(monitor_glints.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and neon_glints.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and kitchen_glints.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"marked glints ignore pointer input")
	var monitor_material := monitor_glints.material as ShaderMaterial
	var neon_material := neon_glints.material as ShaderMaterial
	var kitchen_material := kitchen_glints.material as ShaderMaterial
	check(monitor_material != null and neon_material != null and kitchen_material != null
		and monitor_material.shader == GlintShader
		and neon_material.shader == GlintShader
		and kitchen_material.shader == GlintShader,
		"marked glints share the local glint shader")
	var expected_monitor: Rect2 = environment._art_space_rect_for(
		environment.size, Rect2(0.075, 0.39, 0.17, 0.20))
	var expected_neon: Rect2 = environment._art_space_rect_for(
		environment.size, Rect2(0.70, 0.13, 0.12, 0.43))
	var expected_kitchen: Rect2 = environment._art_space_rect_for(
		environment.size, Rect2(0.84, 0.30, 0.13, 0.11))
	check(monitor_glints.position.is_equal_approx(expected_monitor.position)
		and monitor_glints.size.is_equal_approx(expected_monitor.size)
		and neon_glints.position.is_equal_approx(expected_neon.position)
		and neon_glints.size.is_equal_approx(expected_neon.size)
		and kitchen_glints.position.is_equal_approx(expected_kitchen.position)
		and kitchen_glints.size.is_equal_approx(expected_kitchen.size)
		and monitor_glints.size.x < environment.size.x
		and neon_glints.size.x < environment.size.x
		and kitchen_glints.size.x < environment.size.x,
		"marked glints stay localized to art-space rectangles")

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

	var gs := GameStateScript.new()
	gs.name = "TimeState"
	root.add_child(gs)
	gs.reset_profile()
	check(environment.time_band_for(179) == &"night"
		and environment.time_band_for(180) == &"pre_dawn"
		and environment.time_band_for(359) == &"pre_dawn"
		and environment.time_band_for(360) == &"daylight"
		and environment.time_band_for(1199) == &"daylight"
		and environment.time_band_for(1200) == &"night",
		"time bands classify every authored boundary")
	check(environment.time_band_for(-1) == &"night"
		and environment.time_band_for(1440) == &"night",
		"time bands normalize minutes into one day")

	environment.size = Vector2(1920.0, 1080.0)
	environment.apply_environment_layout()
	environment.setup(gs)
	check(environment._time_band == &"night"
		and background.modulate.is_equal_approx(Color.WHITE)
		and is_equal_approx(window_rain.modulate.a, 1.0),
		"initial GameState setup applies night targets immediately")
	var studio_profile: Dictionary = environment._art_profile
	var loft_profile: Dictionary = environment.ART_PROFILES[&"sector_9_loft"]
	check(background.texture == ApartmentTexture
		and background.texture.resource_path == "res://assets/tier-1-appartment.png"
		and studio_profile.source_size == ART_SIZE
		and studio_profile.window == WINDOW_UV_RECT,
		"Studio selects its existing artwork and authored profile")
	check(LoftTexture.resource_path == "res://assets/tier-2-appartment-update.png"
		and LoftTexture.get_width() == 1672 and LoftTexture.get_height() == 941,
		"Loft artwork uses the required 1672x941 asset")
	check(loft_profile.source_size == Vector2(1672.0, 941.0)
		and loft_profile.window != studio_profile.window
		and loft_profile.cyan_spill != studio_profile.cyan_spill
		and loft_profile.magenta_spill != studio_profile.magenta_spill
		and loft_profile.monitor_glints != studio_profile.monitor_glints
		and loft_profile.neon_glints != studio_profile.neon_glints
		and loft_profile.kitchen_glints != studio_profile.kitchen_glints
		and loft_profile.room_flash != studio_profile.room_flash,
		"Loft has a separately authored window, spill, glint, and lightning profile")
	var loft_cutouts: Array = loft_profile.get("rain_cutouts", [])
	check(loft_cutouts.size() == 3,
		"Loft has authored rain exclusions for foreground objects")
	var loft_lamp_glow: Rect2 = loft_profile.get("lamp_glow", Rect2())
	check(loft_lamp_glow.size.x > 0.0 and loft_lamp_glow.size.y > 0.0
		and not studio_profile.has("lamp_glow"),
		"Loft has an authored table-lamp glow region")
	gs.current_residence_id = &"sector_9_loft"
	gs.residence_changed.emit(gs.current_residence_id)
	var loft_window_rect: Rect2 = environment._art_space_rect_for(
		environment.size, loft_profile.window)
	check(background.texture == LoftTexture
		and background.texture.resource_path == "res://assets/tier-2-appartment-update.png"
		and environment._art_profile == loft_profile
		and window_rain.position.is_equal_approx(loft_window_rect.position)
		and window_rain.size.is_equal_approx(loft_window_rect.size),
		"residence change selects Loft artwork and remaps its window")
	if loft_cutouts.size() == 3:
		var rain_mask_applied := true
		for index in loft_cutouts.size():
			var cutout: Rect2 = loft_cutouts[index]
			var expected_cutout := Vector4(
				cutout.position.x, cutout.position.y, cutout.size.x, cutout.size.y)
			rain_mask_applied = rain_mask_applied \
				and rain_material.get_shader_parameter("rain_cutout_%d" % index) == expected_cutout
		check(rain_mask_applied, "Loft rain shader receives authored exclusions")
	var loft_layer_names: Array[StringName] = []
	for child in environment.get_children():
		loft_layer_names.append(child.name)
	check(loft_layer_names == [&"ApartmentBackground", &"WindowRain", &"ExteriorLight", &"Lightning"]
		and environment.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and background.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and window_rain.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and exterior_light.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and lightning.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"Loft switch preserves environment layer order and mouse filtering")
	var lamp_glow := exterior_light.get_node_or_null("LampGlow") as TextureRect
	var lamp_glow_ready := lamp_glow != null
	if lamp_glow != null:
		var lamp_texture := lamp_glow.texture as GradientTexture2D
		var lamp_rect: Rect2 = environment._art_space_rect_for(environment.size, loft_lamp_glow)
		lamp_glow_ready = lamp_glow.visible \
			and lamp_glow.position.is_equal_approx(lamp_rect.position) \
			and lamp_glow.size.is_equal_approx(lamp_rect.size) \
			and lamp_glow.mouse_filter == Control.MOUSE_FILTER_IGNORE \
			and lamp_texture != null \
			and lamp_texture.fill == GradientTexture2D.FILL_RADIAL \
			and lamp_texture.gradient.get_color(0).r > lamp_texture.gradient.get_color(0).b
	check(lamp_glow_ready, "Loft renders a warm localized lamp glow")
	if lamp_glow != null:
		var lamp_alpha_before := lamp_glow.modulate.a
		environment._process(0.7)
		var lamp_alpha_after := lamp_glow.modulate.a
		check(absf(lamp_alpha_after - lamp_alpha_before) > 0.005
			and lamp_alpha_after > 0.15 and lamp_alpha_after < 0.35,
			"Lamp glow flickers within a restrained warm range")
	var expected_loft_cyan: Rect2 = environment._art_space_rect_for(environment.size, loft_profile.cyan_spill)
	var expected_loft_magenta: Rect2 = environment._art_space_rect_for(environment.size, loft_profile.magenta_spill)
	var expected_loft_monitor: Rect2 = environment._art_space_rect_for(environment.size, loft_profile.monitor_glints)
	var expected_loft_neon: Rect2 = environment._art_space_rect_for(environment.size, loft_profile.neon_glints)
	var expected_loft_kitchen: Rect2 = environment._art_space_rect_for(environment.size, loft_profile.kitchen_glints)
	var expected_loft_room: Rect2 = environment._art_space_rect_for(environment.size, loft_profile.room_flash)
	check(cyan_spill.position.is_equal_approx(expected_loft_cyan.position)
		and cyan_spill.size.is_equal_approx(expected_loft_cyan.size)
		and magenta_spill.position.is_equal_approx(expected_loft_magenta.position)
		and magenta_spill.size.is_equal_approx(expected_loft_magenta.size)
		and monitor_glints.position.is_equal_approx(expected_loft_monitor.position)
		and monitor_glints.size.is_equal_approx(expected_loft_monitor.size)
		and neon_glints.position.is_equal_approx(expected_loft_neon.position)
		and neon_glints.size.is_equal_approx(expected_loft_neon.size)
		and kitchen_glints.position.is_equal_approx(expected_loft_kitchen.position)
		and kitchen_glints.size.is_equal_approx(expected_loft_kitchen.size)
		and ambient_grade.position.is_equal_approx(expected_loft_room.position)
		and ambient_grade.size.is_equal_approx(expected_loft_room.size)
		and room_flash.position.is_equal_approx(expected_loft_room.position)
		and room_flash.size.is_equal_approx(expected_loft_room.size)
		and window_flash.position.is_equal_approx(loft_window_rect.position)
		and window_flash.size.is_equal_approx(loft_window_rect.size),
		"Loft residence remaps every authored effect rectangle")
	gs.current_residence_id = &"lower_vesper_studio"
	gs.residence_changed.emit(gs.current_residence_id)
	check(background.texture == ApartmentTexture
		and environment._art_profile == studio_profile,
		"residence change back selects Studio artwork and profile")
	var same_band_tween: Variant = environment._atmosphere_tween
	gs.minute_of_day = 60
	gs.clock_changed.emit(gs.day, gs.minute_of_day)
	check(environment._time_band == &"night" and environment._atmosphere_tween == same_band_tween,
		"clock updates inside the active band do not restart atmosphere work")

	environment._apply_time_band(&"pre_dawn", true)
	check(environment._time_band == &"pre_dawn"
		and background.modulate.is_equal_approx(Color(0.86, 0.91, 1.0, 1.0))
		and is_equal_approx(window_rain.modulate.a, 0.72)
		and is_equal_approx(environment._spill_multiplier, 0.65)
		and is_equal_approx(ambient_grade.color.a, 0.12),
		"pre-dawn immediate application uses all authored targets")
	environment._apply_time_band(&"daylight", true)
	check(environment._time_band == &"daylight"
		and background.modulate.is_equal_approx(Color(0.94, 1.0, 1.0, 1.0))
		and is_equal_approx(window_rain.modulate.a, 0.40)
		and is_equal_approx(environment._spill_multiplier, 0.30)
		and is_equal_approx(ambient_grade.color.a, 0.06),
		"daylight immediate application uses all authored targets")
	gs.minute_of_day = 1200
	gs.clock_changed.emit(gs.day, gs.minute_of_day)
	check(environment._time_band == &"night" and environment._atmosphere_tween != null,
		"a band crossing starts the night crossfade")
	if environment._atmosphere_tween != null:
		environment._atmosphere_tween.kill()
	gs.queue_free()

	environment.queue_free()
