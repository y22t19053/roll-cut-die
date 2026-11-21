extends Control
## NightStage — the title backdrop: a soundstage after hours. A green cyc
## sweeping into the floor, one hanging work light, and crew silhouettes
## wheeling equipment through a lit stage door. Drawn entirely in code.
##
## Nothing here flashes: every light holds a constant level and motion is a
## slow sway and a slow walk. `still = true` freezes it into one composed
## frame and stops redrawing altogether.

const BLACK := Color(0.035, 0.038, 0.045)
const CYC := Color(0.085, 0.33, 0.17)
const CYC_DARK := Color(0.03, 0.115, 0.065)
const FLOOR_FAR := Color(0.07, 0.25, 0.13)
const FLOOR_NEAR := Color(0.012, 0.035, 0.024)
const WALL := Color(0.028, 0.03, 0.036)
const DOOR := Color(0.98, 0.93, 0.80)
const WARM := Color(1.0, 0.86, 0.62)
const SHADE := Color(0.012, 0.016, 0.018)

const SWAY_PERIOD := 9.0       # seconds per lamp swing
const SWAY_DEG := 2.2
const PASS_SECONDS := 15.0     # one crew crossing
const REST_SECONDS := 5.0      # empty doorway between crossings
const STILL_TIME := 7.4        # the composed frame used when still

var still := false: set = set_still
var _t := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(not still)
	resized.connect(queue_redraw)


func set_still(on: bool) -> void:
	still = on
	set_process(not on)
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w < 8.0 or h < 8.0:
		return
	var t := STILL_TIME if still else _t
	var grid_y := h * 0.15
	var horizon := h * 0.60
	var cove := h * 0.68
	var wall_x := w * 0.76

	draw_rect(Rect2(0, 0, w, h), BLACK)
	# Cyc wall: brightest left of centre where the work light reaches it.
	var lit_x := w * 0.14
	_quad(Vector2(0, grid_y), Vector2(lit_x, grid_y), Vector2(lit_x, horizon), Vector2(0, horizon),
		CYC_DARK, CYC, CYC, CYC_DARK)
	_quad(Vector2(lit_x, grid_y), Vector2(wall_x, grid_y), Vector2(wall_x, horizon), Vector2(lit_x, horizon),
		CYC, CYC_DARK, CYC_DARK, CYC)
	# The cove: wall rolls into floor with no visible corner.
	_quad(Vector2(0, horizon), Vector2(lit_x, horizon), Vector2(lit_x, cove), Vector2(0, cove),
		CYC_DARK, CYC, FLOOR_FAR, CYC_DARK)
	_quad(Vector2(lit_x, horizon), Vector2(wall_x, horizon), Vector2(wall_x, cove), Vector2(lit_x, cove),
		CYC, CYC_DARK, CYC_DARK, FLOOR_FAR)
	_quad(Vector2(0, cove), Vector2(lit_x, cove), Vector2(lit_x, h), Vector2(0, h),
		CYC_DARK, FLOOR_FAR, FLOOR_NEAR, FLOOR_NEAR)
	_quad(Vector2(lit_x, cove), Vector2(w, cove), Vector2(w, h), Vector2(lit_x, h),
		FLOOR_FAR, CYC_DARK, FLOOR_NEAR, FLOOR_NEAR)
	# Shade over the top of the cyc so it falls off into the grid.
	_quad(Vector2(0, grid_y), Vector2(wall_x, grid_y), Vector2(wall_x, h * 0.34), Vector2(0, h * 0.34),
		Color(BLACK, 0.85), Color(BLACK, 0.85), Color(BLACK, 0.0), Color(BLACK, 0.0))

	_draw_grid(w, grid_y)
	_draw_side_wall(w, h, wall_x)
	_draw_lamp(w, h, t)
	_draw_crew(w, h, t)
	# Quiet column behind the menu so slates and status text stay readable.
	var cx := w * 0.5
	var half := 330.0
	var fade := w * 0.08
	var core := Color(BLACK, 0.72)
	var none := Color(BLACK, 0.0)
	_quad(Vector2(cx - half - fade, 0), Vector2(cx - half, 0), Vector2(cx - half, h), Vector2(cx - half - fade, h),
		none, core, core, none)
	draw_rect(Rect2(cx - half, 0, half * 2.0, h), core)
	_quad(Vector2(cx + half, 0), Vector2(cx + half + fade, 0), Vector2(cx + half + fade, h), Vector2(cx + half, h),
		core, none, none, core)


## Lighting grid: pipes and a few dead fixtures above the cyc.
func _draw_grid(w: float, grid_y: float) -> void:
	draw_rect(Rect2(0, 0, w, grid_y), Color(0.02, 0.022, 0.027))
	var pipe := Color(0.075, 0.08, 0.09)
	for i: int in 3:
		var y := grid_y * (0.3 + 0.3 * i)
		draw_line(Vector2(0, y), Vector2(w, y), pipe, 3.0)
	for i: int in 9:
		var x := w * (0.06 + 0.11 * i)
		draw_line(Vector2(x, 0), Vector2(x, grid_y * 0.9), Color(pipe, 0.6), 2.0)
	for fx: float in [0.30, 0.50, 0.70]:
		var p := Vector2(w * fx, grid_y * 0.9)
		draw_rect(Rect2(p.x - 13, p.y, 26, 20), Color(0.05, 0.053, 0.06))
		draw_rect(Rect2(p.x - 17, p.y + 20, 34, 5), Color(0.065, 0.068, 0.075))


## The dark stage wall on the right with the lit door and its spill of light.
func _draw_side_wall(w: float, h: float, wall_x: float) -> void:
	var base := h * 0.73
	draw_colored_polygon(PackedVector2Array([
		Vector2(wall_x, 0), Vector2(w, 0), Vector2(w, base), Vector2(wall_x, base)]), WALL)
	var door := _door(w, h)
	# Spill across the floor, strongest at the sill.
	var sill_l := Vector2(door.position.x, door.end.y)
	var sill_r := Vector2(door.end.x, door.end.y)
	_quad(sill_l, sill_r, Vector2(door.end.x - w * 0.05, h), Vector2(door.position.x - w * 0.24, h),
		Color(WARM, 0.34), Color(WARM, 0.34), Color(WARM, 0.0), Color(WARM, 0.0))
	# Frame, then the opening itself: warm white, a touch cooler at the top.
	draw_rect(door.grow(7.0), Color(0.07, 0.072, 0.08))
	_quad(door.position, Vector2(door.end.x, door.position.y), door.end, sill_l,
		Color(0.90, 0.90, 0.86), Color(0.90, 0.90, 0.86), DOOR, DOOR)
	# EXIT box above the frame: a steady dull green tile, no text to localize.
	draw_rect(Rect2(door.get_center().x - 22, door.position.y - 34, 44, 16), Color(0.16, 0.46, 0.25))


func _door(w: float, h: float) -> Rect2:
	return Rect2(w * 0.855, h * 0.37, w * 0.085, h * 0.36)


## One hanging work light on a cable, swaying a couple of degrees.
func _draw_lamp(w: float, h: float, t: float) -> void:
	var pivot := Vector2(w * 0.14, 0)
	var ang := deg_to_rad(SWAY_DEG) * sin(t * TAU / SWAY_PERIOD)
	var dir := Vector2(sin(ang), cos(ang))
	var side := Vector2(dir.y, -dir.x)
	var lamp := pivot + dir * h * 0.25
	draw_line(pivot, lamp, Color(0.09, 0.09, 0.1), 2.0)
	# Cone of light, fading to nothing before the floor.
	var reach := h * 0.62
	var a := lamp + side * 20.0
	var b := lamp - side * 20.0
	_quad(b, a, lamp + dir * reach + side * w * 0.09, lamp + dir * reach - side * w * 0.09,
		Color(WARM, 0.20), Color(WARM, 0.20), Color(WARM, 0.0), Color(WARM, 0.0))
	# Pool on the floor under it.
	var pool := Vector2(lamp.x + dir.x * reach, h * 0.83)
	for i: int in 5:
		var k := 1.0 - i / 5.0
		_ellipse(pool, Vector2(w * 0.10 * k, h * 0.035 * k), Color(WARM, 0.035))
	# Shade and bulb.
	draw_colored_polygon(PackedVector2Array([
		lamp - dir * 22.0 + side * 9.0, lamp - dir * 22.0 - side * 9.0,
		lamp - side * 26.0, lamp + side * 26.0]), Color(0.06, 0.062, 0.07))
	draw_circle(lamp + dir * 3.0, 7.0, Color(1.0, 0.95, 0.82))


## Crew crossings alternate: out through the door with a wheeled case, back in
## with a light stand. Each is a slow walk that eases off into the doorway.
func _draw_crew(w: float, h: float, t: float) -> void:
	var cycle := PASS_SECONDS + REST_SECONDS
	var n := int(floor(t / cycle))
	var u := (t - n * cycle) / PASS_SECONDS
	if u >= 1.0:
		return
	var outbound := n % 2 == 0
	var k := u if outbound else 1.0 - u        # 0 = on the floor, 1 = in the door
	var door := _door(w, h)
	var sill := Vector2(door.get_center().x, door.end.y + 2.0)
	var start := Vector2(w * 0.80, h * 0.97)
	var foot := start.lerp(sill, k)
	var scale_k := lerpf(1.0, 0.62, k)
	# Dissolve gently into the glare over the last stretch (a fade, not a blink).
	var alpha := 1.0 - smoothstep(0.86, 1.0, k)
	alpha *= smoothstep(0.0, 0.06, k)
	if alpha <= 0.01:
		return
	var ink := Color(SHADE, alpha)
	var unit := h * 0.21 * scale_k            # figure height
	var facing := 1.0 if outbound else -1.0   # +1 walks toward the door (right)
	var stride := sin(t * 3.4) * (0.0 if still else 1.0)
	_figure(foot, unit, facing, stride, ink)
	var lead := foot + Vector2(facing * unit * 0.50, 0)
	if outbound:
		_road_case(lead, unit, ink)
	else:
		_light_stand(lead, unit, ink)


func _figure(foot: Vector2, u: float, facing: float, stride: float, ink: Color) -> void:
	var hip := foot + Vector2(0, -u * 0.48)
	var neck := hip + Vector2(facing * u * 0.05, -u * 0.34)
	var lw := maxf(3.0, u * 0.075)
	draw_line(hip, foot + Vector2(stride * u * 0.11, 0), ink, lw)
	draw_line(hip, foot + Vector2(-stride * u * 0.11, 0), ink, lw)
	draw_line(hip, neck, ink, lw * 1.9)
	draw_circle(neck + Vector2(facing * u * 0.02, -u * 0.09), u * 0.075, ink)
	# Arms out to whatever is being pushed.
	var hand := hip + Vector2(facing * u * 0.36, -u * 0.08)
	draw_line(neck + Vector2(0, u * 0.05), hand, ink, lw * 0.8)


## Flight case on castors with a coil of cable on top.
func _road_case(at: Vector2, u: float, ink: Color) -> void:
	var cw := u * 0.46
	var ch := u * 0.34
	var wheel := u * 0.035
	draw_rect(Rect2(at.x - cw * 0.5 + u * 0.14, at.y - wheel * 2.0 - ch, cw, ch), ink)
	draw_circle(Vector2(at.x - cw * 0.32 + u * 0.14, at.y - wheel), wheel, ink)
	draw_circle(Vector2(at.x + cw * 0.32 + u * 0.14, at.y - wheel), wheel, ink)
	draw_arc(Vector2(at.x + u * 0.14, at.y - wheel * 2.0 - ch - u * 0.05), u * 0.07, 0.0, TAU, 16, ink, maxf(2.0, u * 0.03))


## Rolling stand with a barn-doored lamp head.
func _light_stand(at: Vector2, u: float, ink: Color) -> void:
	var lw := maxf(2.0, u * 0.035)
	var top := at + Vector2(0, -u * 1.12)
	draw_line(at + Vector2(0, -u * 0.12), top, ink, lw)
	draw_line(at + Vector2(0, -u * 0.12), at + Vector2(-u * 0.16, 0), ink, lw)
	draw_line(at + Vector2(0, -u * 0.12), at + Vector2(u * 0.16, 0), ink, lw)
	draw_rect(Rect2(top.x - u * 0.11, top.y - u * 0.16, u * 0.22, u * 0.18), ink)
	draw_line(top + Vector2(-u * 0.11, -u * 0.16), top + Vector2(-u * 0.19, -u * 0.22), ink, lw)
	draw_line(top + Vector2(-u * 0.11, u * 0.02), top + Vector2(-u * 0.19, u * 0.08), ink, lw)


func _quad(a: Vector2, b: Vector2, c: Vector2, d: Vector2, ca: Color, cb: Color, cc: Color, cd: Color) -> void:
	draw_polygon(PackedVector2Array([a, b, c, d]), PackedColorArray([ca, cb, cc, cd]))


func _ellipse(c: Vector2, r: Vector2, col: Color) -> void:
	if r.x < 1.0 or r.y < 1.0:
		return
	var pts := PackedVector2Array()
	for i: int in 28:
		var a := TAU * i / 28.0
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	draw_colored_polygon(pts, col)
