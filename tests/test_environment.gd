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

	environment.size = Vector2.ZERO
	environment.apply_environment_layout()
	check(background.size.x >= 0.0 and background.size.y >= 0.0,
		"zero-size layout does not create invalid background geometry")
	check(environment.art_rect_for(Vector2.ZERO) == Rect2()
		and environment.art_rect_for(Vector2(-1.0, -1.0)) == Rect2(),
		"art rectangle is empty for zero or negative dimensions")

	environment.queue_free()
