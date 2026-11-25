extends RefCounted
## The death card pays exactly once, and it gives the keyboard back.
##
## This is the regression test for the worst bug the relay has shipped with: a
## ghost standing on the checkpoint billed the player every frame while the slate
## was still up, which stacked respawns until ESC and WASD were both dead. The
## rules that stop it are: one death per card, hazards are not evaluated while the
## card is up, a respawn never lands inside the past, and the restore always hands
## the controls back.


const Save = preload("res://scripts/relay/relay_save.gd")
const RELAY := "res://scenes/relay/run.tscn"

## The board runs on wall-clock timers, so this needs real frames.
const BOARD_FRAMES := 400


static func run(h, tree = null) -> void:
	h.begin("relay_death")
	if tree == null:
		h.ok("a tree is available for the scene test", false)
		return

	var packed = load(RELAY)
	h.ok("relay scene loads", packed != null)
	if packed == null:
		return

	var inst: Node = (packed as PackedScene).instantiate()
	tree.root.add_child(inst)
	await tree.process_frame
	await tree.process_frame
	h.ok("relay scene instantiates", is_instance_valid(inst))
	if not is_instance_valid(inst):
		return

	# Novice rules: no cut desk, the card freezes you and puts you back.
	inst.set("difficulty", 0)
	inst.set("deaths", 0)

	# Three hits in three consecutive frames is what the old code saw when a
	# ghost was standing on the checkpoint. Only the first one is a death.
	inst.call("_hit", 0)
	inst.call("_hit", 0)
	inst.call("_hit", 0)
	h.eq("three contacts inside one card are one death", int(inst.get("deaths")), 1)
	h.ok("the guard holds while the card is up", bool(inst.get("_dying")))

	await _wait_for_card(inst, tree)
	h.ok("the card finishes instead of looping", not bool(inst.get("_dying")))
	var player = inst.get_node_or_null("Player")
	h.ok("the player node survives the death", player != null)
	if player != null:
		h.ok("the keyboard comes back after the card", not bool(player.get("frozen")))
		h.ok("the player is put back on the deck", player.global_position.y < 1.0)
	h.ok("a respawn carries grace", float(inst.get("grace")) > 0.0)

	# And the guard releases: once the card is gone the next contact is a real
	# death again, so the protection is per card and not per run.
	var before: int = int(inst.get("deaths"))
	inst.call("_hit", 0)
	h.eq("the next card may bill again", int(inst.get("deaths")), before + 1)
	await _wait_for_card(inst, tree)
	h.ok("the second card finishes before teardown", not bool(inst.get("_dying")))

	Save.clear()
	inst.queue_free()
	await tree.process_frame
	await tree.process_frame


static func _wait_for_card(inst: Node, tree: SceneTree) -> void:
	for frame in BOARD_FRAMES:
		if not bool(inst.get("_dying")):
			return
		await tree.process_frame
