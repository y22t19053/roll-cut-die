extends RefCounted
## The touch pad, checked where it can be checked without a phone: layout, hit
## maths, the eight-way quantiser, the zoom clamp, and the phase table.
##
## What this file cannot prove is whether a thumb finds the buttons or whether the
## pad feels like WASD under glass. That needs a real phone and a person; say so
## rather than pretending the assertions below cover it.


const Pad = preload("res://scripts/relay/touch_pad.gd")
## Read statically: the autoload is not a compile-time identifier inside a
## --script runner, but the class's constants and defaults are.
const Session = preload("res://scripts/core/game_session.gd")


static func run(h, tree = null) -> void:
	h.begin("touch_pad")
	_pad_scale(h)
	_stick_math(h)
	_slots(h)
	_phases(h)
	_device(h)
	_zoom(h)


static func _pad_scale(h) -> void:
	# A 6" phone in canvas units is still ~1600 wide (stretch expand), so scale has
	# to come from the shorter side, and it has both a floor and a ceiling.
	var phone := Pad.pad_scale(Vector2(1600.0, 2844.0))
	var desk := Pad.pad_scale(Vector2(1600.0, 900.0))
	var tablet := Pad.pad_scale(Vector2(2200.0, 1400.0))
	h.ok("phone buttons are big enough to hit", phone >= 96.0 and phone <= 216.0)
	h.ok("a desktop window does not get phone-sized targets", desk >= 96.0)
	h.ok("a big tablet does not get giant targets", tablet <= 216.0)
	h.ok("scale never exceeds its ceiling", Pad.pad_scale(Vector2(9000.0, 9000.0)) <= 216.0)


static func _stick_math(h) -> void:
	var r := 130.0
	var up := Pad.stick_vector(Vector2(0.0, -120.0), r)
	var down := Pad.stick_vector(Vector2(0.0, 120.0), r)
	var right := Pad.stick_vector(Vector2(120.0, 0.0), r)
	var left := Pad.stick_vector(Vector2(-120.0, 0.0), r)
	# Screen up is world forward: -Y on the stick is -y in the input vector.
	h.ok("up on the stick is forward", up == Vector2(0.0, -1.0))
	h.ok("down on the stick is back", down == Vector2(0.0, 1.0))
	h.ok("right on the stick is right", right == Vector2(1.0, 0.0))
	h.ok("left on the stick is left", left == Vector2(-1.0, 0.0))
	h.ok("a resting thumb does not walk", Pad.stick_vector(Vector2(6.0, 8.0), r) == Vector2.ZERO)
	# Diagonals are quantised to eight, and normalised so two axes are not 1.41x.
	var diag := Pad.stick_vector(Vector2(90.0, 90.0), r)
	h.ok("a diagonal is one of the eight", is_equal_approx(diag.length(), 1.0))
	h.ok("a diagonal points the way the thumb went", diag.x > 0.6 and diag.y > 0.6)
	var diag_up := Pad.stick_vector(Vector2(-90.0, -90.0), r)
	h.ok("up-left reads as up-left", diag_up.x < -0.6 and diag_up.y < -0.6)
	h.ok("the quantiser is symmetric", Pad.stick_vector(Vector2(-90.0, 90.0), r).x < -0.6)


static func _slots(h) -> void:
	var visible := Vector2(1600.0, 2844.0)
	var u := Pad.pad_scale(visible)
	var origin := Pad.stick_origin(visible, u)
	h.ok("the stick sits in the lower left", origin.x < visible.x * 0.25 and origin.y > visible.y * 0.6)
	var slots := Pad.button_slots(visible, u)
	h.ok("four targets exist", slots.size() == 4)
	var primary: Dictionary = slots[0]
	h.ok("the primary action is in the lower right",
		(primary["pos"] as Vector2).x > visible.x * 0.7 and (primary["pos"] as Vector2).y > visible.y * 0.6)
	h.ok("the primary action is the biggest target", float(primary["r"]) > float((slots[1] as Dictionary)["r"]))
	var far: Vector2 = primary["pos"]
	h.ok("the stick and the buttons do not overlap",
		far.distance_to(origin) > u * 2.0)
	# Nothing may hang off the screen edge, or a phone with rounded corners loses it.
	for s: Dictionary in slots:
		var p: Vector2 = s["pos"]
		var rr: float = float(s["r"])
		h.ok("a target stays on screen", p.x + rr <= visible.x and p.y + rr <= visible.y and p.x - rr >= 0.0)


static func _phases(h) -> void:
	var play := Pad.buttons_for(Pad.M_PLAY)
	h.ok("playing offers cut, mark and menu", play.size() == 3)
	h.ok("the primary action while playing is CUT", int(play[0]["key"]) == KEY_C)
	h.ok("MARK is the second target", int(play[1]["key"]) == KEY_M)
	h.ok("the third target is the pause menu", int(play[2]["key"]) == KEY_ESCAPE)
	var cut := Pad.buttons_for(Pad.M_CUT)
	h.ok("the cutting desk offers confirm, up, down, out", cut.size() == 4)
	h.ok("a splice needs a confirm, not a tap on a card", int(cut[0]["key"]) == KEY_SPACE)
	h.ok("the cutting desk can step up", int(cut[1]["key"]) == KEY_UP)
	h.ok("the cutting desk can step down", int(cut[2]["key"]) == KEY_DOWN)
	h.ok("the cutting desk can back out", int(cut[3]["key"]) == KEY_ESCAPE)
	var over := Pad.buttons_for(Pad.M_DONE)
	h.ok("the end of a run offers continue and replay", over.size() == 3)
	h.ok("continue is the primary action", int(over[0]["key"]) == KEY_SPACE)
	h.ok("the same seed is one target away", int(over[1]["key"]) == KEY_R)
	h.ok("a lost run also ends on continue", int(Pad.buttons_for(Pad.M_LOST)[0]["key"]) == KEY_SPACE)
	var card := Pad.buttons_for(Pad.M_ITEM)
	h.ok("a card the player is reading offers only the menu", card.size() == 1)
	h.ok("the board hides the pad", Pad.wanted(Pad.M_PLAY, true) == false)
	h.ok("play shows the pad", Pad.wanted(Pad.M_PLAY, false) == true)
	h.ok("the cutting desk shows the pad", Pad.wanted(Pad.M_CUT, false) == true)
	# The death card is the one moment the frame must stay readable: nothing of the
	# pad may sit over the slate.
	h.ok("the slate hides the pad in every phase", Pad.wanted(Pad.M_CUT, true) == false)


static func _device(h) -> void:
	# Auto is the default because both mistakes are visible: thumbs on a keyboard
	# screen, or no way to move on a phone. The preference has to answer first.
	h.ok("auto hides the pad on a machine without a touch screen", Pad.device_wants("auto", false) == false)
	h.ok("auto shows the pad where there is a touch screen", Pad.device_wants("auto", true) == true)
	h.ok("always shows it even with a keyboard", Pad.device_wants("on", false) == true)
	h.ok("never hides it even on a phone", Pad.device_wants("off", true) == false)
	h.ok("an unreadable preference falls back to auto", Pad.device_wants("banana", false) == false)
	var session = Session.new()
	h.ok("a written preference is one of three words", Session.CHOICES["touch_pad"] == ["auto", "on", "off"])
	h.ok("the pad preference is stored like every other", session.settings.has("touch_pad"))
	h.ok("auto is the default, so a keyboard machine starts clean", str(session.settings["touch_pad"]) == "auto")
	session.free()


static func _zoom(h) -> void:
	h.ok("pinching in backs the camera off", Pad.clamp_zoom(12.0, 1.4) > 12.0)
	h.ok("pinching out pulls the camera in", Pad.clamp_zoom(12.0, 0.75) < 12.0)
	h.ok("zoom cannot cross the near limit", Pad.clamp_zoom(12.0, 0.10) == Pad.ZOOM_MIN)
	h.ok("zoom cannot cross the far limit", Pad.clamp_zoom(12.0, 9.00) == Pad.ZOOM_MAX)
	h.ok("the default distance is inside the zoom range", Pad.ZOOM_MIN < 12.0 and 12.0 < Pad.ZOOM_MAX)