extends RefCounted
## ROLL is a rule, not a feel.
##
## Every claim in docs/RCD_GAME_DESIGN_BIBLE.md §4 that can be computed is
## computed here: world-anchored input, facing, the deadzone, the finite angular
## speed and acceleration, the short-way wrap, determinism, roll derivation and
## return, rig geometry, and the mouse channel's isolation. §4.7 is the checklist
## that drove this file.

const CameraMath = preload("res://scripts/camera/camera_math.gd")
const CameraChase = preload("res://scripts/camera/camera_chase.gd")
const CameraRigScript = preload("res://scripts/camera/camera_rig.gd")
const RollModes = preload("res://scripts/camera/roll_modes.gd")

const DT := 1.0 / 60.0
## _chase and _roll assert the §4.3 chase integrator (CameraChase), which only
## drives the frame under ROLL mode 0. SNAP and ORBIT have their own rules and
## are measured by tests/probe_roll_modes.gd. _input, _facing, _geometry and
## _mouse hold in every mode.
const CHASE_ONLY := RollModes.CHASE


static func run(h, _tree = null) -> void:
	h.begin("camera")
	_input(h)
	_facing(h)
	_chase(h, CHASE_ONLY)
	_roll(h, CHASE_ONLY)
	_geometry(h)
	_mouse(h)
	_tilt(h)
	_mid_snap_restore(h)


static func _mid_snap_restore(h) -> void:
	var live := CameraRigScript.new()
	var retry := CameraRigScript.new()
	live.set_roll_mode(RollModes.SNAP)
	retry.set_roll_mode(RollModes.SNAP)
	var a = live.active()
	var b = retry.active()
	for i in 5:
		a.drive(0.0, Vector3.RIGHT, DT)
	h.ok("MARK occurs inside the quarter turn", absf(a.yaw) > 0.1 and absf(a.yaw) < PI/2 - 0.1 and a.presses == 1)
	retry.restore_mark_motion({"cam_motion": live.mark_motion(), "cam_yaw": a.yaw, "cam_roll": a.roll})
	var peak_error := 0.0
	var presses_match := true
	for i in 30:
		var intent := Vector3.RIGHT if i < 8 else (Vector3.ZERO if i < 12 else Vector3.FORWARD)
		a.drive(0.0, intent, DT)
		b.drive(0.0, intent, DT)
		peak_error = maxf(peak_error, maxf(absf(angle_difference(a.yaw,b.yaw)), maxf(absf(a.roll-b.roll),absf(a.w-b.w))))
		presses_match = presses_match and a.presses == b.presses
	h.near("same SNAP yaw, tilt and rate throughout continuation", peak_error, 0.0, 0.000001)
	h.ok("held direction not counted again; later turn recognized", presses_match and b.presses == 2)
	live.free()
	retry.free()


# --- §4.2: movement is anchored to world axes ----------------------------
static func _input(h) -> void:
	h.eq("W -> world -Z", CameraMath.move_dir(Vector2(0, -1)), Vector3(0, 0, -1))
	h.eq("S -> world +Z", CameraMath.move_dir(Vector2(0, 1)), Vector3(0, 0, 1))
	h.eq("D -> world +X", CameraMath.move_dir(Vector2(1, 0)), Vector3(1, 0, 0))
	h.eq("A -> world -X", CameraMath.move_dir(Vector2(-1, 0)), Vector3(-1, 0, 0))
	h.eq("zero input -> zero", CameraMath.move_dir(Vector2.ZERO), Vector3.ZERO)
	h.near("diagonal is normalised", CameraMath.move_dir(Vector2(1, -1)).length(), 1.0, 0.000001)
	h.near("diagonal keeps its bearing", CameraMath.move_dir(Vector2(1, -1)).angle_to(
		Vector3(1, 0, -1).normalized()), 0.0, 0.000001)

	# The quantity the player is fighting: pressed direction vs view direction.
	h.near("aligned view has no drift", CameraMath.view_drift(Vector2(0, -1), 0.0), 0.0)
	h.near("side-on view drifts 90deg",
		rad_to_deg(CameraMath.view_drift(Vector2(0, -1), deg_to_rad(90.0))), 90.0, 0.001)
	h.near("reachable view drifts 8deg",
		rad_to_deg(CameraMath.view_drift(Vector2(0, -1), deg_to_rad(8.0))), 8.0, 0.001)


# --- §4.2: facing is where you walk --------------------------------------
static func _facing(h) -> void:
	h.near("facing of -Z is 0", CameraMath.facing_from_dir(Vector3(0, 0, -1)), 0.0)
	h.near("facing of +X is -90deg",
		rad_to_deg(CameraMath.facing_from_dir(Vector3(1, 0, 0))), -90.0, 0.0001)
	h.near("facing of +Z is 180deg",
		absf(rad_to_deg(CameraMath.facing_from_dir(Vector3(0, 0, 1)))), 180.0, 0.0001)
	h.near("facing of zero dir is 0", CameraMath.facing_from_dir(Vector3.ZERO), 0.0)


# --- §4.3: the chase rule (ROLL mode 0 only) -----------------------------
static func _chase(h, mode: int) -> void:
	if mode != RollModes.CHASE:
		return
	var dead := CameraMath.DEADZONE
	var band := CameraMath.BAND
	var w_max := CameraMath.W_MAX

	# w_t = 0 inside the deadzone, ramps linearly across the band, saturates.
	h.near("w_t is 0 at deadzone edge", CameraMath.yaw_speed_target(dead), 0.0)
	h.near("w_t is 0 inside deadzone", CameraMath.yaw_speed_target(dead * 0.9), 0.0)
	h.near("w_t ramps halfway across the band",
		CameraMath.yaw_speed_target(dead + band * 0.5), w_max * 0.5, 0.000001)
	h.near("w_t saturates at the band edge",
		CameraMath.yaw_speed_target(dead + band), w_max, 0.000001)
	h.near("w_t saturates far outside", CameraMath.yaw_speed_target(PI * 0.9), w_max, 0.000001)
	h.near("w_t sign follows the error", CameraMath.yaw_speed_target(-(dead + band)), -w_max, 0.000001)

	# Finite angular acceleration: one step of w can never exceed W_ACCEL * dt.
	var acc = CameraChase.new(0.0)
	acc.step(PI, DT)
	h.at_most("one step respects W_ACCEL", absf(acc.w), CameraMath.W_ACCEL * DT + 1e-9)
	# The transient peaks at w_max and the settled state is 0 (the frame has
	# arrived), so the bound has to be measured over the whole run.
	var peak := 0.0
	for i in 600:
		acc.step(PI, DT)
		peak = maxf(peak, absf(acc.w))
	h.at_most("w never exceeds w_max", peak, w_max + 1e-6)
	h.at_least("w reaches w_max on a large error", peak, w_max - 1e-6)
	h.near("a settled frame has no speed left", acc.w, 0.0, 1e-9)

	# Inside the deadzone the frame holds perfectly still.
	var held = CameraChase.new(0.0)
	for i in 120:
		held.step(dead * 0.9, DT)
	h.near("inside deadzone the frame never moves", held.yaw, 0.0, 1e-12)
	h.near("inside deadzone w stays 0", held.w, 0.0, 1e-12)

	# Short way across the +-180 seam. From 179 to -165 the short arc is +16deg.
	var seam_yaw := deg_to_rad(179.0)
	var seam = CameraChase.new(seam_yaw)
	seam.step(deg_to_rad(-165.0), DT)
	h.ok("wrap takes the short way", seam.yaw > seam_yaw)
	h.near("wrap step stays within one accel step",
		rad_to_deg(absf(CameraMath.wrap_angle(seam.yaw - seam_yaw))),
		rad_to_deg(CameraMath.W_ACCEL * DT * DT), 0.01)

	# Settling: w_t is proportional to the error above the deadzone, so the chase
	# approaches the deadzone EDGE asymptotically. The equilibrium is the edge,
	# not zero error; "settled" means the remaining gap is invisible.
	for start_deg: float in [160.0, 90.0, 20.0]:
		var ch = CameraChase.new(deg_to_rad(start_deg))
		var ticks := -1
		var prev_gap := 1e9
		var monotone := true
		var sign_flips := 0
		var last_sign := 0.0
		for i in 600:
			var e := CameraMath.wrap_angle(0.0 - ch.yaw)
			var gap := rad_to_deg(absf(e)) - CameraMath.DEAD_DEG
			if gap > prev_gap + 0.0001:
				monotone = false
			prev_gap = gap
			var s := signf(e)
			if s != 0.0:
				if last_sign != 0.0 and s != last_sign:
					sign_flips += 1
				last_sign = s
			if gap <= 0.01:
				ticks = i
				break
			ch.step(0.0, DT)
		h.ok("settles within 4s from %.0f deg" % start_deg, ticks >= 0 and float(ticks) * DT <= 4.0)
		h.ok("never overshoots the player from %.0f deg" % start_deg, sign_flips == 0)
		h.ok("approaches monotonically from %.0f deg" % start_deg, monotone)
		h.note("settle from %.0f deg: %d ticks (%.2f s)" % [start_deg, ticks, float(ticks) * DT])

	# Determinism, §4.7: the same input sequence must give the same end state.
	var first := 0.0
	for run in 20:
		var d = CameraChase.new(deg_to_rad(37.0))
		for i in 90:
			d.step(deg_to_rad(-20.0 if i % 30 < 15 else 70.0), DT)
		if run == 0:
			first = d.yaw
		else:
			h.near("run %d is bit-identical" % run, d.yaw, first, 1e-12)


# --- §4.3: roll (ROLL mode 0 only: SNAP kicks, ORBIT holds a lean) -------
static func _roll(h, mode: int) -> void:
	if mode != RollModes.CHASE:
		return
	h.near("no yaw speed -> no roll", CameraMath.roll_target(0.0), 0.0)
	h.near("roll clamps at full speed", CameraMath.roll_target(CameraMath.W_MAX), -CameraMath.ROLL_MAX, 1e-9)
	h.near("roll clamps on reversal", CameraMath.roll_target(-CameraMath.W_MAX), CameraMath.ROLL_MAX, 1e-9)
	h.near("roll sign inverts with yaw speed",
		CameraMath.roll_target(1.0), -CameraMath.roll_target(-1.0))
	h.near("roll is linear below the clamp",
		CameraMath.roll_target(0.4), -CameraMath.ROLL_GAIN * 0.4, 1e-9)
	h.near("roll clamp is 12 deg", CameraMath.ROLL_MAX_DEG, 12.0)

	# §4.7: standing still, the horizon returns to within 1 deg in 0.6 s.
	var ch = CameraChase.new(0.0)
	ch.roll = CameraMath.ROLL_MAX
	var ticks := 0
	while ticks < 60 and absf(rad_to_deg(ch.roll)) > 1.0:
		ch.step(0.0, DT)
		ticks += 1
	h.at_most("roll returns to <=1deg within 0.6s", float(ticks) * DT, 0.6)
	h.note("roll return 12deg -> under 1deg: %d ticks (%.2f s)" % [ticks, float(ticks) * DT])
	for i in 90:
		ch.step(0.0, DT)
	h.near("roll settles exactly level", ch.roll, 0.0, 1e-12)

	# Roll is derived from yaw speed, and never feeds back into it (§4.2).
	var before = CameraChase.new(0.0)
	before.step(deg_to_rad(120.0), DT)
	var w_with_roll: float = before.w
	before.roll = CameraMath.ROLL_MAX
	before.step(deg_to_rad(120.0), DT)
	h.near("roll does not change yaw speed", before.w, w_with_roll + CameraMath.W_ACCEL * DT, 1e-9)


# --- §4.3 rig geometry --------------------------------------------------
static func _geometry(h) -> void:
	var offset: Vector3 = CameraMath.camera_offset()
	h.near("camera sits at DISTANCE", offset.length(), CameraMath.DISTANCE, 0.001)
	h.ok("camera is above the focus point", offset.y > 0.5)
	h.near("camera pitch is forward of the focus",
		rad_to_deg(atan2(offset.y, offset.z)), CameraMath.PITCH_DEG, 0.001)
	h.near("pitch is 55 deg", CameraMath.PITCH_DEG, 55.0)
	h.near("distance is 12 m", CameraMath.DISTANCE, 12.0)

	var euler: Vector3 = CameraMath.camera_euler(CameraMath.PITCH_DEG, 0.1)
	h.near("euler pitch is negative (looking down)", euler.x, -deg_to_rad(CameraMath.PITCH_DEG))
	h.near("euler roll passes through", euler.z, 0.1)


# --- §4.3: the mouse channel is isolated --------------------------------
static func _mouse(h) -> void:
	var rig = CameraRigScript.new()
	h.eq("rig defaults to ROLL mode 0 (CHASE)", rig.roll_mode, RollModes.CHASE)
	var w_before: float = rig.chase.w
	var roll_before: float = rig.chase.roll
	rig.mouse_look(200.0)
	h.ok("mouse moves the view offset", rig.yaw_offset < 0.0)
	h.at_most("mouse offset is clamped", absf(rig.yaw_offset), rig.MOUSE_OFFSET_MAX + 1e-9)
	for i in 40:
		rig.mouse_look(-400.0)
	h.near("mouse offset clamps the other way", rig.yaw_offset, rig.MOUSE_OFFSET_MAX, 1e-9)
	h.near("mouse never touches chase speed", rig.chase.w, w_before, 0.0)
	h.near("mouse never touches chase roll", rig.chase.roll, roll_before, 0.0)
	h.near("mouse decay constant is 1.2s", CameraMath.MOUSE_TAU, 1.2)
	rig.free()


# --- §4.5: the handheld bank follows the input, not the rules -----------
static func _tilt(h) -> void:
	var right := Vector3(1.0, 0.0, 0.0)
	var forward := Vector3(0.0, 0.0, -1.0)
	var idle: float = CameraRigScript.lean_target(Vector3.ZERO, 0.0, 0.0)
	h.near("no input -> no bank", idle, 0.0)
	var strafing: float = CameraRigScript.lean_target(right, 0.0, 0.0)
	h.ok("a screen-right step banks the frame", strafing < -0.05)
	h.near("bank is the mirror image on the other side",
		CameraRigScript.lean_target(-right, 0.0, 0.0), -strafing, 1e-9)
	var ahead: float = CameraRigScript.lean_target(forward, 0.0, 0.0)
	h.at_most("walking straight ahead barely banks", absf(ahead), 0.02)
	h.near("the cap holds under a big sidestep",
		CameraRigScript.lean_target(right * 4.0, 0.0, 0.0),
		-CameraRigScript.LEAN_MAX, 1e-9)
	h.at_most("spinning up banks into the turn",
		CameraRigScript.lean_target(Vector3.ZERO, 0.0, 2.0),
		-CameraRigScript.LEAN_MAX * 0.9)
	h.near("a spin alone cannot exceed the cap",
		CameraRigScript.lean_target(Vector3.ZERO, 0.0, 60.0),
		-CameraRigScript.LEAN_MAX, 1e-9)
	var rig = CameraRigScript.new()
	h.ok("tilt is on by default", rig.tilt_enabled)
	rig.tilt_enabled = false
	h.near("switching tilt off zeroes the bank", rig.lean, 0.0)
	rig.free()
