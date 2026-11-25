extends Node
## frame_fx.gd — the dark edges and the flash.
##
## Presentation only. It never reads a rule, never blocks input and never
## changes what the player can reach. Two things: a soft vignette that keeps the
## far end of the set from competing with the near end, and a single flash drawn
## UNDER the slate (layer 19 vs 20) so the board always stays legible.

const VIGNETTE_INK := Color(0.02, 0.02, 0.025)

var _flash: ColorRect
var _flash_layer: CanvasLayer
var _tween: Tween
var _edge_tween: Tween
var _bars: Array[ColorRect] = []
var _last_edge_ms: int = -1000
var _last_flash_ms: int = -1000


func _ready() -> void:
	var vignette_layer := CanvasLayer.new()
	vignette_layer.name = "Vignette"
	vignette_layer.layer = 5
	add_child(vignette_layer)

	var grad := Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0.0))
	grad.set_color(1, Color(0, 0, 0, 0.72))
	# A wide soft shoulder: a two-stop ramp on a radial texture bands visibly
	# once it is stretched over a 1440p frame.
	grad.add_point(0.55, Color(0, 0, 0, 0.02))
	grad.add_point(0.80, Color(0, 0, 0, 0.26))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.04, 1.04)
	tex.width = 1024
	tex.height = 1024

	var vig := TextureRect.new()
	vig.name = "Edges"
	vig.texture = tex
	vig.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vig.stretch_mode = TextureRect.STRETCH_SCALE
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette_layer.add_child(vig)

	_flash_layer = CanvasLayer.new()
	_flash_layer.name = "Flash"
	_flash_layer.layer = 19
	add_child(_flash_layer)
	_flash = ColorRect.new()
	_flash.name = "Flash"
	_flash.color = Color(1, 1, 1, 0)
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_layer.add_child(_flash)
	for bottom: bool in [false, true]:
		var bar := ColorRect.new()
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.color = Color(1, 1, 1, 0)
		bar.anchor_right = 1.0
		if bottom:
			bar.anchor_top = 1.0
			bar.anchor_bottom = 1.0
			bar.offset_top = -6.0
		else:
			bar.offset_bottom = 6.0
		_flash_layer.add_child(bar)
		_bars.append(bar)


## One flash, one decay. A second call replaces the first rather than stacking:
## two flashes at once read as a bug, not as impact.
func flash(tint: Color, peak := 0.28, hold := 0.02, fade := 0.18) -> void:
	var now: int = Time.get_ticks_msec()
	if _reduce_motion():
		if now - _last_flash_ms < 500: return
		peak *= 0.5
		fade = maxf(fade, 0.25)
	_last_flash_ms = now
	if _flash == null:
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_flash.color = Color(tint.r, tint.g, tint.b, peak)
	_tween = create_tween()
	if hold > 0.0:
		_tween.tween_interval(hold)
	_tween.tween_property(_flash, "color:a", 0.0, fade)


func edge_pulse(tint: Color, peak: float = 0.22, hold: float = 0.18) -> void:
	var now: int = Time.get_ticks_msec()
	if _reduce_motion():
		if now - _last_edge_ms < 500: return
		peak *= 0.5
	_last_edge_ms = now
	if _edge_tween != null and _edge_tween.is_valid(): _edge_tween.kill()
	for bar: ColorRect in _bars: bar.color = Color(tint.r, tint.g, tint.b, peak)
	_edge_tween = create_tween()
	_edge_tween.tween_interval(hold)
	_edge_tween.tween_method(_set_edge_alpha, peak, 0.0, 0.28)


func _reduce_motion() -> bool:
	# Resolve at runtime: these scripts are also preloaded by standalone tests.
	var session: Node = get_node_or_null("/root/GameSession")
	if session == null: return false
	var settings: Dictionary = session.get("settings")
	return bool(settings.get("reduce_motion", false))


func _set_edge_alpha(alpha: float) -> void:
	for bar: ColorRect in _bars: bar.color.a = alpha
