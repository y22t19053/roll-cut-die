extends RefCounted
## CameraMath — the ROLL rule set, as constants and pure functions.
##
## Source of truth: docs/RCD_GAME_DESIGN_BIBLE.md §4.1–§4.3.
##   §4.1 three implementation rules, hard:
##     ① camera yaw chases the player's facing through a deadzone + finite
##       angular speed, so the frame always arrives late;
##     ② roll (Dutch tilt) is derived from yaw angular velocity, clamped, and
##       returns to level when the camera is still;
##     ③ pitch is a fixed downward angle; the mouse only corrects yaw.
##   §4.2 hard rule: movement is anchored to WORLD axes. Camera rotation changes
##     what you see, never what you press. (Camera-relative movement is rejected
##     there in as many words: it makes the mapping unstable.)
##   §4.2 hard rule: the camera takes part in no gameplay check at all.
##
## The one-way chain is input → facing → yaw → roll. The arrow never reverses:
## roll never feeds back into facing, yaw or speed.
##
## Numbers are the §4.3 starting values. They are all labelled 待验证 (V01–V07)
## in the bible: the relationships below are rule, the magnitudes are force
## settings awaiting playtest. Never change a relationship to fix a number.

# --- chase, §4.3 ---------------------------------------------------------
## Angle error below which the chase is completely still. Legibility: small
## corrections must never move the frame, so the player learns how much drift
## is free.
const DEAD_DEG := 8.0
const DEADZONE := DEAD_DEG * PI / 180.0
## Error range above the deadzone over which the target speed ramps to w_max.
const BAND_DEG := 25.0
const BAND := BAND_DEG * PI / 180.0
## Hard ceiling on camera yaw speed.
const W_MAX_DEG := 120.0
const W_MAX := W_MAX_DEG * PI / 180.0
## Hard ceiling on how fast that speed may change. This is what makes the frame
## feel like it has mass instead of snapping.
const W_ACCEL_DEG := 360.0
const W_ACCEL := W_ACCEL_DEG * PI / 180.0
## Below this angular speed the camera counts as still (drives roll return).
const W_EPSILON := 0.02

# --- roll, §4.3 ----------------------------------------------------------
## Radians of roll per rad/s of yaw speed. The bible writes it as "0.22 s".
const ROLL_GAIN := 0.22
## Clamp: the horizon may lean, it may never flip.
const ROLL_MAX_DEG := 12.0
const ROLL_MAX := ROLL_MAX_DEG * PI / 180.0
## Time to fall from full lean back to level.
const ROLL_RETURN_S := 0.35
## Linear roll speed, rad/s. Linear on purpose: an exponential approach never
## actually arrives, and §4.7 demands ≤ 1° within 0.6 s of standing still.
const ROLL_RATE := ROLL_MAX / ROLL_RETURN_S

# --- rig, §4.3 V05 -------------------------------------------------------
const PITCH_DEG := 55.0
const DISTANCE := 12.0
const FOV := 46.0
const FOCUS_HEIGHT := 1.0

# --- mouse, §4.3 ---------------------------------------------------------
## Mouse yaw offset decays back to zero with this time constant, and never
## counts as yaw velocity for roll (§4.3 已决策: otherwise the player could
## farm Dutch angle by flicking the mouse).
const MOUSE_TAU := 1.2


## Wrap to (-PI, PI].
static func wrap_angle(a: float) -> float:
	return wrapf(a, -PI, PI)


## Screen input to a world-space direction of length ≤ 1.
## input_xy: x = right (D), y = back (S); up is negative y, Godot screen order.
##
## World-anchored by rule (§4.2): W is always world -Z no matter where the camera
## is pointing. If this ever takes a yaw argument again, ROLL has been replaced
## by an ordinary third-person camera and the mechanic is gone.
static func move_dir(input_xy: Vector2) -> Vector3:
	var v := Vector3(input_xy.x, 0.0, input_xy.y)
	if v.length_squared() > 1.0:
		v = v.normalized()  # diagonal input must not be faster than cardinal
	if v.length_squared() <= 0.000001:
		return Vector3.ZERO
	return v


## The facing angle that points a -Z-forward actor along `dir`.
static func facing_from_dir(dir: Vector3) -> float:
	if dir.length_squared() <= 0.000001:
		return 0.0
	return atan2(-dir.x, -dir.z)


## Target yaw speed for an angle error, §4.3:
##   w_t = 0                                            if |e| <= dead
##       = sign(e) * min(1, (|e|-dead)/band) * w_max    otherwise
static func yaw_speed_target(err: float) -> float:
	var mag := absf(err)
	if mag <= DEADZONE:
		return 0.0
	return signf(err) * minf(1.0, (mag - DEADZONE) / BAND) * W_MAX


## Roll target for a yaw speed: roll_t = clamp(-gain * w, ±max).
## Negative sign: a camera operator panning left lets the frame fall right.
static func roll_target(yaw_speed: float) -> float:
	if absf(yaw_speed) <= W_EPSILON:
		return 0.0
	return clampf(-ROLL_GAIN * yaw_speed, -ROLL_MAX, ROLL_MAX)


## How far the pressed world direction is from the direction the camera is
## looking. This is the quantity the player is fighting: it is what makes W
## appear to go sideways. Read-only diagnostic for the debug overlay and tests.
static func view_drift(input_xy: Vector2, cam_yaw: float) -> float:
	var dir := move_dir(input_xy)
	if dir.length_squared() <= 0.000001:
		return 0.0
	return absf(wrap_angle(facing_from_dir(dir) - cam_yaw))


## Local position of the camera inside the rig.
static func camera_offset(pitch_deg: float = PITCH_DEG, dist: float = DISTANCE) -> Vector3:
	var pr := deg_to_rad(pitch_deg)
	return Vector3(0.0, dist * sin(pr), dist * cos(pr))


## Local rotation of the camera inside the rig: pitch down, then tilt.
static func camera_euler(pitch_deg: float = PITCH_DEG, roll: float = 0.0) -> Vector3:
	return Vector3(-deg_to_rad(pitch_deg), 0.0, roll)
