extends RefCounted
## Geometry oracle for the level.
##
## Deliberately independent of the engine: the route proof must be about the
## data the game actually loads, not about whatever the physics server happened
## to do on one machine. Everything here is exact arithmetic on the same rects.

const PLAYER_RADIUS := 0.32


static func rect(a) -> Rect2:
	var x0 := float(a[0])
	var y0 := float(a[1])
	var x1 := float(a[2])
	var y1 := float(a[3])
	return Rect2(Vector2(minf(x0, x1), minf(y0, y1)),
		Vector2(absf(x1 - x0), absf(y1 - y0)))


## Every solid in the room: outer walls, the office, and the furniture.
static func solids(map: Dictionary) -> Array:
	var out: Array = []
	for w in map.get("walls", []):
		out.append(rect(w))
	for p in map.get("props", []):
		out.append(rect(p.get("rect", [0, 0, 0, 0])))
	return out


## Can a body of `radius` stand with its centre here?
static func walkable(map: Dictionary, p: Vector2, radius := PLAYER_RADIUS) -> bool:
	return walkable_in(map.get("size", [0.0, 0.0]), solids(map), p, radius)


## Same rule as walkable(), with the solids already built.
##
## The route proof calls this about a million times per run; rebuilding the
## Rect2 list from the JSON dictionaries on every call turned a four-second
## proof into a five-minute one. Callers in hot loops should call solids() once
## and use this overload.
static func walkable_in(size: Array, built_solids: Array, p: Vector2,
		radius := PLAYER_RADIUS) -> bool:
	if p.x < radius or p.y < radius:
		return false
	if p.x > float(size[0]) - radius or p.y > float(size[1]) - radius:
		return false
	for s: Rect2 in built_solids:
		if s.grow(radius).has_point(p):
			return false
	return true


## Straight-line walkability. Not a physics trace: walls are axis-aligned and
## the radius is folded into the growth, so sampling is honest at 0.1 m.
static func segment_clear(map: Dictionary, a: Vector2, b: Vector2, radius := PLAYER_RADIUS) -> bool:
	var d := b - a
	var steps := maxi(1, int(ceil(d.length() / 0.1)))
	for i in steps + 1:
		var p := a + d * (float(i) / float(steps))
		if not walkable(map, p, radius):
			return false
	return true


static func npc(map: Dictionary, id: String) -> Dictionary:
	for n: Dictionary in map.get("npcs", []):
		if str(n.get("id", "")) == id:
			return n
	return {}


static func npc_route(map: Dictionary, id: String) -> PackedVector3Array:
	var n := npc(map, id)
	var pts := PackedVector3Array()
	for pt in n.get("route", []):
		pts.append(Vector3(float(pt[0]), 0.0, float(pt[1])))
	return pts


static func evidence_pos(map: Dictionary, id: String) -> Vector2:
	for e: Dictionary in map.get("evidence", []):
		if str(e.get("id", "")) == id:
			return Vector2(float(e["pos"][0]), float(e["pos"][1]))
	return Vector2(-999, -999)


## [x, z] as a 2D point. Spawn and report zones share this shape.
static func rect_point(a) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))
