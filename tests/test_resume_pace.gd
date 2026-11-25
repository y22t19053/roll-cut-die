extends RefCounted

## A save only stores which rooms a run has; it does not store their clock. When a
## run is rebuilt from a save the rooms are built again from scratch, so anything the
## builder scaled by difficulty has to be scaled again on the way back in. Codex J
## put the pace on the fresh leg and left this path at the default, which made a
## resumed EXPERT run quietly easier than the run that was saved.

const Harness = preload("res://tests/harness.gd")
const RelaySave = preload("res://scripts/relay/relay_save.gd")

## The scene opens a run of its own before any save is applied, so room 0 always
## belongs to that opening set and the rooms rebuilt from the save start at 1.
const BOOT_ROOMS := 1


static func run(h: Harness, tree: SceneTree = null) -> void:
	h.begin("resume_pace")
	var packed := load("res://scenes/relay/run.tscn") as PackedScene
	h.ok("relay run scene loads", packed != null)
	if packed == null:
		h.finish()
		return
	var prior_save := RelaySave.save_path
	RelaySave.save_path = "user://rcd_test_saves/resume_pace_%s.json" % Crypto.new().generate_random_bytes(8).hex_encode()

	var slice: Array = [
		{"kind": "straight", "variant": 0, "mod": "", "final": false, "event": ""},
		{"kind": "straight", "variant": 1, "mod": "", "final": false, "event": ""},
	]
	var novice: Variant = await _rebuilt(h, tree, packed, slice, 0, "novice")
	var expert: Variant = await _rebuilt(h, tree, packed, slice, 1, "expert")
	if novice != null and expert != null:
		var slow := _period(novice, BOOT_ROOMS)
		var fast := _period(expert, BOOT_ROOMS)
		h.ok("both loads put a dolly on the track", slow > 0.0 and fast > 0.0)
		# EXPERT shortens the mechanism period by ~8%; anything less means the
		# rebuilt room came back at the NOVICE clock.
		h.at_most("a resumed EXPERT run keeps the speed it was saved at", fast, slow * 0.95)

	RelaySave.save_path = prior_save
	tree.paused = false
	h.finish()


static func _rebuilt(h: Harness, tree: SceneTree, packed: PackedScene, slice: Array,
		mode: int, tag: String) -> Variant:
	var inst: Variant = packed.instantiate()
	tree.root.add_child(inst)
	await tree.process_frame
	await tree.process_frame
	inst.call("_apply_run", {"difficulty": mode, "segments": slice, "deaths": 0})
	await tree.process_frame
	var built: int = (inst.segments as Array).size() - BOOT_ROOMS
	h.eq("%s: the save rebuilt every room" % tag, built, slice.size())
	return inst


static func _period(inst: Variant, room_index: int) -> float:
	# Rooms keeps one dolly list per room; a room's clock is stored as a period in
	# seconds divided by hurry, so a smaller period is a faster dolly.
	var by_room: Array = inst.get_node("Rooms").get("_dollies")
	if room_index >= by_room.size():
		return 0.0
	for d: Dictionary in by_room[room_index]:
		return float(d.get("period", 0.0))
	return 0.0
