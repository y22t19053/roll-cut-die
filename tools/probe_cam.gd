extends SceneTree
## Numeric probe for the ROLL chase (§4.3). Not a test: it reports the curve so
## the constants can be judged (settle time, overshoot, oscillation) instead of
## assumed.
##
## Key subtlety it exists to measure: w_t is proportional to the error above the
## deadzone, so the chase approaches the deadzone edge asymptotically and the
## equilibrium is the edge itself. "Settled" therefore means "residual gap to the
## edge is invisible", never "the error went to zero".
## Run: godot --headless --path . --script tests/probe_cam.gd

const CameraMath = preload("res://scripts/camera/camera_math.gd")
const CameraChase = preload("res://scripts/camera/camera_chase.gd")

const DT := 1.0 / 60.0


func _init() -> void:
	print("dead=%.2f band=%.2f w_max=%.1f accel=%.0f roll_max=%.2f" % [
		CameraMath.DEAD_DEG, CameraMath.BAND_DEG, CameraMath.W_MAX_DEG,
		CameraMath.W_ACCEL_DEG, CameraMath.ROLL_MAX_DEG])
	print("")
	for start_deg: float in [160.0, 90.0, 40.0, 20.0, 12.0, 5.0]:
		_report(start_deg)
	print("")
	print("--- roll from full lean, standing still ---")
	var ch = CameraChase.new(0.0)
	ch.roll = CameraMath.ROLL_MAX
	var ticks := 0
	while ticks < 300 and rad_to_deg(absf(ch.roll)) > 1.0:
		ch.step(0.0, DT)
		ticks += 1
	print("  roll %.1f deg -> <=1 deg in %d ticks (%.3f s)" % [
		CameraMath.ROLL_MAX_DEG, ticks, float(ticks) * DT])
	quit(0)


func _report(start_deg: float) -> void:
	var ch = CameraChase.new(deg_to_rad(start_deg))
	var target := 0.0
	var ticks := 0
	var settle_01 := -1
	var settle_0001 := -1
	var min_err := 1e9
	var flips := 0
	var last_sign := 0.0
	var max_roll := 0.0
	while ticks < 2400:
		var e: float = CameraMath.wrap_angle(target - ch.yaw)
		var gap: float = rad_to_deg(absf(e)) - CameraMath.DEAD_DEG
		min_err = minf(min_err, gap)
		max_roll = maxf(max_roll, rad_to_deg(absf(ch.roll)))
		var s := signf(e)
		if s != 0.0:
			if last_sign != 0.0 and s != last_sign:
				flips += 1
			last_sign = s
		if gap <= 0.01 and settle_01 < 0:
			settle_01 = ticks
		if gap <= 0.0001 and settle_0001 < 0:
			settle_0001 = ticks
			break
		ch.step(target, DT)
		ticks += 1
	print("from %6.1f deg: gap<=0.01deg at %4d ticks (%.2f s)  gap<=0.0001deg at %4d (%.2f s)  min_gap=%+.6f deg  sign_flips=%d  peak_roll=%.2f deg  w_end=%.4f deg/s" % [
		start_deg, settle_01, float(settle_01) * DT, settle_0001, float(settle_0001) * DT,
		min_err, flips, max_roll, rad_to_deg(ch.w)])
