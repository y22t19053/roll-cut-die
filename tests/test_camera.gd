extends RefCounted
## ROLL is a rule, not a feel. Every claim in docs/ROLL_CAMERA_DESIGN.md that
## can be computed gets computed here: direction, deadzone, angular rate cap,
## roll clamp, and the property that actually matters — a player who keeps
## walking in one direction ends up seeing straight down that direction.

const CameraMath = preload("res://scripts/camera/camera_math.gd")


static func run(h, _tree = null) -> void:
	h.begin("camera")

	# --- direction ---------------------------------------------------------
	var fwd: Vector3 = CameraMath.move_dir(Vector2(0, -1), 0.0)
	h.near("W at yaw 0 -> -Z", fwd.z, -1.0)
	h.near("W at yaw 0 -> no X", fwd.x, 0.0)

	var right: Vector3 = CameraMath.move_dir(Vector2(1, 0), 0.0)
	h.near("D at yaw 0 -> +X", right.x, 1.0)

	var back: Vector3 = CameraMath.move_dir(Vector2(0, 1), 0.0)
	h.near("S at yaw 0 -> +Z", back.z, 1.0)

	# Camera looks along -Z at yaw 0, so pressing W must move along -Z for ANY yaw.
	for deg in [15.0, 45.0, 90.0, 180.0, -60.0]:
		var yaw := deg_to_rad(deg)
		var d: Vector3 = CameraMath.move_dir(Vector2(0, -1), yaw)
		h.near("W follows camera yaw %.0f" % deg, d.length(), 1.0, 0.0005)
		var look := Vector3(-sin(yaw), 0.0, -cos(yaw))
		h.near("W matches look dir at yaw %.0f" % deg, d.dot(look), 1.0, 0.0005)

	# Diagonal input must not be faster than cardinal input.
	var diag: Vector3 = CameraMath.move_dir(Vector2(1, -1), 0.0)
	h.near("diagonal clamped to 1", diag.length(), 1.0, 0.0005)
	h.eq("zero input -> zero", CameraMath.move_dir(Vector2.ZERO, 1.0), Vector3.ZERO)

	# --- facing ------------------------------------------------------------
	h.near("facing of -Z is 0", CameraMath.facing_from_dir(Vector3(0, 0, -1)), 0.0)
	h.near("facing of +X is -90deg", CameraMath.facing_from_dir(Vector3(1, 0, 0)), deg_to_rad(-90.0))
	h.near("facing of +Z is 180deg", absf(CameraMath.facing_from_dir(Vector3(0, 0, 1))), PI)

	# --- chase -------------------------------------------------------------
	# Inside the deadzone the camera does not move at all: this is what makes
	# the small corrections near a wall feel stable instead of twitchy.
	var held: float = CameraMath.chase_step(0.0, CameraMath.DEADZONE * 0.5, 1.0 / 60.0)
	h.near("inside deadzone holds", held, 0.0)

	# A single step never exceeds MAX_RATE.
	var stepped: float = CameraMath.chase_step(0.0, PI * 0.5, 1.0 / 60.0)
	h.at_most("one step respects MAX_RATE", absf(stepped), CameraMath.MAX_RATE / 60.0 + 1e-6)

	# Wrap: going from -179 to +179 degrees must take the short way.
	var wrapped: float = CameraMath.chase_step(deg_to_rad(179.0), deg_to_rad(-179.0), 1.0 / 60.0)
	h.ok("wrap takes the short way", wrapped > deg_to_rad(179.0))

	# Convergence: hold W (facing -Z), camera should settle on facing in < 1.5 s.
	var yaw := deg_to_rad(160.0)
	var dt := 1.0 / 60.0
	var ticks := 0
	var facing := 0.0  # walking towards -Z
	while ticks < 600 and absf(CameraMath.wrap_angle(yaw - facing)) > CameraMath.DEADZONE:
		yaw = CameraMath.chase_step(yaw, facing, dt)
		ticks += 1
	h.at_most("settles within 1.5s", float(ticks) * dt, 1.5)
	h.note("convergence from 160deg: %d ticks (%.2fs)" % [ticks, float(ticks) * dt])

	# --- roll --------------------------------------------------------------
	h.near("no yaw rate -> no roll", CameraMath.roll_target(0.0), 0.0)
	h.at_most("roll is clamped", absf(CameraMath.roll_target(99.0)), CameraMath.ROLL_MAX + 1e-6)
	h.near("roll sign inverts with yaw rate",
		CameraMath.roll_target(1.0), -CameraMath.roll_target(-1.0))

	var r := 0.0
	var target: float = CameraMath.roll_target(1.0)
	for i in 120:
		r = CameraMath.roll_step(r, target, dt)
	h.near("roll converges to target", r, target, 0.01)

	# --- geometry ----------------------------------------------------------
	var offset: Vector3 = CameraMath.camera_offset()
	h.near("camera sits at DISTANCE", offset.length(), CameraMath.DISTANCE, 0.001)
	h.ok("camera is above the focus point", offset.y > 0.5)
	h.near("camera pitch is forward of the focus",
		rad_to_deg(atan2(offset.y, offset.z)), CameraMath.PITCH_DEG, 0.001)

	var euler: Vector3 = CameraMath.camera_euler(CameraMath.PITCH_DEG, 0.1)
	h.near("euler pitch is negative (looking down)", euler.x, -deg_to_rad(CameraMath.PITCH_DEG))
	h.near("euler roll passes through", euler.z, 0.1)

	# --- comfort -----------------------------------------------------------
	# The whole point of ROLL is that holding one direction is safe. If drift is
	# large the game is nauseating, so drift is a tested quantity, not a taste.
	var still: float = CameraMath.drift_ratio(Vector2(0, -1), 0.0, 0.0)
	h.near("no drift when aligned", still, 0.0, 0.0001)
