extends RefCounted
## NPCs are the fair half of DIE: they must be predictable to the millisecond
## and identical on every machine. Everything here is about determinism, not
## behaviour — the behaviour lives in the data.

const NpcPatrol = preload("res://scripts/npc/npc_patrol.gd")
const Harness = preload("res://tests/harness.gd")
const Geom = preload("res://tests/geom.gd")


static func run(h, _tree = null) -> void:
	h.begin("npc")

	var square := PackedVector3Array([
		Vector3(0, 0, 0), Vector3(4, 0, 0), Vector3(4, 0, 3), Vector3(0, 0, 3)])
	# Perimeter 14 m at 1 m/s -> a 14 s loop.
	var p0: Dictionary = NpcPatrol.state_at(square, 1.0, 0.0, "loop", 0.0)
	h.near("starts on the first point", p0["pos"].x, 0.0, 0.0001)

	var p4: Dictionary = NpcPatrol.state_at(square, 1.0, 0.0, "loop", 4.0)
	h.near("after 4s on the first leg", p4["pos"].x, 4.0, 0.001)
	h.near("stays on the leg Z", p4["pos"].z, 0.0, 0.001)
	h.eq("leg advanced once", int(p4["leg"]), 1)

	var p10: Dictionary = NpcPatrol.state_at(square, 1.0, 0.0, "loop", 10.0)
	h.near("after 10s it is on the way home", p10["pos"].z, 3.0, 0.001)
	h.near("traveled equals distance walked", float(p10["traveled"]), 10.0, 0.05)

	# Determinism: two calls, same answer, exactly.
	var a: Vector3 = NpcPatrol.pose_at(square, 1.15, 0.0, "loop", 7.31)
	var b: Vector3 = NpcPatrol.pose_at(square, 1.15, 0.0, "loop", 7.31)
	h.at_most("same second, same place", a.distance_to(b), 0.0)

	# Periodicity: one full loop later it is back where it was.
	var t := 3.7
	var one: Vector3 = NpcPatrol.pose_at(square, 1.0, 0.0, "loop", t)
	var two: Vector3 = NpcPatrol.pose_at(square, 1.0, 0.0, "loop", t + 14.0)
	h.at_most("loop repeats every 14s", one.distance_to(two), 0.02)
	h.note("loop period check: drift %.4f m over one lap" % one.distance_to(two))

	# Ping-pong walks back down the same line instead of looping.
	var line := PackedVector3Array([Vector3(0, 0, 0), Vector3(4, 0, 0)])
	var t6: Vector3 = NpcPatrol.pose_at(line, 1.0, 0.0, "pingpong", 6.0)
	h.near("pingpong turned around", t6.x, 2.0, 0.01)

	# Dwell: standing still at the end of a leg.
	var dw: Vector3 = NpcPatrol.pose_at(line, 1.0, 2.0, "pingpong", 5.0)
	h.near("dwell holds position", dw.x, 4.0, 0.01)

	# --- the real room -----------------------------------------------------
	var map: Variant = Harness.read_json("res://data/studio_map.json")
	h.ok("map parses", map is Dictionary)
	if not (map is Dictionary):
		return

	for id in ["director", "stagehand"]:
		var n := Geom.npc(map, id)
		h.ok("npc present: " + id, not n.is_empty())
		if n.is_empty():
			continue
		var route := Geom.npc_route(map, id)
		var spd := float(n.get("speed", 1.0))
		var perim := 0.0
		for i in route.size():
			perim += route[i].distance_to(route[(i + 1) % route.size()])
		var period := perim / spd
		h.at_least("%s patrol period is learnable (<40s)" % id, 40.0 - period, 0.0)
		h.note("%s: perimeter %.2f m at %.2f m/s -> %.2f s per lap"
			% [id, perim, spd, period])
		# Every corner must be somewhere a body could stand, or the NPC walks
		# through a wall and the whole danger model is a lie.
		for i in route.size():
			var p := Vector2(route[i].x, route[i].z)
			h.ok("%s waypoint %d is inside the room" % [id, i], Geom.walkable(map, p, 0.0))
