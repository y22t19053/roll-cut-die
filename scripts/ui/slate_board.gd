extends Control
## SlateBoard — draws the clapperboard. All state, no timing.
##
## Drawn rather than imported for the first pass: it can be reshaped in one file
## and it renders identically in a headless capture. The final asset pass can
## replace this with a modelled board without touching the sequence code.

var alpha := 0.0
var stick := -0.30  # radians; negative = open, 0 = shut
var headline := ""
var subline := ""
var corner := ""
var accent := Color(1.0, 0.96, 0.88)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _draw() -> void:
	if alpha <= 0.004:
		return
	var vp := size
	if vp.x < 4.0 or vp.y < 4.0:
		return
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.02, 0.02, 0.025, 0.60 * alpha))

	var bw := minf(vp.x * 0.64, 760.0)
	var bh := bw * 0.32
	var origin := Vector2((vp.x - bw) * 0.5, (vp.y - bh) * 0.5)

	# board body
	draw_rect(Rect2(origin, Vector2(bw, bh)), Color(0.93, 0.92, 0.88, alpha))

	# clap stick, hinged at the top-left corner of the board
	var band_h := bh * 0.30
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
		draw_string(font, Vector2(origin.x + pad, origin.y + bh - bh * 0.10), corner,
			HORIZONTAL_ALIGNMENT_LEFT, bw - pad * 2.0, int(bh * 0.11), Color(0.30, 0.30, 0.31, alpha))


func _draw_stripes(r: Rect2, a: float, count: int) -> void:
	var col := Color(0.93, 0.92, 0.88, a)
	var step := r.size.x / float(count)
	var x := r.position.x - r.size.y
	while x < r.position.x + r.size.x + r.size.y:
		var p := PackedVector2Array([
			Vector2(x, r.position.y + r.size.y),
			Vector2(x + step * 0.45, r.position.y + r.size.y),
			Vector2(x + step * 0.45 + r.size.y, r.position.y),
			Vector2(x + r.size.y, r.position.y),
		])
		draw_colored_polygon(p, col)
		x += step
