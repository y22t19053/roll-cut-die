extends Node3D
## CameraRig — the ROLL camera, §4.1 of the design bible.
##
## The rig sits on the player's focus point and orbits it at a fixed pitch. The
## orbit angle is not controlled directly: CameraChase makes it chase the
## player's facing through a deadzone and a finite angular speed, and that lag is
## the mechanic.
##
## Two yaw channels, kept strictly apart (§4.3 已决策):
##   active().yaw   automatic (chase / snap / orbit, see RollModes), and the
##                  ONLY source of roll;
##   yaw_offset     mouse correction, decays back to zero, never feeds roll.
## `yaw` is the effective view angle the rest of the game records and reads.

const CameraMath = preload("res://scripts/camera/camera_math.gd")
const CameraChase = preload("res://scripts/camera/camera_chase.gd")
const CameraSnap = preload("res://scripts/camera/camera_snap.gd")
const CameraOrbit = preload("res://scripts/camera/camera_orbit.gd")
const RollModes = preload("res://scripts/camera/roll_modes.gd")

signal roll_changed(roll_deg: float)

## Which ROLL scheme drives the automatic yaw channel (RollModes.CHASE/SNAP/ORBIT).
var roll_mode := RollModes.CHASE

## Effective camera orbit angle in radians (chase + mouse offset).
var yaw := 0.0
## Dutch tilt in radians, derived from yaw speed only.
var roll := 0.0
## Degrees below the horizon. Constant by design — no input may change it.
var pitch_deg := CameraMath.PITCH_DEG
var distance := CameraMath.DISTANCE
## Comfort settings (§4.6). These change presentation only, never rules.
var reduce_motion := false
var roll_scale := 1.0
var mouse_sensitivity := 0.0022

var target: Node3D
var camera: Camera3D
var chase = CameraChase.new()
var snap = CameraSnap.new()
var orbit = CameraOrbit.new()

## Mouse correction, radians. It is a view offset, not a gameplay input.
var yaw_offset := 0.0
## How far the mouse may push the frame away from the chase before it is
## clamped. PROPOSED guard: the bible fixes the 1.2 s decay but sets no cap, and
## an uncapped sweep can leave the camera looking at the player's back.
const MOUSE_OFFSET_MAX := PI / 3.0

var _shake := 0.0
var _shake_decay := 6.0
var _rng := RandomNumberGenerator.new()
var _t := 0.0


func _ready() -> void:
	_rng.seed = 0x5243  # fixed: shake must not make screenshots irreproducible
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.fov = CameraMath.FOV
	camera.near = 0.05
	camera.far = 250.0
	camera.current = true
	add_child(camera)
	_apply()


func setup(follow: Node3D) -> void:
	target = follow
	if target != null:
		var f: float = target.get("facing")
		chase.reset(f)
		snap.reset(f)
		orbit.reset(f)
		yaw_offset = 0.0
		yaw = chase.yaw
		global_position = target.global_position + Vector3.UP * CameraMath.FOCUS_HEIGHT
		_apply()


## Mouse correction channel (§4.1 rule ③: the mouse only corrects yaw).
func mouse_look(relative_x: float) -> void:
	yaw_offset = clampf(yaw_offset - relative_x * mouse_sensitivity,
		-MOUSE_OFFSET_MAX, MOUSE_OFFSET_MAX)


func add_shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func _physics_process(dt: float) -> void:
	if target == null or dt <= 0.0:
		return
	_t += dt

	var intent := Vector3.ZERO
	if target.has_method("intent"):
		intent = target.call("intent")
	var drv = active()
	drv.drive(target.get("facing"), intent, dt)

	yaw_offset *= exp(-dt / CameraMath.MOUSE_TAU)
	if absf(yaw_offset) < 0.00001:
		yaw_offset = 0.0

	yaw = CameraMath.wrap_angle(drv.yaw + yaw_offset)
	roll = 0.0 if reduce_motion else drv.roll * roll_scale

	if _shake > 0.0:
		_shake = maxf(0.0, _shake - _shake_decay * dt)

	global_position = target.global_position + Vector3.UP * CameraMath.FOCUS_HEIGHT
	rotation.y = yaw
	_apply()
	roll_changed.emit(rad_to_deg(roll))


func _apply() -> void:
	if camera == null:
		return
	var jitter := Vector3.ZERO
	var roll_total := roll
	if _shake > 0.0:
		jitter = Vector3(
			_rng.randf_range(-1.0, 1.0) * _shake * 0.06,
			_rng.randf_range(-1.0, 1.0) * _shake * 0.06,
			0.0
		)
		roll_total += _rng.randf_range(-1.0, 1.0) * _shake * 0.02
	camera.position = CameraMath.camera_offset(pitch_deg, distance) + jitter
	camera.rotation = CameraMath.camera_euler(pitch_deg, roll_total)


## The stepper that owns yaw and roll under the current mode.
func active():
	match roll_mode:
		RollModes.SNAP:
			return snap
		RollModes.ORBIT:
			return orbit
	return chase


## Switch scheme mid-shot. The new stepper starts from the current frame (same
## yaw, same lean) so the switch itself never jumps the picture.
func set_roll_mode(m: int) -> void:
	m = RollModes.clamp_mode(m)
	if m == roll_mode:
		return
	var prev = active()
	roll_mode = m
	var next = active()
	next.reset(prev.yaw)
	next.roll = prev.roll


## Simulation state, distinct from the effective angles shown by the preview.
func mark_motion() -> Dictionary:
	var drv = active()
	var state := {"mode": roll_mode, "offset": yaw_offset, "yaw": drv.yaw, "roll": drv.roll, "w": drv.w}
	for k in _mode_fields():
		state[k] = drv.get(k)
	return state

func _mode_fields() -> Array:
	match roll_mode:
		RollModes.ORBIT: return ["sense", "_heading", "_has_heading"]
		RollModes.SNAP: return ["target", "presses", "_from", "_t", "_heading", "_has_heading"]
	return []

func restore_mark_motion(point: Dictionary) -> void:
	var state: Dictionary = point.get("cam_motion", {})
	var drv = active()
	drv.reset(float(point.cam_yaw))
	yaw_offset = 0.0
	if state.get("mode", -1) == roll_mode:
		for k in ["yaw", "w", "roll"] + _mode_fields():
			drv.set(k, state[k])
		yaw_offset = state.offset
	else:
		# Older snapshots / a different selected mode: match pose without borrowing incompatible momentum.
		drv.roll = point.cam_roll / roll_scale if not is_zero_approx(roll_scale) else 0.0
	yaw = CameraMath.wrap_angle(drv.yaw + yaw_offset)
	roll = 0.0 if reduce_motion else drv.roll * roll_scale
	rotation.y = yaw
	_apply()

## Diagnostics for the debug overlay and for tests.
func snapshot() -> Dictionary:
	return {
		"mode": RollModes.mode_name(roll_mode),
		"yaw_deg": rad_to_deg(yaw),
		"chase_yaw_deg": rad_to_deg(chase.yaw),
		"yaw_offset_deg": rad_to_deg(yaw_offset),
		"w_deg": rad_to_deg(active().w),
		"roll_deg": rad_to_deg(roll),
		"pitch_deg": pitch_deg,
		"distance": distance,
	}
