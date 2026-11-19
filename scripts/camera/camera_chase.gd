extends RefCounted
## CameraChase — the stateful half of ROLL: yaw speed, yaw, roll.
##
## CameraMath holds the relationships (pure), this holds the integration (state).
## It is a separate object so the mechanic can be stepped and asserted without a
## SceneTree, and so the rig cannot accidentally drive yaw from anywhere else.
##
## Order inside one step, exactly as §4.3:
##   e     = wrap_pi(target_yaw - cam_yaw)
##   w_t   = CameraMath.yaw_speed_target(e)
##   w     = move_toward(w, w_t, W_ACCEL * dt)        # finite angular accel
##   yaw  += w * dt
##   roll  = move_toward(roll, roll_target(w), ROLL_RATE * dt)
##
## Mouse yaw is deliberately NOT part of this object: §4.3 decided that
## mouse-driven yaw must not feed roll, otherwise the player could farm Dutch
## angle. The rig adds its decaying mouse offset on top of `yaw` for the view.

const CameraMath = preload("res://scripts/camera/camera_math.gd")

## Camera orbit angle, radians. 0 == world -Z.
var yaw := 0.0
## Yaw speed, rad/s. Always within ±W_MAX.
var w := 0.0
## Dutch tilt, radians. Always within ±ROLL_MAX.
var roll := 0.0


func _init(start_yaw: float = 0.0) -> void:
	yaw = CameraMath.wrap_angle(start_yaw)


## Snap to a pose without any motion (spawn, retake, replay seek).
func reset(new_yaw: float = 0.0) -> void:
	yaw = CameraMath.wrap_angle(new_yaw)
	w = 0.0
	roll = 0.0


## One fixed step of the chase. Returns the yaw change actually applied, rad.
func step(target_yaw: float, dt: float) -> float:
	if dt <= 0.0:
		return 0.0

	var err := CameraMath.wrap_angle(target_yaw - yaw)
	var w_target := CameraMath.yaw_speed_target(err)
	w = move_toward(w, w_target, CameraMath.W_ACCEL * dt)
	w = clampf(w, -CameraMath.W_MAX, CameraMath.W_MAX)

	var before := yaw
	yaw = CameraMath.wrap_angle(yaw + w * dt)

	roll = move_toward(roll, CameraMath.roll_target(w), CameraMath.ROLL_RATE * dt)
	return CameraMath.wrap_angle(yaw - before)


## Diagnostics for the debug overlay and for tests.
func snapshot() -> Dictionary:
	return {
		"yaw_deg": rad_to_deg(yaw),
		"w_deg": rad_to_deg(w),
		"roll_deg": rad_to_deg(roll),
	}
