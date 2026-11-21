extends Node3D
## NpcPatrol — a stage worker walking a fixed route on a fixed clock.
##
## Deterministic by construction: position is a pure function of elapsed
## physics time and arc length walked, never of the player's location. The same
## route and the same speed always put the NPC in the same place at the same
## second, which is what makes the level learnable and what makes the route
## feasibility test meaningful.

const Logger = preload("res://scripts/core/logger.gd")

signal caught_player(npc_id: String)

## Danger radius. Slightly larger than the visual shell so contact registers at
## the visible edge, never inside it.
const DANGER_RADIUS := 0.45
const BODY_RADIUS := 0.42
const BODY_HEIGHT := 1.75
const TURN_RATE := 9.0

var npc_id := ""
var display_name := "":
	set(value):
		display_name = value
		if is_node_ready():
			get_node("Tag").text = value
var route: PackedVector3Array = PackedVector3Array()
var speed := 1.0
var dwell_s := 0.0
var mode := "loop"  # "loop" | "pingpong"

## Monotonic arc length walked since spawn. A determinism probe: two runs of the
## same length must agree to the millimetre.
var traveled := 0.0

var facing := 0.0

var _leg := 0
var _dir := 1
var _dist := 0.0
var _dwell_left := 0.0
var _active := true

var _visual: Node3D
var _danger: Area3D


func setup(id: String, label: String, pts: PackedVector3Array, spd: float, dw: float = 0.0, md: String = "loop") -> void:
	npc_id = id
	display_name = label
	route = pts
	speed = maxf(spd, 0.01)
	dwell_s = maxf(dw, 0.0)
	mode = md
	_leg = 0
	_dir = 1
	_dist = 0.0
	_dwell_left = 0.0
	traveled = 0.0
	if route.size() > 0:
		global_position = route[0]
		facing = _leg_facing()


func _ready() -> void:
	_build()


func _build() -> void:
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)

	var mesh := MeshInstance3D.new()
	mesh.name = "Body"
	var cm := CapsuleMesh.new()
	cm.radius = BODY_RADIUS
	cm.height = BODY_HEIGHT
	cm.radial_segments = 14
	cm.rings = 5
	mesh.mesh = cm
	mesh.position = Vector3(0.0, BODY_HEIGHT * 0.5, 0.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = _tint()
	mat.roughness = 0.7
	mesh.material_override = mat
	_visual.add_child(mesh)

	var head := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.16
	sm.height = 0.32
	head.mesh = sm
	head.position = Vector3(0.0, BODY_HEIGHT - 0.05, 0.0)
	var hm := StandardMaterial3D.new()
	hm.albedo_color = _tint().lightened(0.15)
	head.material_override = hm
	_visual.add_child(head)

	var tag := Label3D.new()
	tag.name = "Tag"
	tag.text = display_name
	tag.font_size = 48
	tag.pixel_size = 0.006
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.no_depth_test = false
	tag.modulate = Color(1, 1, 1, 0.85)
	tag.outline_size = 8
	tag.outline_modulate = Color(0, 0, 0, 0.8)
	tag.position = Vector3(0.0, BODY_HEIGHT + 0.32, 0.0)
	add_child(tag)

	# Layer 20 holds live actors; the historical camera renders stills instead.
	for part in [mesh, head, tag]:
		part.layers = 1 << 19
	_danger = Area3D.new()
	_danger.name = "Danger"
	_danger.collision_layer = 4
	_danger.collision_mask = 2  # the player body layer
	_danger.monitoring = true
	_danger.monitorable = false
	var dc := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = DANGER_RADIUS
	cyl.height = BODY_HEIGHT
	dc.shape = cyl
	dc.position = Vector3(0.0, BODY_HEIGHT * 0.5, 0.0)
	_danger.add_child(dc)
	add_child(_danger)
	_danger.body_entered.connect(_on_body_entered)


func still_frame() -> Dictionary:
	return {"pose": global_transform, "visual_pose": _visual.transform, "name": display_name}

func mark_phase() -> Dictionary:
	return {"leg": _leg, "dir": _dir, "dist": _dist, "dwell": _dwell_left,
		"traveled": traveled, "facing": facing, "position": global_position}

func restore_phase(p: Dictionary) -> void:
	_leg = p.leg
	_dir = p.dir
	_dist = p.dist
	_dwell_left = p.dwell
	traveled = p.traveled
	facing = p.facing
	global_position = p.position
	_visual.rotation.y = facing

func make_still(frame: Dictionary) -> Node3D:
	var still := Node3D.new()
	var visual := _visual.duplicate(0) as Node3D
	visual.transform = frame.visual_pose
	for mesh in visual.find_children("*", "MeshInstance3D", true, false):
		mesh.layers = 1
	still.add_child(visual)
	var tag := get_node("Tag").duplicate(0) as Label3D
	tag.layers = 1
	tag.text = frame.name
	still.add_child(tag)
	return still

func _tint() -> Color:
	match npc_id:
		"director":
			return Color(0.42, 0.16, 0.18)
		"stagehand":
			return Color(0.20, 0.28, 0.38)
		_:
			return Color(0.3, 0.3, 0.3)


func _on_body_entered(body: Node3D) -> void:
	if not _active:
		return
	if body is CharacterBody3D and body.get("frozen") != null:
		caught_player.emit(npc_id)


func set_active(v: bool) -> void:
	_active = v
	if _danger != null:
		_danger.monitoring = v


func is_active() -> bool:
	return _active


## Put the NPC back at the top of its route.
##
## Every take starts on the same second of the same loop. Without this the
## level would be unlearnable and the route proof in tests/test_routes.gd would
## be describing a different game than the one being played.
func reset_phase() -> void:
	_leg = 0
	_dir = 1
	_dist = 0.0
	_dwell_left = 0.0
	traveled = 0.0
	if route.size() > 0:
		global_position = route[0]
		facing = _leg_facing()
		if _visual != null:
			_visual.rotation.y = facing


func _next_index() -> int:
	if mode == "pingpong":
		var n := _leg + _dir
		if n < 0:
			return 0
		if n >= route.size():
			return route.size() - 1
		return n
	return (_leg + 1) % maxi(route.size(), 1)


func _leg_facing() -> float:
	if route.size() < 2:
		return facing
	var a: Vector3 = route[_leg]
	var b: Vector3 = route[_next_index()]
	var d := b - a
	if d.length_squared() <= 0.000001:
		return facing
	return atan2(-d.x, -d.z)


func _advance_leg() -> void:
	if route.size() < 2:
		return
	if mode == "pingpong":
		var n := _leg + _dir
		if n < 0 or n >= route.size():
			_dir = -_dir
			n = _leg + _dir
		_leg = clampi(n, 0, route.size() - 1)
	else:
		_leg = (_leg + 1) % route.size()


func _physics_process(dt: float) -> void:
	if not _active or route.size() < 2:
		return
	if _dwell_left > 0.0:
		_dwell_left = maxf(0.0, _dwell_left - dt)
		_pose()
		return

	var budget := speed * dt
	var guard := 0
	while budget > 0.0 and guard < 32:
		guard += 1
		var a: Vector3 = route[_leg]
		var b: Vector3 = route[_next_index()]
		var leg_len := maxf(a.distance_to(b), 0.0001)
		var need := leg_len - _dist
		if budget < need:
			_dist += budget
			traveled += budget
			budget = 0.0
		else:
			traveled += need
			budget -= need
			_dist = 0.0
			_advance_leg()
			if dwell_s > 0.0:
				_dwell_left = dwell_s
				budget = 0.0
	_pose()


func _pose() -> void:
	if route.size() < 2:
		return
	var a: Vector3 = route[_leg]
	var b: Vector3 = route[_next_index()]
	var leg_len := maxf(a.distance_to(b), 0.0001)
	global_position = a.lerp(b, clampf(_dist / leg_len, 0.0, 1.0))
	var want := atan2(-(b - a).x, -(b - a).z)
	facing = lerp_angle(facing, want, 0.35)
	if _visual != null:
		_visual.rotation.y = facing


## Pure oracle: where the NPC is after `seconds` of a fresh run.
##
## Built as an analytic timeline — walk and dwell segments with their durations,
## then one modulo — because the route proof asks this question a hundred
## thousand times and a stepping simulation cannot answer it. The semantics are
## exactly those of _physics_process above: walk a leg, dwell at the end of it,
## and for pingpong turn round at the last point.
static func build_timeline(pts: PackedVector3Array, spd: float, dw: float, md: String) -> Dictionary:
	var segs: Array = []
	var n := pts.size()
	if n < 2:
		return {"segs": segs, "cycle": 0.0, "length": 0.0}
	var sp := maxf(spd, 0.01)
	if md == "pingpong":
		for i in range(0, n - 1):
			segs.append({"a": pts[i], "b": pts[i + 1], "dur": pts[i].distance_to(pts[i + 1]) / sp})
			if dw > 0.0:
				segs.append({"a": pts[i + 1], "b": pts[i + 1], "dur": dw})
		for i in range(n - 1, 0, -1):
			segs.append({"a": pts[i], "b": pts[i - 1], "dur": pts[i].distance_to(pts[i - 1]) / sp})
			if dw > 0.0:
				segs.append({"a": pts[i - 1], "b": pts[i - 1], "dur": dw})
	else:
		for i in n:
			var a: Vector3 = pts[i]
			var b: Vector3 = pts[(i + 1) % n]
			segs.append({"a": a, "b": b, "dur": a.distance_to(b) / sp})
			if dw > 0.0:
				segs.append({"a": b, "b": b, "dur": dw})
	var cycle := 0.0
	var length := 0.0
	for s: Dictionary in segs:
		cycle += float(s["dur"])
		length += (s["a"] as Vector3).distance_to(s["b"] as Vector3)
	return {"segs": segs, "cycle": cycle, "length": length}


static func state_from_timeline(tl: Dictionary, seconds: float) -> Dictionary:
	var segs: Array = tl["segs"]
	if segs.is_empty():
		return {"pos": Vector3.ZERO, "traveled": 0.0, "leg": 0}
	var cycle := float(tl["cycle"])
	var t := seconds
	var walked := 0.0
	if cycle > 0.0 and seconds > 0.0:
		var laps := floorf(seconds / cycle)
		t = seconds - laps * cycle
		walked = laps * float(tl["length"])
	if seconds <= 0.0:
		return {"pos": segs[0]["a"], "traveled": 0.0, "leg": 0}
	var pos: Vector3 = segs[0]["a"]
	var leg := 0
	for i in segs.size():
		var s: Dictionary = segs[i]
		var d := float(s["dur"])
		var a: Vector3 = s["a"]
		var b: Vector3 = s["b"]
		leg = i
		# Strict comparison: at exactly the end of a leg the walker has already
		# arrived and stepped onto the next one (that is what _physics_process
		# does when its budget lands on zero), so the boundary belongs to the
		# outgoing leg. `<=` here would report the previous leg while the
		# position already sits on the corner.
		if t < d:
			if d > 0.0:
				pos = a.lerp(b, clampf(t / d, 0.0, 1.0))
				walked += a.distance_to(pos)
			else:
				pos = b
			return {"pos": pos, "traveled": walked, "leg": leg}
		t -= d
		walked += a.distance_to(b)
		pos = b
	return {"pos": pos, "traveled": walked, "leg": leg}


static func pose_at(pts: PackedVector3Array, spd: float, dw: float, md: String, seconds: float) -> Vector3:
	return state_from_timeline(build_timeline(pts, spd, dw, md), seconds)["pos"]


static func state_at(pts: PackedVector3Array, spd: float, dw: float, md: String, seconds: float) -> Dictionary:
	return state_from_timeline(build_timeline(pts, spd, dw, md), seconds)
