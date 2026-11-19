extends RefCounted
## GhostTrack is the save format. If it is lossy or non-deterministic the whole
## premise breaks: the ghost you face in take 3 must be the run you actually
## did in take 1, not an approximation of it.

const GhostTrack = preload("res://scripts/ghost/ghost_track.gd")


static func run(h, _tree = null) -> void:
	h.begin("ghost")

	var t = GhostTrack.new()
	t.take_id = 1
	h.eq("starts empty", t.size(), 0)
	h.near("empty duration", t.duration(), 0.0)

	h.ok("first sample accepted", t.add_sample(0.0, Vector3(1.0, 0.0, 2.0), 0.5, 1.0, 0.0))
	h.ok("non-increasing time rejected", not t.add_sample(0.0, Vector3(9.0, 0.0, 9.0), 0.0, 0.0, 0.0))
	h.ok("second sample accepted", t.add_sample(0.1, Vector3(2.0, 0.0, 4.0), 0.7, 1.2, 0.05))
	h.eq("two samples stored", t.size(), 2)

	# --- interpolation -----------------------------------------------------
	var mid: Dictionary = t.sample_at(0.05)
	h.near("interpolated X", mid["position"].x, 1.5, 0.001)
	h.near("interpolated Z", mid["position"].z, 3.0, 0.001)
	h.near("interpolated facing", mid["facing"], 0.6, 0.01)
	h.ok("mid sample is not finished", not mid["finished"])

	var before: Dictionary = t.sample_at(-1.0)
	h.near("before start holds first frame", before["position"].x, 1.0, 0.001)
	var after: Dictionary = t.sample_at(99.0)
	h.near("after end holds last frame", after["position"].x, 2.0, 0.001)
	h.ok("after end is finished", after["finished"])

	# --- flags -------------------------------------------------------------
	# A stationary player is mostly noise, so identical frames are dropped. A new
	# flag is an event though: it keeps its own timestamp instead of being
	# attached to the start of the standstill.
	h.ok("identical frame with no news is dropped",
		not t.add_sample(0.15, Vector3(2.0, 0.0, 4.0), 0.7, 1.2, 0.05))
	t.add_sample(0.2, Vector3(2.0, 0.0, 4.0), 0.7, 1.2, 0.05, GhostTrack.FLAG_INTERACT)
	h.eq("an interact on a still frame keeps its own sample", t.size(), 3)
	var folded: Dictionary = t.sample_at(0.2)
	h.ok("folded sample keeps the interact flag", folded["interact"])

	# --- quantisation ------------------------------------------------------
	# quant_pos/dequant_pos work per component (millimetre ints in flat arrays),
	# so a Vector3 round-trip is three calls, not one.
	var probe := Vector3(-7.1234, 1.5, 12.9876)
	var round_pos := Vector3(
		GhostTrack.dequant_pos(GhostTrack.quant_pos(probe.x)),
		GhostTrack.dequant_pos(GhostTrack.quant_pos(probe.y)),
		GhostTrack.dequant_pos(GhostTrack.quant_pos(probe.z))
	)
	h.at_most("position round-trips within 1mm", probe.distance_to(round_pos), 0.0011)

	var ang := deg_to_rad(-137.25)
	var round_ang: float = GhostTrack.dequant_ang(GhostTrack.quant_ang(ang))
	h.at_most("angle round-trips within 0.02deg", absf(rad_to_deg(round_ang) - rad_to_deg(ang)), 0.02)

	# --- persistence -------------------------------------------------------
	var src = GhostTrack.new()
	src.take_id = 2
	for i in 40:
		var f := float(i) * 0.1
		src.add_sample(f, Vector3(sin(f), 0.0, cos(f) * 3.0), f * 0.5, f * 0.3, 0.0)
	var dict: Dictionary = src.to_dict()
	var back = GhostTrack.from_dict(dict)
	h.ok("round-trip returns a track", back != null)
	if back != null:
		h.eq("take id survives", back.take_id, 2)
		h.eq("sample count survives", back.size(), src.size())
		h.at_most("reload is bit-identical", src.max_deviation(back), 0.0)
		h.near("duration survives", back.duration(), src.duration(), 0.000001)

	h.ok("wrong version refused", GhostTrack.from_dict({"version": 99, "take_id": 1, "n": 0}) == null)
	h.ok("truncated data refused",
		GhostTrack.from_dict({"version": 1, "take_id": 1, "n": 5, "t": [0], "x": [0], "y": [0],
			"z": [0], "f": [0], "cy": [0], "cr": [0], "fl": [0]}) == null)

	# --- data weight -------------------------------------------------------
	# The save file has to survive a hundred takes. 10 Hz is the budget: one
	# second of play must cost about 10 samples and well under a kilobyte.
	src.clear()
	for i in 600:
		src.add_sample(float(i) * 0.1, Vector3(float(i) * 0.01, 0.0, 0.0), 0.0, 0.0, 0.0)
	h.eq("one minute at 10Hz is 600 samples", src.size(), 600)
	h.note("60s track stored as %d bytes (%.1f B/s) after JSON"
		% [_json_bytes(src), _json_bytes(src) / 60.0])


static func _json_bytes(track) -> int:
	return JSON.stringify(track.to_dict()).length()
