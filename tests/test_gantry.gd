extends RefCounted
## Sprint 5 item 4 asks one question about the Free-Blocking candidate: does a set
## with decks at two heights survive the parts of Relay that assume a flat floor —
## vertical walking, history ghosts, and the existing entry seam?
##
## This checks the shape of the answer in geometry, not a scripted playthrough:
## the player's own capsule has to fit on the ground deck, under the bridge, on
## the bridge, and up the whole ramp in between. Decision C-03 keeps Studio
## Blocking a separate mode, so nothing here mounts the gantry into a Relay bay.

const Gantry = preload("res://scripts/relay/h_gantry.gd")
const Track = preload("res://scripts/ghost/ghost_track.gd")

const BRIDGE_TOP := 2.5
const RAMP_RUN := 5.0
const RAMP_EDGE_Z := 1.05
const EYE_OFFSET := 0.85


static func run(h, tree = null) -> void:
	h.begin("gantry")
	if tree == null:
		h.ok("a tree is available for the gantry check", false)
		return

	var world := Node3D.new()
	tree.root.add_child(world)
	var parts := Gantry.build(world)
	h.ok("gantry builds", parts.has("stations") and parts.has("spawn"))
	await tree.physics_frame
	await tree.physics_frame

	var space := world.get_world_3d().direct_space_state
	var cap := CapsuleShape3D.new()
	cap.radius = 0.32
	cap.height = 1.0
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = cap
	params.collision_mask = 1

	h.ok("ground deck holds a player at the spawn",
		_free_at(space, params, Vector3(5.0, EYE_OFFSET, 7.2)))
	h.ok("bridge deck holds a player at its height",
		_free_at(space, params, Vector3(0.0, BRIDGE_TOP + EYE_OFFSET, 0.0)))
	h.ok("the clearance under the bridge is walkable",
		_free_at(space, params, Vector3(0.0, EYE_OFFSET, 0.0)))

	# A ramp you cannot walk is a wall with extra polygons: every metre of the run
	# has to hold the capsule at the height the surface is actually at.
	var blocked := 0
	for i in 12:
		var t := float(i) / 11.0
		var z := RAMP_EDGE_Z + RAMP_RUN * t
		var y := BRIDGE_TOP * (1.0 - t) + EYE_OFFSET
		if not _free_at(space, params, Vector3(5.0, y, z)):
			blocked += 1
	h.eq("the east ramp holds the player the whole way up", blocked, 0)

	# A probe that fits is not a body that climbs. Walk a real CharacterBody3D up the
	# ramp the way player.gd does when vertical_walk is on, and require it to arrive
	# on the bridge rather than sliding back down.
	var body := CharacterBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = cap
	body.add_child(shape)
	body.floor_max_angle = deg_to_rad(50.0)
	world.add_child(body)
	body.global_position = Vector3(5.0, 0.55, RAMP_EDGE_Z + RAMP_RUN + 0.2)
	var arrived := false
	var frames := 0
	var vy := 0.0
	for f in 400:
		frames = f + 1
		vy = maxf(vy - 19.6 / 60.0, -24.0)
		body.velocity = Vector3(0.0, vy, -3.2)
		body.move_and_slide()
		if body.is_on_floor():
			vy = 0.0
		if body.global_position.y >= BRIDGE_TOP - 0.05:
			arrived = true
			break
		await tree.physics_frame
	h.ok("a body climbs the ramp to the bridge", arrived)
	h.note("climb ended at y=%.2f z=%.2f after %d frames"
		% [body.global_position.y, body.global_position.z, frames])
	body.queue_free()

	# History is recorded in world coordinates, so a take walked on the bridge has
	# to replay at bridge height rather than snapping down to the floor.
	var tr := Track.new()
	tr.take_id = 7
	for i in 5:
		tr.add_sample(float(i) * 0.25, Vector3(-3.0 + float(i), BRIDGE_TOP, 0.0), 0.0, 0.0, 0.0)
	h.eq("a bridge take keeps one sample per frame", tr.size(), 5)
	h.near("a bridge take replays at bridge height", tr.sample_at(0.5).position.y, BRIDGE_TOP, 0.01)
	h.near("a bridge take keeps its recorded heading", tr.sample_at(0.5).position.x, -1.0, 0.05)

	# Building twice must not depend on leftover state: the sets are procedural, and
	# a second gantry has to come out the same size as the first.
	var again := Node3D.new()
	tree.root.add_child(again)
	var second := Gantry.build(again)
	h.eq("a second gantry reports the same three stations",
		(second["stations"] as PackedVector3Array).size(), 3)
	h.eq("a second gantry leaves the first one alone", parts["stations"], second["stations"])

	again.queue_free()
	world.queue_free()
	await tree.process_frame


static func _free_at(space, params: PhysicsShapeQueryParameters3D, at: Vector3) -> bool:
	params.transform = Transform3D(Basis(), at)
	return space.intersect_shape(params, 1).is_empty()
