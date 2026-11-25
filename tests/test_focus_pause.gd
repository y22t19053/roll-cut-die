extends RefCounted

const Harness = preload("res://tests/harness.gd")
const RelaySave = preload("res://scripts/relay/relay_save.gd")


static func run(h: Harness, tree: SceneTree = null) -> void:
	h.begin("focus_pause")
	var session: Variant = tree.root.get_node("GameSession")
	var events: Array[String] = []
	var record_loss := func() -> void: events.append("lost")
	var record_gain := func() -> void: events.append("gained")
	session.focus_lost.connect(record_loss)
	session.focus_gained.connect(record_gain)
	session.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	h.eq("application focus out emits focus_lost", events, ["lost"])
	session.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	h.eq("application focus in emits focus_gained", events, ["lost", "gained"])
	session.focus_lost.disconnect(record_loss)
	session.focus_gained.disconnect(record_gain)

	var packed := load("res://scenes/relay/run.tscn") as PackedScene
	h.ok("relay run scene loads", packed != null)
	if packed != null:
		await _run_focus(h, tree, session, packed)
	tree.paused = false
	h.finish()


static func _run_focus(h: Harness, tree: SceneTree, session: Node, packed: PackedScene) -> void:
	# A fresh run clears its save path, including when run through only.gd.
	var prior_save := RelaySave.save_path
	RelaySave.save_path = "user://rcd_test_saves/focus_pause_%s.json" % Crypto.new().generate_random_bytes(8).hex_encode()
	var inst: Variant = packed.instantiate()
	tree.root.add_child(inst)
	await tree.process_frame
	await tree.process_frame

	for mode: int in [inst.Mode.PICK, inst.Mode.CUT, inst.Mode.DONE, inst.Mode.LOST, inst.Mode.ITEM, inst.Mode.ACT]:
		inst.phase = mode
		session.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
		h.ok("focus loss leaves %s running" % inst.Mode.keys()[mode], not tree.paused and not inst.paused)
	inst.phase = inst.Mode.PLAY
	inst._dying = true
	session.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	h.ok("focus loss leaves the death sequence running", not tree.paused and not inst.paused)
	inst._dying = false

	session.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	h.ok("losing focus in PLAY pauses the tree", tree.paused)
	h.ok("losing focus in PLAY opens the pause menu", inst.paused)
	session.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	h.ok("repeated focus loss keeps the run paused", tree.paused and inst.paused)
	session.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	h.ok("gaining focus keeps the run paused", tree.paused and inst.paused)

	tree.paused = false
	session.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	h.ok("focus gain leaves the tree flag false and the menu open", not tree.paused and inst.paused)
	inst.pause_ui._resume()
	session.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	h.ok("the player can resume and stay in play", not tree.paused and not inst.paused)

	inst._notice_left = 2.0
	inst._physics_process(1.0)
	h.near("a one-second tick uses 50 ms of notice time", inst._notice_left, 1.95)

	tree.paused = false
	inst.queue_free()
	await tree.process_frame
	await tree.process_frame
	RelaySave.save_path = prior_save
