extends SceneTree
## Measures the three ROLL schemes on the real Player and CameraRig nodes.
##
##   godot --headless --path . --script res://tests/probe_roll_modes.gd
##
## Not part of run_all: it prints curves for docs/ROLL_SCHEME_STUDY.md. It does
## end with a few sanity checks (exit 1 if any fails) so a broken mode cannot
## produce a plausible-looking table.
##
## Both nodes are stepped by hand, once per real physics frame (60 Hz, so the
## probe takes ~40 s of wall time), and output is bit-identical between runs. Every scenario starts from rest: player at the origin facing
## world -Z, camera behind it (yaw 0), roll 0.
##
## Columns: t, yaw (camera), roll, facing, pos (x,z), scr = where the player is
## actually moving ON SCREEN: 0 = up, +90 = right, -90 = left, 180 = down.
## "scr drift" while one key is held is the re-learning load: how far the
## on-screen meaning of an unchanged key moved.

const PlayerScript = preload("res://scripts/player/player.gd")
const CameraRigScript = preload("res://scripts/camera/camera_rig.gd")
const CameraMath = preload("res://scripts/camera/camera_math.gd")
const RollModes = preload("res://scripts/camera/roll_modes.gd")

const DT := 1.0 / 60.0
const SAMPLE_TICKS := 15  # 0.25 s

const W := Vector2(0, -1)
const D := Vector2(1, 0)

## name, [[input, seconds], ...]
const SCENARIOS := [
	["hold D 1s", [[D, 1.0]]],
	["hold W 1s", [[W, 1.0]]],
	["W->D switch x4 (0.5s each)", [[W, 0.5], [D, 0.5], [W, 0.5], [D, 0.5]]],
	# Steady state: does the mapping settle back to an ordinary game?
	["hold D 4s", [[D, 4.0]]],
]

var _fails := 0
## mode -> scenario -> summary
var _sum := {}


func _init() -> void:
	call_deferred("_main")


func _main() -> void:
	print("ROLL PROBE  dt=1/60  sample=0.25s")
	print("CHASE dead=%.0f w_max=%.0f/s accel=%.0f/s2 turn=%.0f/s | SNAP step=%.0f time=%.2fs | ORBIT w=%.0f/s accel=%.0f/s2 turn=%.0f/s | roll_max=%.0f" % [
		CameraMath.DEAD_DEG, CameraMath.W_MAX_DEG, CameraMath.W_ACCEL_DEG, RollModes.CHASE_TURN_RATE,
		RollModes.SNAP_STEP_DEG, RollModes.SNAP_TIME,
		RollModes.ORBIT_W_DEG, RollModes.ORBIT_ACCEL_DEG, RollModes.ORBIT_TURN_DEG,
		CameraMath.ROLL_MAX_DEG])
	for mode in RollModes.COUNT:
		_sum[mode] = {}
		for sc: Array in SCENARIOS:
			_sum[mode][sc[0]] = await _run(mode, str(sc[0]), sc[1])
	_table()
	_checks()
	print("")
	print("ROLL PROBE: %s" % ("OK" if _fails == 0 else "%d CHECK(S) FAILED" % _fails))
	quit(0 if _fails == 0 else 1)


func _run(mode: int, title: String, script: Array) -> Dictionary:
	var player = PlayerScript.new()
	root.add_child(player)
	player.set_physics_process(false)
	player.teleport(Vector3.ZERO, 0.0)
	player.roll_mode = mode
	var rig = CameraRigScript.new()
	root.add_child(rig)
	rig.set_physics_process(false)
	rig.setup(player)
	rig.set_roll_mode(mode)

	print("")
	print("=== %s · %s" % [RollModes.mode_name(mode), title])
	print("   t    yaw    roll  facing      x      z     scr")
	var tick := 0
	var peak_roll := 0.0
	var yaw_path := 0.0
	var scr_drift_max := 0.0
	var seg_scr_first := NAN
	var yaw_prev := 0.0
	_line(0.0, rig, player)
	for seg: Array in script:
		var input: Vector2 = seg[0]
		var ticks := int(round(float(seg[1]) / DT))
		player.input_override = input
		seg_scr_first = NAN
		for i in ticks:
			# move_and_slide() takes the PROCESS delta (wall clock) when called
			# outside a physics frame; inside one it is exactly 1/60.
			await physics_frame
			player._physics_process(DT)
			rig._physics_process(DT)
			tick += 1
			peak_roll = maxf(peak_roll, absf(rad_to_deg(rig.roll)))
			yaw_path += absf(rad_to_deg(CameraMath.wrap_angle(rig.yaw - yaw_prev)))
			yaw_prev = rig.yaw
			# Screen drift is measured once the body is at speed, so the
			# acceleration ramp is not counted as "the key changed meaning".
			if player.speed_now() > PlayerScript.SPEED * 0.9:
				var s := _scr(rig, player)
				if is_nan(seg_scr_first):
					seg_scr_first = s
				else:
					scr_drift_max = maxf(scr_drift_max, absf(_wrap_deg(s - seg_scr_first)))
			if tick % SAMPLE_TICKS == 0:
				_line(tick * DT, rig, player)

	var out := {
		"yaw": rad_to_deg(rig.yaw),
		"yaw_path": yaw_path,
		"roll_end": rad_to_deg(rig.roll),
		"peak_roll": peak_roll,
		"facing": rad_to_deg(player.facing),
		"disp": Vector2(player.global_position.x, player.global_position.z),
		"scr_end": _scr(rig, player),
		"scr_drift": scr_drift_max,
	}
	print("   -> yaw %+.1f (swept %.1f)  peak|roll| %.1f  end roll %+.1f  disp (%+.2f, %+.2f) |%.2f| m  scr_end %+.0f  max scr drift on a held key %.1f deg" % [
		out["yaw"], yaw_path, peak_roll, out["roll_end"], out["disp"].x, out["disp"].y,
		out["disp"].length(), out["scr_end"], scr_drift_max])
	rig.queue_free()
	player.queue_free()
	await process_frame
	return out


func _line(t: float, rig, player) -> void:
	print("%5.2f %+7.1f %+6.1f %+7.1f %+6.2f %+6.2f %+6.0f%s" % [
		t, rad_to_deg(rig.yaw), rad_to_deg(rig.roll), rad_to_deg(player.facing),
		player.global_position.x, player.global_position.z, _scr(rig, player),
		"" if player.speed_now() > 0.01 else " (still)"])


## On-screen bearing of the actual velocity: 0 up, +90 right.
func _scr(rig, player) -> float:
	var v: Vector3 = player.velocity
	if Vector2(v.x, v.z).length() < 0.01:
		return 0.0
	return -_wrap_deg(rad_to_deg(CameraMath.facing_from_dir(Vector3(v.x, 0, v.z)) - rig.yaw))


func _wrap_deg(a: float) -> float:
	return wrapf(a, -180.0, 180.0)


func _table() -> void:
	print("")
	print("=== SUMMARY")
	print("mode   scenario                      yaw_end  swept  peak_roll  roll_end  disp_m  scr_end  scr_drift")
	for mode in RollModes.COUNT:
		for sc: Array in SCENARIOS:
			var s: Dictionary = _sum[mode][sc[0]]
			print("%-6s %-28s %+7.1f %6.1f %9.1f %9.1f %7.2f %+8.0f %9.1f" % [
				RollModes.mode_name(mode), sc[0], s["yaw"], s["yaw_path"], s["peak_roll"],
				s["roll_end"], s["disp"].length(), s["scr_end"], s["scr_drift"]])


func _check(name: String, cond: bool) -> void:
	print("%s %s" % ["PASS" if cond else "FAIL", name])
	if not cond:
		_fails += 1


func _checks() -> void:
	print("")
	print("=== CHECKS")
	var d := "hold D 1s"
	var w := "hold W 1s"
	var sw := "W->D switch x4 (0.5s each)"
	# Movement is world-anchored in every mode: same keys, same displacement.
	for mode in RollModes.COUNT:
		_check("%s: hold D moves +X" % RollModes.mode_name(mode),
			_sum[mode][d]["disp"].x > 2.0 and absf(_sum[mode][d]["disp"].y) < 0.01)
		_check("%s: hold W moves -Z" % RollModes.mode_name(mode),
			_sum[mode][w]["disp"].y < -2.0 and absf(_sum[mode][w]["disp"].x) < 0.01)
	_check("CHASE: hold W leaves the frame still", absf(_sum[RollModes.CHASE][w]["yaw_path"]) < 0.01)
	_check("SNAP: hold D is exactly one 90 deg step",
		absf(_sum[RollModes.SNAP][d]["yaw"] + 90.0) < 0.01)
	_check("SNAP: hold W (already aligned) never snaps",
		_sum[RollModes.SNAP][w]["yaw_path"] < 0.01)
	_check("ORBIT: hold W still turns the frame",
		_sum[RollModes.ORBIT][w]["yaw_path"] > 20.0)
	_check("ORBIT: held key drifts on screen more than CHASE",
		_sum[RollModes.ORBIT][sw]["scr_drift"] > _sum[RollModes.CHASE][sw]["scr_drift"])
	_check("the three modes end on three different yaws after the switch run",
		absf(_sum[0][sw]["yaw"] - _sum[1][sw]["yaw"]) > 1.0
		and absf(_sum[1][sw]["yaw"] - _sum[2][sw]["yaw"]) > 1.0
		and absf(_sum[0][sw]["yaw"] - _sum[2][sw]["yaw"]) > 1.0)
