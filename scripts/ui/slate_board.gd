extends Control
## SlateBoard — draws the clapperboard. All state, no timing.
##
## Drawn rather than imported for the first pass: it can be reshaped in one file
## and it renders identically in a headless capture. The final asset pass can
## replace this with a modelled board without touching the sequence code.

## Widest the clap stick ever opens, radians.
const OPEN_MAX := 0.34
## Screen bands the board and its open stick must never enter: the HUD top bar
## above, the HUD death line and hint below.
const TOP_CLEAR := 60.0
const BOTTOM_CLEAR := 240.0
const HEIGHT_FRAC := 0.32
const BAND_FRAC := 0.30

var alpha := 0.0
var stick := -0.30  # radians; negative = open, 0 = shut
var headline := ""
var subline := ""
var corner := ""
var accent := Color(1.0, 0.96, 0.88)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


## Board width and top-left corner for a viewport, sized so the board plus the
## fully open stick fit between TOP_CLEAR and BOTTOM_CLEAR.
static func board_layout(vp: Vector2) -> Dictionary:
	var room := maxf(vp.y - TOP_CLEAR - BOTTOM_CLEAR, 1.0)
	var bw := minf(minf(vp.x * 0.64, 760.0), room / (stick_reach(1.0) + HEIGHT_FRAC))
	var reach := stick_reach(bw)
	var spare := room - reach - bw * HEIGHT_FRAC
	return {"width": bw, "origin": Vector2((vp.x - bw) * 0.5, TOP_CLEAR + reach + spare * 0.5)}


## How far above the board's top edge the fully open stick's far corner rises.
static func stick_reach(bw: float) -> float:
	var band_h := bw * HEIGHT_FRAC * BAND_FRAC
	return 1.02 * bw * sin(OPEN_MAX) + 1.02 * band_h * cos(OPEN_MAX)


func _draw() -> void:
	if alpha <= 0.004:
		return
	var vp := size
	if vp.x < 4.0 or vp.y < 4.0:
		return
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.02, 0.02, 0.025, 0.60 * alpha))

	var layout := board_layout(vp)
	var bw: float = layout["width"]
	var bh := bw * HEIGHT_FRAC
	var origin: Vector2 = layout["origin"]

	# board body
	draw_rect(Rect2(origin, Vector2(bw, bh)), Color(0.93, 0.92, 0.88, alpha))

	# clap stick, hinged at the top-left corner of the board
	var band_h := bh * BAND_FRAC
	draw_set_transform(origin, stick, Vector2.ONE)
	var stick_rect := Rect2(Vector2(-bw * 0.02, -band_h * 1.02), Vector2(bw * 1.04, band_h * 0.86))
	draw_rect(stick_rect, Color(0.09, 0.09, 0.10, alpha))
	_draw_stripes(stick_rect, alpha * 0.92, 11)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# stripe band on the board itself
	var band := Rect2(origin, Vector2(bw, band_h))
	draw_rect(band, Color(0.08, 0.08, 0.09, alpha))
	_draw_stripes(band, alpha * 0.95, 11)

	# information lines
	var font := ThemeDB.fallback_font
	var pad := bh * 0.10
	var y := origin.y + band_h + bh * 0.26
	if headline != "":
		draw_string(font, Vector2(origin.x + pad, y), headline,
			HORIZONTAL_ALIGNMENT_LEFT, bw - pad * 2.0, int(bh * 0.30), Color(accent.r, accent.g, accent.b, alpha * 0.10))
		draw_string(font, Vector2(origin.x + pad, y), headline,
			HORIZONTAL_ALIGNMENT_LEFT, bw - pad * 2.0, int(bh * 0.30), Color(0.10, 0.10, 0.11, alpha))
	if subline != "":
		draw_string(font, Vector2(origin.x + pad, y + bh * 0.26), subline,
			HORIZONTAL_ALIGNMENT_LEFT, bw - pad * 2.0, int(bh * 0.13), Color(0.20, 0.20, 0.21, alpha))
	if corner != "":
		# Share the subline's row instead of stacking under it: two lines of
		# small type at this width touch, and the take number is the one that
		# has to stay legible.
		var cy := y + bh * 0.26 if subline != "" else origin.y + bh - bh * 0.10
		draw_string(font, Vector2(origin.x + pad, cy), corner,
			HORIZONTAL_ALIGNMENT_RIGHT, bw - pad * 2.0, int(bh * 0.11), Color(0.30, 0.30, 0.31, alpha))


func _draw_stripes(r: Rect2, a: float, count: int) -> void:
	var col := Color(0.93, 0.92, 0.88, a)
	var step := r.size.x / float(count)
	var clip := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end,
		Vector2(r.position.x, r.end.y)])
	var x := r.position.x - r.size.y
	while x < r.position.x + r.size.x + r.size.y:
		var p := PackedVector2Array([
			Vector2(x, r.position.y + r.size.y),
			Vector2(x + step * 0.45, r.position.y + r.size.y),
			Vector2(x + step * 0.45 + r.size.y, r.position.y),
			Vector2(x + r.size.y, r.position.y),
		])
		# Clipped to the band: unclipped, the slanted ends overhang the board.
		for piece: PackedVector2Array in Geometry2D.intersect_polygons(p, clip):
			draw_colored_polygon(piece, col)
		x += step
