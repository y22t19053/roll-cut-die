extends RefCounted
## Integration: the real scene, actually built, actually ticking.
##
## This is the test that catches "the game does not start". It is deliberately
## shallow about behaviour: L0/L1/L2 tests own the rules, this one owns the
## wiring — nodes exist, the slate runs, the player is released onto the floor.

const SlateUi = preload("res://scripts/ui/slate_ui.gd")


static func run(h, tree = null) -> void:
	h.begin("scene")

	var packed = load("res://scenes/main/main.tscn")
	h.ok("main scene loads", packed != null)
	if packed == null:
		return

	var inst: Node = (packed as PackedScene).instantiate()
	tree.root.add_child(inst)
	h.ok("scene instantiates", inst != null)
	if inst == null:
		return

	# The scene builds its world in _ready, which has already run by now.
	h.ok("player exists", inst.get_node_or_null("Player") != null)
	h.ok("camera rig exists", inst.get_node_or_null("CameraRig") != null)
	h.ok("hud exists", inst.get_node_or_null("Hud") != null)
	h.ok("slate exists", inst.get_node_or_null("Slate") != null)
	h.ok("recorder exists", inst.get_node_or_null("GhostRecorder") != null)

	var npcs := 0
	var evidence := 0
	for child: Node in inst.get_children():
		if child.get_script() != null:
			var path := str(child.get_script().resource_path)
			if path.ends_with("npc_patrol.gd"):
				npcs += 1
			elif path.ends_with("evidence_prop.gd"):
				evidence += 1
	h.eq("two npcs in the room", npcs, 2)
	h.eq("four evidence props in the room", evidence, 4)

	var player: Node = inst.get_node_or_null("Player")
	h.ok("player is frozen while the slate rolls", bool(player.get("frozen")))
	h.ok("no ghosts on take 1", (inst.get("ghost_nodes") as Array).size() == 0)

	# The slate runs on wall-clock timers, so let real frames pass. 240 frames
	# of headless idle is plenty for the 1.95 s ROLL sequence.
	var frames := 0
	while frames < 400 and bool(player.get("frozen")):
		await tree.process_frame
		frames += 1
	h.ok("player is released after ROLL", not bool(player.get("frozen")))
	h.note("released after %d frames" % frames)

	# The rig must have followed the player and be pointing at the room.
	var rig: Node = inst.get_node_or_null("CameraRig")
	var cam: Camera3D = rig.get("camera")
	h.ok("camera exists", cam != null)
	if cam != null:
		h.ok("camera is current", cam.current)
		var target: Node3D = rig.get("target")
		h.at_most("camera sits at the rig distance",
			absf(rig.global_position.distance_to(target.global_position) - 1.0), 0.05)

	var phase: int = int(inst.get("phase"))
	h.eq("take is rolling", phase, 0)

	inst.queue_free()
	await tree.process_frame
