extends RefCounted
## Choose the nearest clear studio entrance, not a new invulnerability rule.
## Only the opening five seconds are reserved; later crossings are still lethal.
const Spec = preload("res://scripts/world/room_spec.gd")
const OPENING := 5.0
const CLEARANCE := 1.4 # metres, exceeds player + either danger radius and leaves a step
const WALL_MARGIN := 0.48 # player capsule radius 0.32 plus elbow room

static func choose(map: Dictionary, home: Vector3, ghosts: Array) -> Variant:
	if ghosts.is_empty(): return home
	var obstacles: Array[Rect2] = []
	for wall in map.walls:
		obstacles.append(Spec.rect(wall).grow(WALL_MARGIN))
	for prop in map.props:
		if prop.get("solid",true): obstacles.append(Spec.rect(prop.rect).grow(WALL_MARGIN))
	var segments := PackedVector2Array()
	for item in ghosts:
		var track = item.track
		if not track or not track.size(): continue
		var previous := _xz(track.sample_at(0).position)
		# Follow the actual interpolation knots (including off-grid interactions).
		for i in range(1,track.size()):
			var t: float = track.dequant_time(track.times[i])
			var pos := _xz(track.sample_at(minf(t,OPENING)).position)
			segments.append(previous)
			segments.append(pos)
			previous = pos
			if t >= OPENING: break
	for npc in map.npcs:
		for i in range(1,npc.route.size()):
			segments.append(Spec.xy(npc.route[i-1]))
			segments.append(Spec.xy(npc.route[i]))
		if npc.get("mode","loop") == "loop":
			segments.append(Spec.xy(npc.route.back()))
			segments.append(Spec.xy(npc.route.front()))
	var origin := _xz(home)
	var candidates: Array[Vector2] = [origin]
	for x in range(1,int(map.size[0])):
		for z in range(1,int(map.size[1])):
			candidates.append(Vector2(x,z))
	candidates.sort_custom(func(a: Vector2,b: Vector2) -> bool: return a.distance_squared_to(origin) < b.distance_squared_to(origin))
	for p in candidates:
		if _clear(p, obstacles, segments): return Vector3(p.x,home.y,p.y)
	return null # Exhausted set: never substitute a point we just rejected.

static func _clear(p: Vector2, obstacles: Array[Rect2], segments: PackedVector2Array) -> bool:
	for box in obstacles:
		if box.has_point(p): return false
	for i in range(0,segments.size(),2):
		var a := segments[i]
		var d := segments[i+1]-a
		var nearest := a if d.is_zero_approx() else a+d*clampf((p-a).dot(d)/d.length_squared(),0,1)
		if p.distance_squared_to(nearest) < CLEARANCE*CLEARANCE: return false
	return true

static func _xz(p: Vector3) -> Vector2:
	return Vector2(p.x,p.z)
