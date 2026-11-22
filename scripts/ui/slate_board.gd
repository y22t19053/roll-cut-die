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
var take_no := 0
var accent := Color(1.0, 0.96, 0.88)
## Chalk on slate. The board is the one object in the game that must look like a
## physical thing a crew writes on, so it keeps its own two inks and its own type.
var slate_ink := Color(0.086, 0.082, 0.075)
var chalk := Color(0.925, 0.906, 0.855)
var chalk_dim := Color(0.925, 0.906, 0.855, 0.42)
var stamp := Color(0.886, 0.263, 0.180)

var _mono: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Consolas", "Cascadia Mono", "DejaVu Sans Mono", "monospace"])
	_mono = f


## Board width and top-left corner for a viewport, sized so the board plus the
## fully open stick fit between TOP_CLEAR and BOTTOM_CLEAR.
## The board is a lower-third card now: the death frame is the thing being read,
## so the board sits under it and the top two thirds stay clear. The open stick
## still rises into frame, but only for the moment it takes to shut.
static func board_layout(vp: Vector2) -> Dictionary:
	var bw := minf(minf(vp.x * 0.52, 660.0), vp.y * 0.62)
	var bh := bw * HEIGHT_FRAC
	var origin := Vector2((vp.x - bw) * 0.5, vp.y * 0.665 - bh * 0.5)
	return {"width": bw, "origin": origin}


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
	# The dip is weighted to the lower third: the frame that killed you stays
	# readable above the board instead of being dimmed with it.
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.02, 0.02, 0.025, 0.14 * alpha))
	draw_rect(Rect2(0.0, vp.y * 0.56, vp.x, vp.y * 0.44), Color(0.02, 0.02, 0.025, 0.58 * alpha))

	var layout := board_layout(vp)
	var bw: float = layout["width"]
	var bh := bw * HEIGHT_FRAC
	var origin: Vector2 = layout["origin"]

	# board body: black slate, with the bottom edge lit so it still reads as a
	# board and not as a hole punched in the frame
	draw_rect(Rect2(origin, Vector2(bw, bh)), Color(slate_ink.r, slate_ink.g, slate_ink.b, alpha))
	draw_rect(Rect2(origin + Vector2(0, bh - bh * 0.02), Vector2(bw, bh * 0.02)),
		Color(chalk.r, chalk.g, chalk.b, alpha * 0.16))
	draw_rect(Rect2(origin, Vector2(bw, bh)), Color(chalk.r, chalk.g, chalk.b, alpha * 0.22), false, bh * 0.006)

	# clap stick, hinged at the top-left corner of the board
	var band_h := bh * BAND_FRAC
	draw_set_transform(origin, stick, Vector2.ONE)
	var stick_rect := Rect2(Vector2(-bw * 0.02, -band_h * 1.02), Vector2(bw * 1.04, band_h * 0.86))
	draw_rect(stick_rect, Color(0.09, 0.09, 0.10, alpha))
	_draw_stripes(stick_rect, alpha * 0.94, 11)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# stripe band on the board itself
	var band := Rect2(origin, Vector2(bw, band_h))
	draw_rect(band, Color(0.08, 0.08, 0.09, alpha))
	_draw_stripes(band, alpha * 0.96, 11)
	# the hinge, so the two sticks read as one object that opens
	draw_circle(origin + Vector2(bw * 0.02, band_h * 0.5), bh * 0.035,
		Color(0.62, 0.60, 0.55, alpha))

	var font := ThemeDB.fallback_font
	var pad := bh * 0.10
	var y := origin.y + band_h + bh * 0.26
	# Field block, top right: three ruled boxes, filled in chalk like a real slate.
	var fw := bw * 0.30
	var fx := origin.x + bw - pad - fw
	var fy := origin.y + band_h + bh * 0.10
	var fh := bh * 0.115
	var labels := ["SCENE", "TAKE", "ROLL"]
	var values := ["—", "%02d" % take_no if take_no > 0 else "—", "01"]
	for i in 3:
		var ry := fy + fh * (1.45 * float(i))
		draw_line(Vector2(fx, ry + fh), Vector2(fx + fw, ry + fh), Color(chalk.r, chalk.g, chalk.b, alpha * 0.35), bh * 0.004)
		draw_string(_mono, Vector2(fx, ry + fh * 0.78), labels[i],
			HORIZONTAL_ALIGNMENT_LEFT, -1, int(bh * 0.085), Color(chalk.r, chalk.g, chalk.b, alpha * 0.45))
		draw_string(_mono, Vector2(fx + fw * 0.52, ry + fh * 0.78), values[i],
			HORIZONTAL_ALIGNMENT_LEFT, -1, int(bh * 0.11), Color(chalk.r, chalk.g, chalk.b, alpha * 0.92))
	# The take number belongs to the field block now; the old corner text only
	# survives when a caller sets one.
	var left_w := bw - pad * 2.0
	if take_no > 0:
		left_w = bw - fw - pad * 2.0
	if headline != "":
		draw_string(font, Vector2(origin.x + pad, y), headline,
			HORIZONTAL_ALIGNMENT_LEFT, left_w, int(bh * 0.30), Color(chalk.r, chalk.g, chalk.b, alpha * 0.10))
		draw_string(font, Vector2(origin.x + pad, y), headline,
			HORIZONTAL_ALIGNMENT_LEFT, left_w, int(bh * 0.30), Color(chalk.r, chalk.g, chalk.b, alpha))
	if subline != "":
		# Two chalk lines rather than one that runs under the field block. An
		# explicit newline in the text is obeyed, so a two-sentence premise stays
		# two sentences instead of being re-flowed into one long strip.
		var lines: Array = []
		for chunk: String in subline.split("\n", false):
			for piece: String in _wrap(chunk, font, int(bh * 0.105), left_w):
				if lines.size() < 2: lines.append(piece)
		for i in lines.size():
			draw_string(font, Vector2(origin.x + pad, y + bh * (0.26 + 0.15 * float(i))), lines[i],
				HORIZONTAL_ALIGNMENT_LEFT, left_w, int(bh * 0.105), Color(chalk.r, chalk.g, chalk.b, alpha * 0.66))
	if corner != "" and take_no == 0:
		var cy := y + bh * 0.26 if subline != "" else origin.y + bh - bh * 0.10
		if subline != "":
			var used: float = font.get_string_size(subline, HORIZONTAL_ALIGNMENT_LEFT, -1, int(bh * 0.115)).x
			if used > bw - pad * 2.0 - bh * 0.34:
				cy = y + bh * 0.40
		draw_string(font, Vector2(origin.x + pad, cy), corner,
			HORIZONTAL_ALIGNMENT_RIGHT, bw - pad * 2.0, int(bh * 0.10), Color(chalk.r, chalk.g, chalk.b, alpha * 0.55))


## Greedy split into at most two lines, measured with the same font that draws
## them. CJK is fixed width, so counting characters is exact enough here.
static func _wrap(s: String, font: Font, px: int, limit: float) -> Array:
	if font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x <= limit:
		return [s]
	var cut := s.length()
	var head := s
	while cut > 1:
		head = s.substr(0, cut)
		if font.get_string_size(head, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x <= limit:
			break
		cut -= 1
	# Prefer to break after a full stop if one is near the cut.
	var stop: int = head.rfind("。")
	if stop > 0 and stop > cut / 3:
		cut = stop + 1
		head = s.substr(0, cut)
	return [head, s.substr(cut)]


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
