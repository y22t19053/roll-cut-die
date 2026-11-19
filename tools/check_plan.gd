extends SceneTree
## Static plan checker: walks every authored route's legs against the room's
## furniture and evidence reach, without any NPC or ghost timing.
##
##   godot --headless --path . --script tools/check_plan.gd
##
## test_routes.gd stops at the first blocked leg of the first take; this prints
## every blocked leg in all three takes so the route data can be fixed in one
## pass instead of one edit per run. Geometry only — timing is the test's job.

const Geom = preload("res://tests/geom.gd")
const Harness = preload("res://tests/harness.gd")

const STEP := 0.05


func _init() -> void:
	call_deferred("_main")
	call_deferred("_watchdog")


## A runtime error inside _main would otherwise leave the tree spinning until the
## caller kills the process with nothing printed, which is how two of today's runs
## were lost. Say so instead.
func _watchdog() -> void:
	await create_timer(60.0).timeout
	print("CHECK WATCHDOG: still running after 60 s — a runtime error killed _main.")
	quit(3)


func _main() -> void:
	var map: Dictionary = Harness.read_json("res://data/studio_map.json")
	var cfg: Dictionary = Harness.read_json("res://data/routes.json")
	if map.is_empty() or cfg.is_empty():
		print("CHECK: data did not parse")
		quit(2)
		return

	var solids: Array = Geom.solids(map)
	var size: Array = map.get("size", [0.0, 0.0])
	var reach := float(cfg.get("reach", 1.15))
	var bad := 0

	for take_def: Dictionary in cfg["takes"]:
		var take_no := int(take_def["take"])
		var here: Vector2 = Geom.rect_point(map["spawn"])
		print("TAKE %02d" % take_no)
		for step_def: Dictionary in take_def["plan"]:
			# A hold step has no destination: it is a clock instruction, not geometry.
			if not step_def.has("to"):
				if step_def.has("wait"):
					print("  wait    (%5.1f,%5.1f)  hold %.1f s" % [here.x, here.y, float(step_def["wait"])])
				continue
			var to := Vector2(float(step_def["to"][0]), float(step_def["to"][1]))
			var seg := to - here
			var dist := seg.length()
			var n := maxi(1, int(ceil(dist / STEP)))
			var blocked := Vector2.INF
			for i in range(0, n + 1):
				var p := here + seg * (float(i) / float(n))
				if not Geom.walkable_in(size, solids, p):
					blocked = p
					break

			var tag := ""
			if step_def.has("act"):
				var eid := str(step_def["act"])
				var ep: Vector2 = Geom.evidence_pos(map, eid)
				var d := to.distance_to(ep)
				tag = "  act=%s reach %.2f/%.2f" % [eid, d, reach]
				if d > reach:
					tag += "  REACH-FAIL"
					bad += 1

			if blocked.x < INF:
				bad += 1
				print("  BLOCKED (%5.1f,%5.1f) -> (%5.1f,%5.1f)  first hit (%.2f, %.2f) on %s%s"
					% [here.x, here.y, to.x, to.y, blocked.x, blocked.y, _solid_name(map, blocked), tag])
			else:
				print("  ok      (%5.1f,%5.1f) -> (%5.1f,%5.1f)  %.2f m%s"
					% [here.x, here.y, to.x, to.y, dist, tag])
			here = to

	print("PLAN %s (%d problems)" % ["CLEAR" if bad == 0 else "BLOCKED", bad])
	quit(0 if bad == 0 else 1)


## Which prop the point landed in, for a readable report. Walls are unnamed.
func _solid_name(map: Dictionary, p: Vector2) -> String:
	for prop: Dictionary in map.get("props", []):
		if not bool(prop.get("solid", true)):
			continue
		var r: Array = prop["rect"]
		if p.x >= float(r[0]) and p.x <= float(r[2]) and p.y >= float(r[1]) and p.y <= float(r[3]):
			return "prop '" + str(prop.get("id", "?")) + "'"
	return "a wall or the room edge"
