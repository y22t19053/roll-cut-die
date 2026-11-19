extends RefCounted
## CameraOrbit — ROLL mode 2. Walking turns the world.
##
## While any direction is held the camera revolves around the player at ORBIT_W.
## The sense is set on each press by which side of the screen that press points
## to: step screen-right and the camera starts walking round to your right, and
## keeps going until you let go. A press straight up/down the screen keeps the
## previous sense. On release it spins down and stays where it stopped.
## Roll comes from the revolution speed, so a held walk carries a steady lean.

const CameraMath = preload("res://scripts/camera/camera_math.gd")
const RollModes = preload("res://scripts/camera/roll_modes.gd")

var yaw := 0.0
var w := 0.0
var roll := 0.0
## +1: camera position revolves counter-clockwise seen from above (yaw grows).
var sense := 1.0

var _has_heading := false
var _heading := 0.0


func _init(start_yaw: float = 0.0) -> void:
	reset(start_yaw)


func reset(new_yaw: float = 0.0) -> void:
	yaw = CameraMath.wrap_angle(new_yaw)
	w = 0.0
	roll = 0.0
	sense = 1.0
	_has_heading = false


func drive(_facing: float, intent: Vector3, dt: float) -> float:
	if dt <= 0.0:
		return 0.0
	var want := 0.0
	var mag := intent.length()
	if mag > 0.01:
		var h := RollModes.quantize_heading(CameraMath.facing_from_dir(intent))
		if not _has_heading or absf(CameraMath.wrap_angle(h - _heading)) > 0.001:
			var lat := RollModes.screen_lateral(intent / mag, yaw)
			if absf(lat) >= RollModes.ORBIT_LATERAL_MIN:
				sense = signf(lat)
		_heading = h
		_has_heading = true
		want = sense * RollModes.ORBIT_W * minf(mag, 1.0)
	else:
		_has_heading = false

	w = move_toward(w, want, RollModes.ORBIT_ACCEL * dt)
	var before := yaw
	yaw = CameraMath.wrap_angle(yaw + w * dt)
	roll = move_toward(roll, CameraMath.roll_target(w), CameraMath.ROLL_RATE * dt)
	return CameraMath.wrap_angle(yaw - before)
