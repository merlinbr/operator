extends "res://tests/test_base.gd"

const EnvironmentScene := preload("res://scenes/main/environment.tscn")

func _run() -> void:
	var environment: Control = EnvironmentScene.instantiate()
	root.add_child(environment)
	environment.size = Vector2(1920.0, 1080.0)
	environment.apply_environment_layout()

	var art_16x9: Rect2 = environment.art_rect_for(Vector2(1920.0, 1080.0))
	check(art_16x9.position.length() <= 1.0
		and art_16x9.size.distance_to(Vector2(1920.0, 1080.0)) <= 1.0,
		"16:9 art occupies the viewport")
	var art_square: Rect2 = environment.art_rect_for(Vector2(1000.0, 1000.0))
	check(is_equal_approx(art_square.size.y, 1000.0) and art_square.size.x > 1000.0,
		"non-16:9 viewport crops covered artwork horizontally")

	var background: TextureRect = environment.get_node("ApartmentBackground")
	check(background.texture != null, "Tier 1 apartment texture is assigned")
	check(background.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_COVERED,
		"background uses aspect-preserving cover crop")
	check(background.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"background ignores pointer input")

	environment.queue_free()
