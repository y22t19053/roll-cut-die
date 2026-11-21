extends Node3D
## Eight continuous passes of a fixed stage. All tracks use world coordinates.
## The owner suspends its campaign clock/interactions while active. Do not pause
## the tree: its normal player controller and follow camera are used unchanged.
signal leg_banked(number: int)
signal leg_failed(number: int)
signal near_miss(take: int)
signal completed()
const Track = preload("res://scripts/ghost/ghost_track.gd")
const LAST := 8
const LINE := 6.25
const APRON := 5.45 # hatched turning boxes at each end; ghosts are light here
const HIT := 0.64 # sum of two 0.32 m capsule radii
const NEAR := 1.08
var active := false
var leg := 1
var tracks: Array = []
var clock := 0.0
var _actor
var _rig
var _record
var _origin: Vector3
var _face := 0.0
var _bodies := []
var _close := {}
var _last_pos: Vector3
var _last_emit := 0.0
var _decor: Node3D
var _targets: Array = []

func _box(at: Vector3, size: Vector3, ink: Color, solid := true) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var box := MeshInstance3D.new()
	box.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = ink
	box.material_override = mat
	box.position = at
	add_child(box)
	if solid:
		var b := StaticBody3D.new()
		var c := CollisionShape3D.new()
		var s := BoxShape3D.new()
		s.size = size
		c.shape = s
		box.add_child(b)
		b.add_child(c)
	return box

func _ready() -> void:
	process_physics_priority = 5 # observe after the player moves
	_box(Vector3(0,-0.16,0),Vector3(15.6,0.32,7.2),Color("393944"))
	for side in [-1,1]:
		_box(Vector3(0,0.6,side*3.45),Vector3(15.6,1.2,0.3),Color("584f43"))
		_box(Vector3(side*7.65,0.6,0),Vector3(0.3,1.2,6.6),Color("584f43"))
		_box(Vector3(side*APRON,0.012,0),Vector3(0.06,0.02,6.6),Color("bca770"),false)
		_targets.append(_box(Vector3(side*LINE,0.018,0),Vector3(0.11,0.025,6.6),Color.WHITE,false))
	_box(Vector3(0,0.7,0),Vector3(4,1.4,1.4),Color("665950"))
	var path := "res://scripts/studiolot/oner_set.gd"
	if ResourceLoader.exists(path):
		_decor = load(path).new()
		add_child(_decor)

func start(player,rig) -> bool:
	if active or not is_instance_valid(player) or not is_instance_valid(rig): return false
	_actor = player
	_rig = rig
	for b in _bodies: b.queue_free()
	_bodies.clear()
	tracks.clear()
	leg = 1
	active = true
	_actor.teleport(to_global(Vector3(-6.5,0.05,0)), -PI/2)
	_actor.set_frozen(false)
	_begin()
	return true

## Q/scene exit: abandon this challenge only; owner restores campaign position.
func abort() -> void:
	active = false
	_close.clear()
	for b in _bodies: b.hide()

func _begin() -> void:
	_origin = _actor.global_position
	_face = _actor.facing
	_last_pos = _origin
	_last_emit = 0
	clock = 0
	_close.clear()
	_record = Track.new()
	_record.take_id = leg
	_sample()
	for i in tracks.size(): _pose(i,0)
	for i in 2:
		_targets[i].material_override.albedo_color = Color("eacd6c") if i == leg%2 else Color("514c48")
	if _decor and _decor.has_method("set_direction"): _decor.call("set_direction",leg%2 == 1)

func _sample() -> void:
	_record.add_sample(clock,_actor.global_position,_actor.facing,_rig.yaw,_rig.roll)
	_last_emit = clock

func _body(id: int) -> Node3D:
	var m := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.32
	cap.height = 1.7
	m.mesh = cap
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color.from_hsv(fmod(0.52 + 0.12*id,1.0),0.62,0.9,0.68)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.material_override = mat
	add_child(m)
	return m

func _pose(i: int,t: float) -> Vector3:
	var tr = tracks[i]
	var pose: Dictionary = tr.sample_at(fmod(t,tr.duration()))
	_bodies[i].global_position = pose.position + Vector3.UP*0.85
	_bodies[i].rotation.y = pose.facing
	return pose.position

func _retry() -> void:
	_actor.teleport(_origin,_face)
	_begin()
	leg_failed.emit(leg)

func _physics_process(dt: float) -> void:
	if not active: return
	var prev := clock
	clock += dt
	var at: Vector3 = _actor.global_position
	var p := to_local(at)
	if absf(p.z)>3.31 or absf(p.x)>7.51 or absf(p.y)>0.35:
		_retry(); return
	var cleared := []
	for i in tracks.size():
		var prev_ghost: Vector3 = _bodies[i].global_position - Vector3.UP*0.85
		var ghost := _pose(i,clock)
		var dur: float = tracks[i].duration()
		var wrap := floori(clock/dur) != floori(prev/dur)
		var inside := absf(p.x)<APRON and absf(to_local(ghost).x)<APRON
		if not inside or wrap:
			_close.erase(i)
			continue
		# Continuous relative motion avoids skipping collisions between ticks.
		var a := _last_pos-prev_ghost
		var b := at-ghost
		var v := b-a
		var t := clampf(-a.dot(v)/maxf(v.length_squared(),0.000001),0,1)
		var separation := (a+t*v).length()
		if separation <= HIT:
			_retry(); return
		if separation <= NEAR: _close[i] = true
		if _close.has(i) and b.length()>NEAR+0.10:
			_close.erase(i)
			cleared.append(i+1)
	for id in cleared: near_miss.emit(id)
	_last_pos = at
	var bank := p.x >= LINE if leg%2==1 else p.x <= -LINE
	if clock-_last_emit >= 0.095 or bank: _sample()
	if not bank: return
	tracks.append(_record)
	_bodies.append(_body(leg))
	_pose(leg-1,clock)
	leg_banked.emit(leg)
	if leg==LAST:
		active = false
		completed.emit()
		return
	leg += 1
	_begin() # No slate, teleport, frozen frame or input reset on success.
