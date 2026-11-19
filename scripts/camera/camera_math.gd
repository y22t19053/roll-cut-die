extends RefCounted
## CameraMath — the whole ROLL rule set as pure functions.
##
## This file exists so the mechanic can be reasoned about and asserted without a
## scene tree. If it is not here, it is not a rule.
##
## Conventions
##   yaw    radians, camera orbit angle around the player. rig.rotation.y == yaw.
##   facing radians, the direction the actor is looking. 0 == world -Z.
##   pitch  degrees BELOW the horizon, constant. Never driven by input.
##   roll   radians, the Dutch tilt. Derived from yaw velocity only.
##
## The ROLL rule in one sentence: the camera does not sit behind the player, it
## *arrives* behind the player, late, at a bounded speed, and it tilts while it
## turns. Holding a strafe key therefore curves your path, because your frame of
## reference drags behind you.

# --- chase ---------------------------------------------------------------
## Angle error below which the camera refuses to move at all. This is what makes
## the mechanic legible: small corrections never move the frame, so the player
## learns exactly how much drift is "free".
const DEADZONE := 0.20  # rad, ~11.5 deg
## Error range above the deadzone over which chase speed ramps to MAX_RATE.
const RAMP := 0.55  # rad, ~31.5 deg
## Hard ceiling on camera yaw speed.
const MAX_RATE := 1.55  # rad/s, ~89 deg/s

# --- roll ----------------------------------------------------------------
## Radians of roll per rad/s of yaw rate.
const ROLL_GAIN := 0.30
## Clamp. The horizon may lean, it may never flip.
const ROLL_MAX := 0.19  # rad, ~10.9 deg
## Exponential return rate, 1/s.
const ROLL_DAMP := 7.0

# --- rig -----------------------------------------------------------------
const PITCH_DEG := 52.0
const DISTANCE := 11.0
const FOV := 46.0
const FOCUS_HEIGHT := 1.0


## Wrap to (-PI, PI].
static func wrap_angle(a: float) -> float:
	return wrapf(a, -PI, PI)


## Camera-relative input to a world-space unit-or-shorter direction.
## input_xy: x = right, y = back (Godot screen convention: up is negative y).
static func move_dir(input_xy: Vector2, cam_yaw: float) -> Vector3:
	var v := Vector3(input_xy.x, 0.0, input_xy.y)
	if v.length_squared() > 1.0:
		v = v.normalized()
	if v.length_squared() <= 0.000001:
		return Vector3.ZERO
	return v.rotated(Vector3.UP, cam_yaw)


## The facing angle that points a -Z-forward actor along `dir`.
static func facing_from_dir(dir: Vector3) -> float:
	if dir.length_squared() <= 0.000001:
		return 0.0
	return atan2(-dir.x, -dir.z)


## One fixed step of the chase. Never overshoots, never exceeds MAX_RATE.
static func chase_step(yaw: float, facing: float, dt: float, cfg: Dictionary = {}) -> float:
	if dt <= 0.0:
		return yaw
	var dz: float = cfg.get("deadzone", DEADZONE)
	var ramp: float = cfg.get("ramp", RAMP)
	var rate: float = cfg.get("max_rate", MAX_RATE)
	var d := wrapf(facing - yaw, -PI, PI)
	var mag := absf(d)
	if mag <= dz:
		return yaw
	var over := mag - dz
	# Soft start: a 1 degree error must not move the frame as fast as a 40 degree
	# error, otherwise the deadzone edge feels like a cliff.
	var strength := minf(over / maxf(ramp, 0.0001), 1.0)
	var step := minf(over, rate * strength * dt)
	return wrapf(yaw + signf(d) * step, -PI, PI)


## Target roll for a given yaw rate. Sign is chosen so the world leans against
## the turn (a camera operator panning left lets the frame fall right).
static func roll_target(yaw_rate: float) -> float:
	return clampf(-yaw_rate * ROLL_GAIN, -ROLL_MAX, ROLL_MAX)


## Frame-rate independent exponential approach toward the roll target.
static func roll_step(roll: float, target: float, dt: float) -> float:
	if dt <= 0.0:
		return roll
	return lerpf(roll, target, 1.0 - exp(-ROLL_DAMP * dt))


## Local position of the camera inside the rig.
static func camera_offset(pitch_deg: float = PITCH_DEG, dist: float = DISTANCE) -> Vector3:
	var pr := deg_to_rad(pitch_deg)
	return Vector3(0.0, dist * sin(pr), dist * cos(pr))


## Local rotation of the camera inside the rig: pitch down, then tilt.
static func camera_euler(pitch_deg: float = PITCH_DEG, roll: float = 0.0) -> Vector3:
	return Vector3(-deg_to_rad(pitch_deg), 0.0, roll)


## How much of the straight-line input actually reaches the world, given that
## the camera is still catching up. Exposed for tests and for the debug overlay.
static func drift_ratio(input_xy: Vector2, cam_yaw: float, facing: float) -> float:
	var dir := move_dir(input_xy, cam_yaw)
	if dir.length_squared() <= 0.000001:
		return 0.0
	var want := facing_from_dir(dir)
	return absf(wrapf(want - facing, -PI, PI))
