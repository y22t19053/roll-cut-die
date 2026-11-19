extends CanvasLayer
## Hud — every piece of on-screen text except the slate.
##
## The HUD is a read-out, not a controller: it is told what to say and shows it.
## All strings come in already localised.

const Loc = preload("res://scripts/core/loc.gd")

var take_label: Label
var hint_label: Label
var banner: Label
var case_label: Label
var debug_label: Label
var screen: Control

var _banner_left := 0.0
var _banner_hold := 0.0


func _ready() -> void:
	layer = 10
	screen = Control.new()
	screen.name = "Screen"
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	take_label = _mk("", 24, 18, 520, 30, 20, HORIZONTAL_ALIGNMENT_LEFT)
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
	take_label.text = "TAKE %02d   ·   %d GHOST%s   ·   %s" % [
		index, ghost_count, "" if ghost_count == 1 else "S", phase
	]


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
