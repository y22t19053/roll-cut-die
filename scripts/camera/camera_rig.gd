extends Node3D
## CameraRig — the ROLL camera.
##
## The rig sits on the player's focus point and orbits it at a fixed pitch. The
## orbit angle (yaw) is not controlled directly: it chases the player's facing
## through CameraMath, which is where the mechanic lives. Mouse input is a
## correction channel only — it nudges yaw, it never owns it.

const CameraMath = preload("res://scripts/camera/camera_math.gd")
const Logger = preload("res://scripts/core/logger.gd")

signal roll_changed(roll_deg: float)

## Camera orbit angle in radians. Read by the player to build its move basis.
var yaw := 0.0
## Dutch tilt in radians, derived from yaw velocity.
var roll := 0.0
## Degrees below the horizon. Constant by design — no input may change it.
var pitch_deg := CameraMath.PITCH_DEG
var distance := CameraMath.DISTANCE
## Set by the comfort settings.
var reduce_motion := false
var mouse_sensitivity := 0.0022
## Scaling of roll for players who want less lean without losing the rule.
var roll_scale := 1.0

var target: Node3D
var camera: Camera3D

var _last_yaw := 0.0
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
	_last_yaw = yaw
	_apply()


func setup(follow: Node3D) -> void:
	target = follow
	if target != null:
		yaw = target.get("facing")
		_last_yaw = yaw
		global_position = target.global_position + Vector3.UP * CameraMath.FOCUS_HEIGHT
		_apply()


## Camera yaw offset from the mouse. Routes through the same wrap as the chase.
func mouse_look(relative_x: float) -> void:
	yaw = CameraMath.wrap_angle(yaw - relative_x * mouse_sensitivity)


func add_shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func _physics_process(dt: float) -> void:
	if target == null:
		return
	_t += dt
	var facing: float = target.get("facing")
	yaw = CameraMath.chase_step(yaw, facing, dt)

	var rate := 0.0
	if dt > 0.0:
		rate = CameraMath.wrap_angle(yaw - _last_yaw) / dt
	_last_yaw = yaw

	var rt := 0.0 if reduce_motion else CameraMath.roll_target(rate) * roll_scale
	roll = CameraMath.roll_step(roll, rt, dt)
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


## Diagnostics for the debug overlay and for tests.
func snapshot() -> Dictionary:
	return {
		"yaw_deg": rad_to_deg(yaw),
		"roll_deg": rad_to_deg(roll),
		"pitch_deg": pitch_deg,
		"distance": distance,
	}
