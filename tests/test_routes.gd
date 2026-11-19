extends RefCounted
## THE PROOF THAT TAKE 2 AND TAKE 3 CAN STILL BE PLAYED.
##
## This is the test the design bible asks for and cannot have: it walks the
## three planned routes through the room at 60 Hz against the real NPC clocks
## and against the ghosts recorded from the earlier takes, using the same
## numbers the game loads. A route that only exists on paper fails here.
##
## Ghost timing model (must match scripts/ghost/ghost_actor.gd):
##   - a ghost replays its take from t=0 of the new take,
##   - its danger is OFF for the first GHOST_WARMUP seconds, because the
##     projection is still materialising and because every take starts on the
##     same mark — the new player needs a moment to step off it.
##
## Waits are not authored. A step marked "auto" searches forward for the first
## instant at which the whole crossing is clear, so the timings printed here are
## results. Edit waypoints; never hand-edit the seconds.

const Geom = preload("res://tests/geom.gd")
const Harness = preload("res://tests/harness.gd")
const NpcPatrol = preload("res://scripts/npc/npc_patrol.gd")

const DT := 1.0 / 60.0
## player radius 0.32 + npc danger 0.45
const NPC_CLEAR := 0.77
## player radius 0.32 + ghost danger 0.34
const GHOST_CLEAR := 0.66
const GHOST_WARMUP := 2.0
const MAX_WAIT := 25.0
const SEARCH := 0.1
const EVIDENCE_IDS := ["clapboard", "script_page", "walkie", "receipt"]

## Built once per npc: the search asks for thousands of poses per route.
## Populated by _prepare(); every hot helper below reads it.
static var _tl := {}
static var _solids: Array = []
static var _map_size: Array = [0.0, 0.0]


static func run(h, tree = null) -> void:
	h.begin("routes")

	var map: Variant = Harness.read_json("res://data/studio_map.json")
	var cfg: Variant = Harness.read_json("res://data/routes.json")
	h.ok("studio_map parses", map is Dictionary)
	h.ok("routes.json parses", cfg is Dictionary)
	if not (map is Dictionary) or not (cfg is Dictionary):
		return

	var takes: Array = cfg["takes"]
	h.eq("three takes are planned", takes.size(), 3)

	_tl = {}
	_prepare(map)
	var ghosts: Array = []
	for take_def: Dictionary in takes:
		var take_no := int(take_def["take"])
		var res := _simulate(map, cfg, take_def, ghosts)

		h.ok("TAKE %02d has a route" % take_no, str(res["problem"]).is_empty())
		if not str(res["problem"]).is_empty():
			print("  TAKE %02d BLOCKED: %s" % [take_no, res["problem"]])
			# Without this take's recording, later takes cannot be judged.
			break

		var trail: Array = res["trail"]
		var secs := float(trail.size()) * DT
		var min_npc := float(res["min_npc"])
		var min_ghost := float(res["min_ghost"])

		h.ok("TAKE %02d keeps %.2f m from the crew" % [take_no, min_npc], min_npc >= NPC_CLEAR)
		h.ok("TAKE %02d keeps %.2f m from the ghosts" % [take_no, min_ghost],
			min_ghost >= GHOST_CLEAR or min_ghost > 900.0)
		h.ok("TAKE %02d takes a sane amount of time (%.0f s)" % [take_no, secs], secs < 200.0)
		# Taking the four things is a set, not a sequence: TAKE 01 deliberately
		# starts with the receipt at the player's feet to teach the pickup.
		var got: Array = (res["acts"] as Array).duplicate()
		var want: Array = EVIDENCE_IDS.duplicate()
		got.sort()
		want.sort()
		h.eq("TAKE %02d collects all four" % take_no, str(got), str(want))

		h.note("TAKE %02d: %.1f s, %.1f m walked, npc %.2f m, ghost %.2f m"
			% [take_no, secs, float(res["meters"]), min_npc, min_ghost])
		for line: String in res["events"]:
			h.note(line)
		if not str(res.get("worst", "")).is_empty():
			h.note("  closest ghost call: " + str(res["worst"]))

		ghosts.append({"take": take_no, "trail": trail})


# --- hot-loop precomputation ----------------------------------------------

## Everything the search needs, built once: the room's solids and one analytic
## timeline per NPC. The route proof asks for millions of poses; anything built
## inside the inner loop makes the proof too slow to run before a commit, and a
## test that is too slow to run is a test that does not exist.
static func _prepare(map: Dictionary) -> void:
	_solids = Geom.solids(map)
	_map_size = map.get("size", [0.0, 0.0])
	_tl = {}
	for npc: Dictionary in map.get("npcs", []):
		var id := str(npc.get("id", ""))
		var pts: PackedVector3Array = Geom.npc_route(map, id)
		if pts.size() < 2:
			continue
		_tl[id] = NpcPatrol.build_timeline(pts, float(npc.get("speed", 1.0)),
			float(npc.get("dwell", 0.0)), str(npc.get("mode", "loop")))


static func _walkable(p: Vector2) -> bool:
	return Geom.walkable_in(_map_size, _solids, p)


# --- simulation ------------------------------------------------------------

static func _simulate(map: Dictionary, cfg: Dictionary, take_def: Dictionary, ghosts: Array) -> Dictionary:
	var speed := float(cfg.get("speed", 2.8))
	var act_time := float(cfg.get("act_time", 0.7))
	var reach := float(cfg.get("reach", 1.15))

	var here := Geom.rect_point(map["spawn"])
	var trail: Array = [here]
	var events: Array = []
	var acts: Array = []
	var meters := 0.0
	var min_npc := 1e9
	var min_ghost := 1e9
	var problem := ""

	for step_def: Dictionary in take_def["plan"]:
		if not problem.is_empty():
			break
		# A take may hold position on purpose: the crew and the ghosts move on a
		# clock, so standing still for a beat is a real route instruction.
		if step_def.has("wait"):
			var hold_s := float(step_def["wait"])
			var wf := int(round(hold_s / DT))
			var wsafe := _stand_frames(map, ghosts, here, trail.size(), wf)
			if wsafe < wf:
				var wb := _nearest(map, ghosts, here, float(trail.size() + wsafe) * DT)
				problem = "cannot wait %.1f s at (%.1f, %.1f): %s reaches %.2f m after %.1f s" % [
					hold_s, here.x, here.y, str(wb["who"]), float(wb["min"]), float(wsafe) * DT]
				break
			events.append("  wait %.1f s at (%.1f, %.1f)" % [hold_s, here.x, here.y])
			for i in wf:
				var wq := _nearest(map, ghosts, here, float(trail.size()) * DT)
				min_npc = minf(min_npc, float(wq["npc"]))
				min_ghost = minf(min_ghost, float(wq["ghost"]))
				trail.append(here)
			continue
		var to := Vector2(float(step_def["to"][0]), float(step_def["to"][1]))
		var auto := bool(step_def.get("auto", false))

		# 1. wait for a safe window, if this crossing needs one.
		var wait_frames := 0
		if auto:
			# A step that ends in taking something needs the stance to stay clear
			# for the whole reach-in, not just at the instant of arrival.
			var hold := int(round(act_time / DT)) if step_def.has("act") else 0
			var limit := _stand_frames(map, ghosts, here, trail.size(), int(MAX_WAIT / DT))
			var found := false
			var f := 0
			while f <= limit:
				if bool(_walk_check(map, ghosts, here, to, speed, trail.size() + f, hold)["ok"]):
					wait_frames = f
					found = true
					break
				f += int(round(SEARCH / DT))
			if not found:
				var wn := _nearest(map, ghosts, here, float(trail.size() + limit) * DT)
				problem = "no window to cross to (%.1f, %.1f); stood %.1f s, %s at %.2f m" % [
					to.x, to.y, float(limit) * DT, str(wn["who"]), float(wn["min"])]
				break
			if wait_frames > 0:
				events.append("  wait %.1f s at (%.1f, %.1f)" % [float(wait_frames) * DT, here.x, here.y])

		for i in wait_frames:
			trail.append(here)

		# 2. walk.
		var seg := to - here
		var dist := seg.length()
		var n := maxi(1, int(ceil(dist / (speed * DT))))
		var stepv := seg / float(n)
		var hit := false
		for i in range(1, n + 1):
			var p := here + stepv * float(i)
			if not _walkable(p):
				problem = "the line to (%.1f, %.1f) hits furniture at (%.2f, %.2f)" % [to.x, to.y, p.x, p.y]
				hit = true
				break
			var w := _nearest(map, ghosts, p, float(trail.size()) * DT)
			min_npc = minf(min_npc, float(w["npc"]))
			min_ghost = minf(min_ghost, float(w["ghost"]))
			trail.append(p)
		if hit:
			break
		meters += dist
		here = to

		# 3. stand still and take the thing.
		if step_def.has("act"):
			var eid := str(step_def["act"])
			var epos: Vector2 = Geom.evidence_pos(map, eid)
			var d := here.distance_to(epos)
			if d > reach:
				problem = "%s is %.2f m from the stance (%.2f, %.2f), reach is %.2f" % [
					eid, d, here.x, here.y, reach]
				break
			acts.append(eid)
			var frames := int(round(act_time / DT))
			var safe := _stand_frames(map, ghosts, here, trail.size(), frames)
			if safe < frames:
				var w := _nearest(map, ghosts, here, float(trail.size() + safe) * DT)
				problem = "the stance for %s is not safe for %.1f s (blocked by %s at %.2f m)" % [
					eid, act_time, str(w["who"]), float(w["min"])]
				break
			for i in frames:
				var w2 := _nearest(map, ghosts, here, float(trail.size()) * DT)
				min_npc = minf(min_npc, float(w2["npc"]))
				min_ghost = minf(min_ghost, float(w2["ghost"]))
				trail.append(here)

		# 4. file the report from inside the zone.
		if bool(step_def.get("report", false)):
			var rz: Dictionary = map["report_zone"]
			var rp := Vector2(float(rz["pos"][0]), float(rz["pos"][1]))
			var rad := float(rz["radius"])
			if here.distance_to(rp) > rad:
				problem = "the report must be filed within %.1f m of (%.1f, %.1f); we are %.2f m away" % [
					rad, rp.x, rp.y, here.distance_to(rp)]
				break

		# Print the clock where it is being designed against: at the pickups.
		if step_def.has("act") or bool(step_def.get("report", false)):
			events.append("  %5.1f s  (%.1f, %.1f)%s" % [float(trail.size()) * DT, here.x, here.y,
				"  took " + str(step_def["act"]) if step_def.has("act") else "  filed"])

	if problem.is_empty():
		var missing: Array = []
		for eid in EVIDENCE_IDS:
			if not acts.has(eid):
				missing.append(eid)
		if not missing.is_empty():
			problem = "the take never collects " + str(missing)

	# Name the frame where the closest ghost call happened: a bare 0.00 m cannot
	# be acted on, the time and place can.
	var worst := ""
	if min_ghost < GHOST_CLEAR:
		for i in trail.size():
			var ww := _nearest(map, ghosts, trail[i], float(i) * DT)
			if float(ww["ghost"]) < GHOST_CLEAR:
				var pp: Vector2 = trail[i]
				worst = "%s at %.1f s on (%.1f, %.1f)" % [str(ww["who"]), float(i) * DT, pp.x, pp.y]
				break

	if not problem.is_empty():
		return {"problem": problem, "trail": [], "events": events, "acts": acts,
			"min_npc": min_npc, "min_ghost": min_ghost, "meters": meters, "worst": worst}
	return {"problem": "", "trail": trail, "events": events, "acts": acts,
		"min_npc": min_npc, "min_ghost": min_ghost, "meters": meters, "worst": worst}


static func _walk_check(map: Dictionary, ghosts: Array, from: Vector2, to: Vector2,
		speed: float, start_frame: int, hold := 0) -> Dictionary:
	var seg := to - from
	var n := maxi(1, int(ceil(seg.length() / (speed * DT))))
	var stepv := seg / float(n)
	for i in range(0, n + 1):
		var p := from + stepv * float(i)
		if not _walkable(p):
			return {"ok": false, "why": "furniture"}
		var w := _nearest(map, ghosts, p, float(start_frame + i) * DT)
		if float(w["min"]) < float(w["need"]):
			return {"ok": false, "why": "blocked"}
	# A window that closes the moment you arrive is not a window: the stance has
	# to stay clear for the whole reach-in.
	for i in range(1, hold + 1):
		var w2 := _nearest(map, ghosts, to, float(start_frame + n + i) * DT)
		if float(w2["min"]) < float(w2["need"]):
			return {"ok": false, "why": "stance"}
	return {"ok": true, "why": ""}


## How many frames may we stand here before something wanders into us?
static func _stand_frames(map: Dictionary, ghosts: Array, pos: Vector2,
		start_frame: int, count: int) -> int:
	for i in count:
		var w := _nearest(map, ghosts, pos, float(start_frame + i) * DT)
		if float(w["min"]) < float(w["need"]):
			return i
	return count


## Closest threat at (pos, t): the crew and the ghosts are judged separately
## because they have different danger radii.
static func _nearest(map: Dictionary, ghosts: Array, pos: Vector2, t: float) -> Dictionary:
	var out := {"npc": 1e9, "ghost": 1e9, "min": 1e9, "need": 0.0, "who": ""}
	for npc: Dictionary in map.get("npcs", []):
		var id := str(npc.get("id", ""))
		var tl: Dictionary = _tl.get(id, {})
		if tl.is_empty():
			continue
		var p: Vector3 = NpcPatrol.state_from_timeline(tl, t)["pos"]
		var d := Vector2(p.x, p.z).distance_to(pos)
		out["npc"] = minf(float(out["npc"]), d)
		if d < float(out["min"]):
			out["min"] = d
			out["need"] = NPC_CLEAR
			out["who"] = id
	for g: Dictionary in ghosts:
		if t < GHOST_WARMUP:
			continue
		var tr: Array = g["trail"]
		if tr.size() == 0:
			continue
		# A ghost that has played out its recording retires, exactly as
		# ghost_actor.gd does: it must not keep standing on the mark it finished at.
		if t > float(tr.size() - 1) * DT:
			continue
		var idx := mini(int(floor(t / DT)), tr.size() - 1)
		var d2 := (tr[idx] as Vector2).distance_to(pos)
		out["ghost"] = minf(float(out["ghost"]), d2)
		if d2 < float(out["min"]):
			out["min"] = d2
			out["need"] = GHOST_CLEAR
			out["who"] = "TAKE %02d" % int(g["take"])
	return out
