extends RefCounted
## RoomSpec — validates data/studio_map.json before a single node is built.
##
## A map that fails validation is not loaded at all: a half-built room is worse
## than a loud refusal, because the player would learn the wrong geometry.

const SCHEMA_VERSION := 1


static func is_xy(v: Variant) -> bool:
	if not (v is Array):
		return false
	var a: Array = v
	if a.size() != 2:
		return false
	for x: Variant in a:
		if not (x is float or x is int):
			return false
	return true


static func xy(v: Array) -> Vector2:
	return Vector2(float(v[0]), float(v[1]))


static func is_rect(v: Variant) -> bool:
	if not (v is Array) or (v as Array).size() != 4:
		return false
	for x: Variant in v:
		if not (x is float or x is int):
			return false
	return true


static func rect(v: Variant) -> Rect2:
	var a: Array = v
	var x0 := float(a[0])
	var z0 := float(a[1])
	var x1 := float(a[2])
	var z1 := float(a[3])
	return Rect2(Vector2(minf(x0, x1), minf(z0, z1)), Vector2(absf(x1 - x0), absf(z1 - z0)))


## Returns an array of human-readable problems. Empty means valid.
static func validate(d: Variant) -> Array:
	var out: Array = []
	if not (d is Dictionary):
		out.append("map: root must be a dictionary")
		return out
	var m: Dictionary = d

	if int(m.get("schema_version", 0)) != SCHEMA_VERSION:
		out.append("map: schema_version must be %d" % SCHEMA_VERSION)

	var size: Variant = m.get("size", null)
	if not is_xy(size) or (size as Array).size() != 2:
		out.append("map: size must be [width, depth]")
		return out
	var w := float(size[0])
	var h := float(size[1])
	if w < 6.0 or h < 6.0:
		out.append("map: size %.1fx%.1f is too small to be a room" % [w, h])
	if w > 120.0 or h > 120.0:
		out.append("map: size %.1fx%.1f is too large for one scene" % [w, h])

	var spawn: Variant = m.get("spawn", null)
	if not is_xy(spawn):
		out.append("map: spawn must be [x, z]")
	elif not _inside(xy(spawn), w, h):
		out.append("map: spawn %s is outside the room" % str(spawn))

	var walls: Variant = m.get("walls", [])
	if not (walls is Array):
		out.append("map: walls must be an array")
	else:
		for i in (walls as Array).size():
			var r: Variant = walls[i]
			if not is_rect(r):
				out.append("map: walls[%d] must be [x0, z0, x1, z1]" % i)
				continue
			var rr := rect(r)
			if rr.size.x < 0.05 or rr.size.y < 0.05:
				out.append("map: walls[%d] has zero thickness" % i)
			if not _rect_inside(rr, w, h):
				out.append("map: walls[%d] %s extends outside the room" % [i, str(rr)])

	var props: Variant = m.get("props", [])
	if props is Array:
		for i in (props as Array).size():
			var p: Variant = props[i]
			if not (p is Dictionary):
				out.append("map: props[%d] must be a dictionary" % i)
				continue
			var pd: Dictionary = p
			if str(pd.get("id", "")).is_empty():
				out.append("map: props[%d] needs an id" % i)
			if not is_rect(pd.get("rect", null)):
				out.append("map: props[%d] needs a rect [x0, z0, x1, z1]" % i)
			if float(pd.get("height", 0.0)) <= 0.0:
				out.append("map: props[%d] needs a positive height" % i)

	var evidence: Variant = m.get("evidence", [])
	if not (evidence is Array) or (evidence as Array).is_empty():
		out.append("map: evidence must be a non-empty array")
	elif (evidence as Array).size() != 4:
		out.append("map: exactly four evidence items are expected, got %d" % (evidence as Array).size())
	else:
		var seen := {}
		for i in (evidence as Array).size():
			var e: Variant = evidence[i]
			if not (e is Dictionary):
				out.append("map: evidence[%d] must be a dictionary" % i)
				continue
			var ed: Dictionary = e
			var id := str(ed.get("id", ""))
			if id.is_empty():
				out.append("map: evidence[%d] needs an id" % i)
			elif seen.has(id):
				out.append("map: evidence id %s is duplicated" % id)
			seen[id] = true
			if not is_xy(ed.get("pos", null)):
				out.append("map: evidence %s needs a pos [x, z]" % id)
			elif not _inside(xy(ed["pos"]), w, h):
				out.append("map: evidence %s is outside the room" % id)

	var npcs: Variant = m.get("npcs", [])
	if not (npcs is Array) or (npcs as Array).is_empty():
		out.append("map: npcs must be a non-empty array")
	else:
		for i in (npcs as Array).size():
			var n: Variant = npcs[i]
			if not (n is Dictionary):
				out.append("map: npcs[%d] must be a dictionary" % i)
				continue
			var nd: Dictionary = n
			var id := str(nd.get("id", ""))
			if id.is_empty():
				out.append("map: npcs[%d] needs an id" % i)
			if float(nd.get("speed", 0.0)) <= 0.0:
				out.append("map: npc %s needs a positive speed" % id)
			var route: Variant = nd.get("route", [])
			if not (route is Array) or (route as Array).size() < 2:
				out.append("map: npc %s needs a route of at least two points" % id)
				continue
			for j in (route as Array).size():
				var pt: Variant = route[j]
				if not is_xy(pt):
					out.append("map: npc %s route[%d] must be [x, z]" % [id, j])
				elif not _inside(xy(pt), w, h):
					out.append("map: npc %s route[%d] is outside the room" % [id, j])

	var rz: Variant = m.get("report_zone", null)
	if not (rz is Dictionary):
		out.append("map: report_zone must be a dictionary")
	else:
		var rzd: Dictionary = rz
		if not is_xy(rzd.get("pos", null)):
			out.append("map: report_zone needs a pos [x, z]")
		elif not _inside(xy(rzd["pos"]), w, h):
			out.append("map: report_zone is outside the room")
		if float(rzd.get("radius", 0.0)) <= 0.0:
			out.append("map: report_zone needs a positive radius")

	return out


static func _inside(p: Vector2, w: float, h: float) -> bool:
	return p.x >= 0.0 and p.y >= 0.0 and p.x <= w and p.y <= h


static func _rect_inside(r: Rect2, w: float, h: float) -> bool:
	return r.position.x >= -0.001 and r.position.y >= -0.001 \
		and r.position.x + r.size.x <= w + 0.001 and r.position.y + r.size.y <= h + 0.001
