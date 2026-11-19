extends RefCounted
## The map and the case are two files that have to agree. Nothing in the engine
## enforces that, so this test does: an evidence id with no prop, or a prop with
## no evidence, is a bug that would only show up when a player walks up to
## nothing.

const RoomSpec = preload("res://scripts/world/room_spec.gd")
const Harness = preload("res://tests/harness.gd")
const Geom = preload("res://tests/geom.gd")


static func run(h, _tree = null) -> void:
	h.begin("map")

	var map: Variant = Harness.read_json("res://data/studio_map.json")
	h.ok("studio_map.json parses", map is Dictionary)
	if not (map is Dictionary):
		return

	var problems: Array = RoomSpec.validate(map)
	h.eq("map validates", problems.size(), 0)
	for p: String in problems:
		print("  map problem: ", p)

	# --- the map used to be rejected --------------------------------------
	var broken: Dictionary = map.duplicate(true)
	broken["size"] = [1.0, 1.0]
	h.ok("a 1x1 room is refused", RoomSpec.validate(broken).size() > 0)

	var no_evidence: Dictionary = map.duplicate(true)
	no_evidence["evidence"] = []
	h.ok("a map without evidence is refused", RoomSpec.validate(no_evidence).size() > 0)

	var bad_rect: Dictionary = map.duplicate(true)
	bad_rect["walls"] = [[0, 0, 1]]
	h.ok("a malformed rect is refused", RoomSpec.validate(bad_rect).size() > 0)

	# --- spawn and report zone are usable ---------------------------------
	var spawn: Vector2 = Geom.rect_point(map["spawn"])
	h.ok("spawn is walkable", Geom.walkable(map, spawn))
	var rz: Dictionary = map["report_zone"]
	var rzp := Vector2(float(rz["pos"][0]), float(rz["pos"][1]))
	h.ok("report zone is walkable", Geom.walkable(map, rzp))
	h.at_least("report zone is reachable from spawn on foot",
		10.0 - spawn.distance_to(rzp), 0.0)

	# --- every evidence item can actually be walked up to -----------------
	for e: Dictionary in map.get("evidence", []):
		var id := str(e.get("id", ""))
		var pos: Vector2 = Geom.evidence_pos(map, id)
		h.ok("%s is inside the room" % id, Geom.walkable(map, pos, 0.0))
		# A player must be able to stand within reach of it. Sample a ring.
		var found := false
		var best := 99.0
		for i in 24:
			var ang := TAU * float(i) / 24.0
			for r in [0.55, 0.75, 0.95, 1.1]:
				var p := pos + Vector2(cos(ang), sin(ang)) * float(r)
				if Geom.walkable(map, p) and Geom.segment_clear(map, pos, p, 0.05):
					found = true
					best = minf(best, float(r))
		h.ok("%s has a standing spot within reach" % id, found)
		h.note("%s: nearest stance %.2f m away" % [id, best])

	# --- map ids and case ids agree ---------------------------------------
	var case_data: Variant = Harness.read_json("res://data/case.json")
	h.ok("case.json parses", case_data is Dictionary)
	if not (case_data is Dictionary):
		return

	var map_ids: Array = []
	for e: Dictionary in map.get("evidence", []):
		map_ids.append(str(e.get("id", "")))
	map_ids.sort()
	var case_ids: Array = []
	for e: Dictionary in case_data.get("evidence", []):
		case_ids.append(str(e.get("id", "")))
	case_ids.sort()
	h.eq("evidence ids match between map and case", str(map_ids), str(case_ids))

	var map_npcs: Array = []
	for n: Dictionary in map.get("npcs", []):
		map_npcs.append(str(n.get("id", "")))
	map_npcs.sort()
	var case_npcs: Array = []
	for n: Dictionary in case_data.get("npcs", []):
		case_npcs.append(str(n.get("id", "")))
	case_npcs.sort()
	h.eq("npc ids match between map and case", str(map_npcs), str(case_npcs))

	# --- props do not swallow the doors -----------------------------------
	# The office has four doors; if furniture blocks one of them the room has a
	# fake route and take 3 will not be solvable.
	for door: Vector2 in [Vector2(12.0, 6.2), Vector2(12.0, 11.8), Vector2(8.2, 9.0), Vector2(15.8, 9.0)]:
		h.ok("door at %s is passable" % str(door), Geom.walkable(map, door))

	# --- both languages present on every visible string --------------------
	var missing := 0
	for e: Dictionary in case_data.get("evidence", []):
		for key in ["name", "inspect", "seal", "meaning"]:
			var block: Dictionary = e.get(key, {})
			if str(block.get("zh", "")).is_empty() or str(block.get("en", "")).is_empty():
				missing += 1
	for n: Dictionary in case_data.get("npcs", []):
		for line: Dictionary in n.get("lines", []):
			var t: Dictionary = line.get("text", {})
			if str(t.get("zh", "")).is_empty() or str(t.get("en", "")).is_empty():
				missing += 1
	for s: Dictionary in case_data.get("report", {}).get("stances", []):
		for key in ["name", "desc"]:
			var b: Dictionary = s.get(key, {})
			if str(b.get("zh", "")).is_empty() or str(b.get("en", "")).is_empty():
				missing += 1
	h.eq("no bilingual gaps in case text", missing, 0)
