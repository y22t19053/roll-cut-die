extends Node2D
## Touch controls for phones, tablets, and the Bilibili TOY player.
##
## The game was built for a keyboard, so this is not a usual mobile stick: it feeds
## the same four world axes the keys feed, and the camera still does whatever it
## wants with them. Slide your thumb right and the world turns under you exactly as
## it does under D — the pad must not become the camera-relative stick that would
## quietly undo the whole game.
##
## Layout is in canvas units (project stretch is canvas_items + expand), sized off
## the shorter side of the visible rect, so a 6" phone and a 13" tablet both get
## buttons you can actually hit instead of 25-pixel slivers. Pinching zooms; the
## camera distance is a view setting like brightness — it changes what you can see,
## never what can hit you.
##
## Everything a test needs is a static function: layout, hit maths, the eight-way
## quantiser, the zoom clamp. The node itself only glues those to real touches.

const ZOOM_MIN := 10.0
const ZOOM_MAX := 17.0
## Mirrors relay_run.Mode, kept as plain numbers so this file stays headless-safe.
const M_PLAY := 0
const M_PICK := 1
const M_CUT := 2
const M_DONE := 3
const M_LOST := 4
const M_ITEM := 5

## Canvas units of button radius per unit of the shorter visible side.
const SCALE := 0.13
const SCALE_MIN := 96.0
const SCALE_MAX := 216.0
const DEADZONE := 0.34

const PAPER := Color(0.933, 0.898, 0.796)
const INK := Color(0.133, 0.137, 0.133)
const AMBER := Color(0.937, 0.702, 0.416)
const MINT := Color(0.576, 0.808, 0.753)

var relay: Node = null
var player: Node = null
var rig: Node = null

var _u := 140.0
var _stick_center := Vector2.ZERO
var _stick_radius := 130.0
var _slots: Array = []
var _buttons: Array = []
var _press_index := -1
var _held := {}
var _free := {}
var _stick_id := -1
var _pinch_ids: Array = []
var _pinch_span := 0.0
var _pinch_dist := 12.0
var _font: Font
var _visible_now := false
var _last_size := Vector2.ZERO


func _ready() -> void:
	_font = load("res://assets/fonts/RCD-Noto.otf") as Font
	if _font == null:
		_font = ThemeDB.fallback_font
	z_index = 40
	## Hidden until _process has decided: a Node2D starts visible, and defaulting
	## to on would flash thumbs on a keyboard machine for one frame.
	visible = false
	set_process(true)
	get_viewport().size_changed.connect(_layout)
	_layout()


## --- layout maths (pure, testable) ------------------------------------------

static func pad_scale(visible: Vector2) -> float:
	return clampf(minf(visible.x, visible.y) * SCALE, SCALE_MIN, SCALE_MAX)


static func stick_origin(visible: Vector2, u: float) -> Vector2:
	var m := u * 0.32
	return Vector2(m + u * 0.95, visible.y - m - u * 0.95)


static func button_slots(visible: Vector2, u: float) -> Array:
	## Four circular targets, biggest at the corner: a thumb can find the primary
	## action without looking, the rest stay in the same place every phase.
	var m := u * 0.32
	var step := u * 1.66
	var primary := Vector2(visible.x - m - u * 0.80, visible.y - m - u * 0.80)
	return [
		{"pos": primary, "r": u * 0.80},
		{"pos": primary - Vector2(step, 0.0), "r": u * 0.60},
		{"pos": primary - Vector2(0.0, step), "r": u * 0.60},
		{"pos": primary - Vector2(step, step), "r": u * 0.52},
	]


## Eight sectors, not a free analogue angle: the keys are four directions with a
## deadzone-shaped rule, and half-angle input would make the camera's chase read
## as noise rather than as a direction.
static func stick_vector(delta: Vector2, radius: float, dead: float = DEADZONE) -> Vector2:
	var v := delta / maxf(radius, 1.0)
	if v.length() < dead:
		return Vector2.ZERO
	var sector := int(round(atan2(v.y, v.x) / (PI / 4.0)))
	var dirs := [
		Vector2(1, 0), Vector2(1, 1), Vector2(0, 1), Vector2(-1, 1),
		Vector2(-1, 0), Vector2(-1, -1), Vector2(0, -1), Vector2(1, -1),
	]
	return (dirs[posmod(sector, 8)] as Vector2).normalized()


static func clamp_zoom(base: float, ratio: float) -> float:
	return clampf(base * ratio, ZOOM_MIN, ZOOM_MAX)


## Which four actions the phase needs. Same order as button_slots().
static func buttons_for(mode: int) -> Array:
	match mode:
		M_CUT:
			return [
				{"label": "OK", "key": KEY_SPACE},
				{"label": "▲", "key": KEY_UP},
				{"label": "▼", "key": KEY_DOWN},
				{"label": "X", "key": KEY_ESCAPE},
			]
		M_DONE, M_LOST:
			return [
				{"label": "OK", "key": KEY_SPACE},
				{"label": "R", "key": KEY_R},
				{"label": "||", "key": KEY_ESCAPE},
			]
		M_ITEM, M_PICK:
			return [{"label": "||", "key": KEY_ESCAPE}]
	return [
		{"label": "C", "key": KEY_C},
		{"label": "M", "key": KEY_M},
		{"label": "||", "key": KEY_ESCAPE},
	]


## Should the pad be on screen at all? A card the player must read is a card the
## thumb should not be able to cover.
static func wanted(mode: int, board_running: bool) -> bool:
	if board_running:
		return false
	return mode in [M_PLAY, M_CUT, M_DONE, M_LOST, M_ITEM, M_PICK]


## Preference "auto"/"on"/"off" crossed with what the machine actually has.
## Auto is the honest default: a keyboard player has no reason to see thumbs,
## and a phone has no way to play without them.
static func device_wants(pref: String, has_touch: bool) -> bool:
	if pref == "on":
		return true
	if pref == "off":
		return false
	return has_touch


static func has_touch_screen() -> bool:
	return DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")


## --- live pad ---------------------------------------------------------------

func _mode() -> int:
	if relay == null:
		return M_PLAY
	return int(relay.phase)


func _board_running() -> bool:
	if relay == null or relay.slate == null:
		return false
	return bool(relay.slate.is_running())


## Read the preference without a hard dependency on the autoload's global name:
## a --script test run has the singleton at /root but not always as a compile-time
## identifier, and a missing hub must mean "auto", not a broken script.
func pad_preference() -> String:
	var hub := get_node_or_null("/root/GameSession")
	if hub == null:
		return "auto"
	var prefs: Variant = hub.get("settings")
	if prefs is Dictionary:
		var d: Dictionary = prefs
		if d.has("touch_pad"):
			return str(d["touch_pad"])
	return "auto"


func _layout() -> void:
	var visible: Vector2 = get_viewport().get_visible_rect().size
	_u = pad_scale(visible)
	_stick_center = stick_origin(visible, _u)
	_stick_radius = _u * 0.95
	_slots = button_slots(visible, _u)
	_buttons = buttons_for(_mode())
	queue_redraw()


func _process(_dt: float) -> void:
	var shape := get_viewport().get_visible_rect().size
	if shape != _last_size:
		_last_size = shape
		_layout()
	var want := (
		wanted(_mode(), _board_running())
		and device_wants(pad_preference(), has_touch_screen())
	)
	if want != _visible_now:
		_visible_now = want
		visible = want
		if not want:
			_release_all()
	if want and _buttons.size() != buttons_for(_mode()).size():
		_layout()
	if want and player != null and _stick_id < 0:
		player.set("touch_vec", Vector2.ZERO)


func _release_all() -> void:
	_held.clear()
	_free.clear()
	_pinch_ids.clear()
	_stick_id = -1
	_press_index = -1
	if player != null:
		player.set("touch_vec", Vector2.ZERO)
	queue_redraw()


func _slot_at(p: Vector2) -> int:
	for i in range(_slots.size()):
		var s: Dictionary = _slots[i]
		var r: float = float(s["r"]) * 1.14
		if p.distance_to(s["pos"] as Vector2) <= r:
			return i
	return -1


func _input(event: InputEvent) -> void:
	if not _visible_now:
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			var slot := _slot_at(t.position)
			if slot >= 0:
				_held[t.index] = slot
				_press_index = slot
				_act(slot)
				_accept()
				return
			if t.position.distance_to(_stick_center) <= _stick_radius * 1.35:
				_stick_id = t.index
				_set_stick(t.position)
				_accept()
				return
			_free[t.index] = t.position
			_update_pinch()
			return
		_held.erase(t.index)
		_free.erase(t.index)
		_pinch_ids.erase(t.index)
		if t.index == _stick_id:
			_stick_id = -1
			if player != null:
				player.set("touch_vec", Vector2.ZERO)
			queue_redraw()
		_update_pinch()
		_accept()
		return
	if event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == _stick_id:
			_set_stick(d.position)
			_accept()
			return
		if _free.has(d.index):
			_free[d.index] = d.position
			_update_pinch()
			_accept()


func _accept() -> void:
	var vp := get_viewport()
	if vp != null:
		vp.set_input_as_handled()


func _set_stick(p: Vector2) -> void:
	var v := stick_vector(p - _stick_center, _stick_radius)
	if player != null:
		player.set("touch_vec", v)
	queue_redraw()


func _act(slot: int) -> void:
	var list := buttons_for(_mode())
	if slot < 0 or slot >= list.size():
		return
	var key: int = int(list[slot]["key"])
	if relay != null and relay.has_method("touch_key"):
		relay.call("touch_key", key)


func _update_pinch() -> void:
	var ids := _free.keys()
	ids.sort()
	if ids.size() < 2:
		_pinch_ids.clear()
		return
	var a: Vector2 = _free[ids[0]]
	var b: Vector2 = _free[ids[1]]
	var span := a.distance_to(b)
	if _pinch_ids.size() < 2:
		_pinch_ids = [ids[0], ids[1]]
		_pinch_span = maxf(span, 1.0)
		_pinch_dist = float(rig.get("distance")) if rig != null else 12.0
		return
	if span <= 1.0 or _pinch_span <= 1.0:
		return
	if rig != null:
		rig.set("distance", clamp_zoom(_pinch_dist * (_pinch_span / span), 1.0))
	queue_redraw()


func _draw() -> void:
	if not _visible_now:
		return
	var u := _u
	# Stick: a ring, eight ticks, and the knob where your thumb is.
	draw_arc(_stick_center, _stick_radius, 0.0, TAU, 48, Color(PAPER.r, PAPER.g, PAPER.b, 0.16), u * 0.10, true)
	var ticks := [
		Vector2(0, -1), Vector2(1, -1), Vector2(1, 0), Vector2(1, 1),
		Vector2(0, 1), Vector2(-1, 1), Vector2(-1, 0), Vector2(-1, -1),
	]
	for t in ticks:
		var dir: Vector2 = (t as Vector2).normalized()
		var a: Vector2 = _stick_center + dir * _stick_radius * 0.80
		var b: Vector2 = _stick_center + dir * _stick_radius * 0.94
		draw_line(a, b, Color(PAPER.r, PAPER.g, PAPER.b, 0.22), u * 0.035, true)
	var knob := _stick_center
	if _stick_id >= 0:
		var v: Vector2 = player.get("touch_vec") if player != null else Vector2.ZERO
		knob = _stick_center + v * _stick_radius * 0.46
	draw_circle(knob, u * 0.30, Color(PAPER.r, PAPER.g, PAPER.b, 0.20))
	draw_arc(knob, u * 0.30, 0.0, TAU, 32, Color(PAPER.r, PAPER.g, PAPER.b, 0.44), u * 0.028, true)
	# Buttons.
	for i in range(mini(_slots.size(), _buttons.size())):
		var s: Dictionary = _slots[i]
		var c: Vector2 = s["pos"]
		var r: float = float(s["r"])
		var on: bool = _held.values().has(i)
		var tint := AMBER if i == 0 else MINT
		draw_circle(c, r, Color(tint.r, tint.g, tint.b, 0.20 if on else 0.11))
		draw_arc(c, r, 0.0, TAU, 40, Color(tint.r, tint.g, tint.b, 0.70 if on else 0.40), u * 0.030, true)
		var label: String = str((_buttons[i] as Dictionary)["label"])
		var size := int(r * (0.78 if label.length() > 1 else 1.05))
		var tw: float = _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		draw_string(_font, c + Vector2(-tw * 0.5, size * 0.36), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(PAPER.r, PAPER.g, PAPER.b, 0.88 if on else 0.70))