extends "res://tests/studiolot_walk.gd"
## Run only in a disposable project without the MCP autoload. Parent drives
## the real delivery and checks the projector against both recorded tracks.
var inspected := false
var finishing := false

func tap(code: int) -> void:
	if code == KEY_SPACE and lot.hatch_open:
		await super.tap(code)
		if not check(lot.hatch_open and lot.hatch_cam.current,"SPACE skipped the hatch"): return
		var tr = lot.hatch.cast.back().track
		var wraps := 0
		for i in 5000:
			var before: float = lot.hatch.clock
			await physics_frame
			if lot.hatch.clock < before: wraps += 1
			if wraps >= 2 and lot.hatch.clock > lot.hatch.period * 0.55: break
		if not check(wraps >= 2 and tr == root.get_node("GameSession").ghosts[0].track,"opening failed to hard-loop the real take"): return
		await cross_lip()
		return
	await super.tap(code)
	if code == KEY_SPACE and lot.screened and not finishing:
		# Parent expects to see replay just restarted after this call. Exercise
		# returning to shoot and locking first, then restart the final playback.
		finishing = true
		await super.tap(KEY_L)
		await super.tap(KEY_B)
		await live()
		if not check(not lot.screened and not lot.locked and lot.images.has("tank") and lot.gates.has("a"),"preview return lost pickups"): return
		await path([Vector2(7.25,31),Vector2(4,32.5)])
		await super.tap(KEY_E)
		await path([Vector2(7.25,31),Vector2(7.25,17),Vector2(8,17),Vector2(8,11.6),Vector2(12.5,11.6),Vector2(12.5,7.5)])
		await super.tap(KEY_E)
		await super.tap(KEY_ENTER)
		if not check(lot.screened and not lot.locked,"Enter alone locked picture"): return
		await super.tap(KEY_L)
		await super.tap(KEY_ENTER)
		await super.tap(KEY_B)
		if not check(lot.locked and lot.screened and inspected,"confirmed print was not final"): return
		print("HATCH_INPUT_LOOP_LAND_PREVIEW_RETURN_LOCK: true")
		await super.tap(KEY_SPACE)

func cross_lip() -> void:
	key(KEY_W,true)
	for i in 180:
		await physics_frame
		if lot.drop_elapsed >= 0: break
	key(KEY_W,false)
	if not check(lot.drop_elapsed >= 0,"walk failed to cross hatch lip"): return
	var falling := false
	for i in 90:
		await physics_frame
		falling = falling or lot.player.position.y < -0.4
		if not lot.hatch_open: break
	if not check(falling and not lot.hatch_open and not lot.player.frozen and lot.ghost_nodes.size()==1,"fall did not hand off to a live take"): return
	var g = lot.ghost_nodes[0]
	inspected = g.playhead > 0 and absf(g.playhead-lot.hatch.clock) < 0.06 and g.position.distance_to(g.track.sample_at(g.playhead).position)<0.05
	check(inspected,"landing discarded observed ghost phase")
