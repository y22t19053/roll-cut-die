extends CanvasLayer
## Hud — every piece of on-screen text except the slate.
##
## The HUD is a read-out, not a controller: it is told what to say and shows it.
## All strings come in already localised.

const Loc = preload("res://scripts/core/loc.gd")
const SlateBoard = preload("res://scripts/ui/slate_board.gd")

var take_label: Label
var hint_label: Label
var banner: Label
var case_label: Label
var debug_label: Label
var roll_label: Label
var mark_label: Label
var death_label: Label
var screen: Control

var _take_index := 0
var _ghost_count := 0
var _phase := ""
var _banner_left := 0.0
var _banner_hold := 0.0
var _marks := Vector2i.ZERO
var _roll_name := ""


func _ready() -> void:
	layer = 10
	screen = Control.new()
	screen.name = "Screen"
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	take_label = _mk("", 24, 18, 520, 30, 20, HORIZONTAL_ALIGNMENT_LEFT)
	mark_label = _mk("", 24, 50, 520, 30, 18, HORIZONTAL_ALIGNMENT_LEFT)
	mark_label.add_theme_color_override("font_color", Color(0.55, 0.95, 0.85))
	case_label = _mk("", 0, 0, 420, 260, 17, HORIZONTAL_ALIGNMENT_RIGHT)
	case_label.anchor_left = 1.0
	case_label.anchor_right = 1.0
	case_label.offset_left = -444.0
	case_label.offset_right = -24.0
	case_label.offset_top = 18.0
	case_label.offset_bottom = 300.0

	banner = _mk("", 0, 0, 900, 40, 34, HORIZONTAL_ALIGNMENT_CENTER)
	banner.anchor_left = 0.5
	banner.anchor_right = 0.5
	banner.offset_left = -450.0
	banner.offset_right = 450.0
	banner.offset_top = 96.0
	banner.offset_bottom = 150.0

	hint_label = _mk("", 0, 0, 1200, 30, 19, HORIZONTAL_ALIGNMENT_CENTER)
	hint_label.anchor_left = 0.5
	hint_label.anchor_right = 0.5
	hint_label.anchor_top = 1.0
	hint_label.anchor_bottom = 1.0
	hint_label.offset_left = -600.0
	hint_label.offset_right = 600.0
	hint_label.offset_top = -58.0
	hint_label.offset_bottom = -20.0

	debug_label = _mk("", 0, 0, 460, 320, 15, HORIZONTAL_ALIGNMENT_RIGHT)
	debug_label.anchor_left = 1.0
	debug_label.anchor_right = 1.0
	debug_label.anchor_top = 1.0
	debug_label.anchor_bottom = 1.0
	debug_label.offset_left = -484.0
	debug_label.offset_right = -24.0
	debug_label.offset_top = -340.0
	debug_label.offset_bottom = -20.0
	debug_label.visible = false

	roll_label = _mk("", 0, 0, 400, 30, 20, HORIZONTAL_ALIGNMENT_CENTER)
	roll_label.anchor_left = 0.5
	roll_label.anchor_right = 0.5
	roll_label.offset_left = -200.0
	roll_label.offset_right = 200.0
	roll_label.offset_top = 18.0
	roll_label.offset_bottom = 48.0

	# Stays up from the moment of death until the retake, and is the only place
	# the cause is written; the slate says DIE./CUT! but not who. Its own layer
	# sits above the slate's dimmer, in the band SlateBoard keeps clear.
	var death_layer := CanvasLayer.new()
	death_layer.name = "DeathLayer"
	death_layer.layer = 30
	add_child(death_layer)
	var death_screen := Control.new()
	death_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	death_layer.add_child(death_screen)
	death_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	death_label = _mk("", 0, 0, 1200, 120, 72, HORIZONTAL_ALIGNMENT_CENTER)
	death_label.reparent(death_screen, false)
	death_label.anchor_left = 0.5
	death_label.anchor_right = 0.5
	death_label.anchor_top = 1.0
	death_label.anchor_bottom = 1.0
	death_label.offset_left = -600.0
	death_label.offset_right = 600.0
	death_label.offset_top = -SlateBoard.BOTTOM_CLEAR + 8.0
	death_label.offset_bottom = -SlateBoard.BOTTOM_CLEAR + 128.0
	death_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	death_label.add_theme_color_override("font_color", Color(1.0, 0.32, 0.28))
	death_label.add_theme_constant_override("outline_size", 12)
	death_label.visible = false


func _mk(text: String, x: float, y: float, w: float, h: float, fsize: int, align: int) -> Label:
	var l := Label.new()
	l.text = text
	l.position = Vector2(x, y)
	l.size = Vector2(w, h)
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	l.add_theme_font_size_override("font_size", fsize)
	l.add_theme_color_override("font_color", Color(0.95, 0.94, 0.90))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.92))
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(l)
	return l


func set_take(index: int, ghost_count: int, phase: String) -> void:
	_take_index = index
	_ghost_count = ghost_count
	_phase = phase
	_render_take()


func set_ghost_count(ghost_count: int) -> void:
	_ghost_count = ghost_count
	_render_take()


func _render_take() -> void:
	take_label.text = Loc.ui("hud.take_one" if _ghost_count == 1 else "hud.take_many",
		[_take_index, _ghost_count, _phase])


func set_marks(used: int, capacity: int) -> void:
	_marks = Vector2i(used, capacity)
	mark_label.text = Loc.ui("hud.marks", [used, capacity])


func set_roll_mode(mode_name: String) -> void:
	_roll_name = mode_name
	roll_label.text = Loc.ui("hud.roll", [mode_name])


## Re-render the read-outs the HUD formats itself. Lines handed in finished
## (hint, banner, death, case) are re-sent by the scene.
func relocalize() -> void:
	_render_take()
	set_marks(_marks.x, _marks.y)
	if not _roll_name.is_empty():
		set_roll_mode(_roll_name)


func banner_showing() -> bool:
	return _banner_left > 0.0 and not banner.text.is_empty()


## Swap the banner wording without restarting its timer.
func retext_banner(text: String) -> void:
	if banner_showing():
		banner.text = text


func show_death(text: String) -> void:
	death_label.text = text
	death_label.visible = true


func clear_death() -> void:
	death_label.text = ""
	death_label.visible = false


func set_hint(text: String) -> void:
	hint_label.text = text


func flash(text: String, seconds: float = 2.2) -> void:
	banner.text = text
	_banner_left = seconds
	_banner_hold = seconds


func clear_banner() -> void:
	banner.text = ""
	_banner_left = 0.0


func set_case_lines(lines: PackedStringArray) -> void:
	case_label.text = "\n".join(lines)


func set_debug(text: String) -> void:
	debug_label.text = text


func toggle_debug() -> void:
	debug_label.visible = not debug_label.visible


func _process(dt: float) -> void:
	if _banner_left > 0.0:
		_banner_left -= dt
		if _banner_left <= 0.0:
			banner.text = ""
		elif _banner_left < 0.5:
			banner.modulate.a = _banner_left / 0.5
	else:
		banner.modulate.a = 1.0
