extends RefCounted
## CameraSnap — ROLL mode 1. The frame moves only when a direction is pressed.
##
## A press is any change of the 8-way heading to a new non-zero value (including
## from standing still). Each press turns the frame one SNAP_STEP toward the new
## heading, if that leaves the frame closer to it than before; otherwise nothing.
## Between presses the frame never moves, however far the heading is from it.
## Roll kicks to roll_target(w) during the swing and returns at ROLL_RATE.

const CameraMath = preload("res://scripts/camera/camera_math.gd")
const RollModes = preload("res://scripts/camera/roll_modes.gd")

var yaw := 0.0
var w := 0.0
var roll := 0.0
## Where the current (or last) swing ends. Always on the step lattice.
var target := 0.0
var presses := 0

var _from := 0.0
var _t := 0.0
var _has_heading := false
var _heading := 0.0


func _init(start_yaw: float = 0.0) -> void:
	reset(start_yaw)


func reset(new_yaw: float = 0.0) -> void:
	yaw = CameraMath.wrap_angle(new_yaw)
	target = yaw
	_from = yaw
	_t = RollModes.SNAP_TIME
	w = 0.0
	roll = 0.0
	_has_heading = false


func drive(_facing: float, intent: Vector3, dt: float) -> float:
	if dt <= 0.0:
		return 0.0
	if intent.length_squared() > 0.0001:
		var h := RollModes.quantize_heading(CameraMath.facing_from_dir(intent))
		if not _has_heading or absf(CameraMath.wrap_angle(h - _heading)) > 0.001:
			_press(h)
		_heading = h
		_has_heading = true
	else:
		_has_heading = false

	var before := yaw
	if _t < RollModes.SNAP_TIME:
		_t = minf(_t + dt, RollModes.SNAP_TIME)
		var a := smoothstep(0.0, 1.0, _t / RollModes.SNAP_TIME)
		yaw = CameraMath.wrap_angle(_from + CameraMath.wrap_angle(target - _from) * a)
	var dy := CameraMath.wrap_angle(yaw - before)
	w = dy / dt

	var rt := CameraMath.roll_target(w)
	if absf(rt) >= absf(roll) and signf(rt) * signf(roll) >= 0.0:
		roll = rt
	else:
		roll = move_toward(roll, rt, CameraMath.ROLL_RATE * dt)
	return dy


func _press(heading: float) -> void:
	var err := CameraMath.wrap_angle(heading - target)
	# Only step if it brings the frame closer: a diagonal 45 deg off never snaps.
	if absf(err) <= RollModes.SNAP_STEP * 0.5 + 0.001:
		return
	presses += 1
	_from = yaw
	target = CameraMath.wrap_angle(target + signf(err) * RollModes.SNAP_STEP)
	_t = 0.0
