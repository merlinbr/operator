extends Control
## Environment placeholder: sky gradient, two parallax skyline layers,
## neon flicker signs, rain. Structured as swappable layers so real art
## can replace each part without code changes. Restrained on purpose.

const PARALLAX_STRENGTH := 8.0
const NEON_CYAN := Color(0.22353, 0.81569, 1.0)
const NEON_PINK := Color(1.0, 0.35294, 0.47059)

var _skyline_far: Polygon2D
var _skyline_near: Polygon2D
var _neon_rects: Array[ColorRect] = []
var _flicker_t: Array[float] = []
var _parallax := Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	resized.connect(_on_resized)
	_build_sky()
	_skyline_far = _make_skyline(Color("0d141c"), 0.42, 9172731)
	_skyline_near = _make_skyline(Color("080d13"), 0.58, 52341987)
	_build_neon()
	_build_rain()
	# First layout: _ready may run before the parent assigns our final size.
	await get_tree().process_frame
	_on_resized()

func _build_sky() -> void:
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	grad.colors = PackedColorArray([Color("050608"), Color("0a0f16"), Color("101820")])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	var sky := TextureRect.new()
	sky.texture = tex
	sky.stretch_mode = TextureRect.STRETCH_SCALE
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sky)

func _make_skyline(color: Color, height_frac: float, seed_value: int) -> Polygon2D:
	var poly := Polygon2D.new()
	poly.color = color
	poly.set_meta("height_frac", height_frac)
	poly.set_meta("seed", seed_value)
	add_child(poly)
	_rebuild_skyline(poly)
	return poly

func _rebuild_skyline(poly: Polygon2D) -> void:
	var height_frac: float = poly.get_meta("height_frac")
	var rng := RandomNumberGenerator.new()
	rng.seed = poly.get_meta("seed")
	var points := PackedVector2Array()
	var base_y := size.y
	var max_drop := size.y * height_frac
	points.append(Vector2(0.0, base_y))
	var x := 0.0
	while x < size.x:
		var bw := rng.randf_range(60.0, 160.0)
		var bh := rng.randf_range(0.35, 1.0) * max_drop
		points.append(Vector2(x, base_y - bh))
		points.append(Vector2(minf(x + bw, size.x), base_y - bh))
		x += bw
	points.append(Vector2(size.x, base_y))
	poly.polygon = points
	poly.position = Vector2.ZERO

func _build_neon() -> void:
	var specs := [
		[NEON_CYAN, Vector2(0.18, 0.62), Vector2(120, 12)],
		[NEON_PINK, Vector2(0.68, 0.48), Vector2(80, 10)],
	]
	for spec: Array in specs:
		var rect := ColorRect.new()
		rect.color = spec[0]
		rect.size = spec[2]
		rect.position = Vector2(size.x * spec[1].x, size.y * spec[1].y)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(rect)
		_neon_rects.append(rect)
		_flicker_t.append(randf() * 2.0)

func _build_rain() -> void:
	var rain := ColorRect.new()
	rain.set_anchors_preset(Control.PRESET_FULL_RECT)
	rain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = FileAccess.get_file_as_string("res://scenes/main/rain.gdshader")
	var mat := ShaderMaterial.new()
	mat.shader = shader
	rain.material = mat
	add_child(rain)

func _on_resized() -> void:
	_rebuild_skyline(_skyline_far)
	_rebuild_skyline(_skyline_near)

func _process(delta: float) -> void:
	for i in _neon_rects.size():
		_flicker_t[i] += delta
		var t := _flicker_t[i]
		var flicker := (0.8 + 0.2 * sin(t * 9.0)) if sin(t * 1.7) > -0.85 else 0.25
		_neon_rects[i].modulate.a = flicker
	_update_parallax(delta)

func _update_parallax(delta: float) -> void:
	if size == Vector2.ZERO:
		return
	var mp := get_viewport().get_mouse_position()
	var center := size * 0.5
	var target := ((mp - center) / center).limit_length(1.0) * PARALLAX_STRENGTH
	_parallax = _parallax.lerp(target, minf(1.0, delta * 3.0))
	_skyline_far.position = Vector2(_parallax.x * 0.35, _parallax.y * 0.2)
	_skyline_near.position = Vector2(_parallax.x * 0.7, _parallax.y * 0.4)
