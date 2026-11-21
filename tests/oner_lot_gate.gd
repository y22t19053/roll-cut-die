extends SceneTree
# Integration fixture: place the actor beside the entrance, exercise E/Q only.
func _initialize(): call_deferred("run")
func press(k: int):
	for down in [true,false]:
		var e := InputEventKey.new()
		e.physical_keycode = k
		e.keycode = k
		e.pressed = down
		Input.parse_input_event(e)
		Input.flush_buffered_events()
		await physics_frame
func run():
	create_timer(9).timeout.connect(func(): quit(3))
	change_scene_to_file("res://scenes/studiolot/world.tscn")
	await scene_changed_signal_compat()
	var lot = current_scene
	while lot.player.frozen: await physics_frame
	lot.player.teleport(lot.ONER_DOOR,0)
	await physics_frame
	await press(KEY_E)
	if not lot.on_soundstage or not lot.oner.active: quit(1); return
	var t: float = lot._world_t
	for i in 30: await physics_frame
	if lot._world_t != t or lot.recorder.recording: quit(1); return
	await press(KEY_Q)
	if lot.on_soundstage or lot.oner.active or lot.oner_print or lot.player.position.distance_to(lot.ONER_DOOR)>0.15 or not lot.recorder.recording: quit(1); return
	print("ONER_LOT_GATE_OK: E enters, outside clock and recording held, Q returns without bonus")
	quit(0)
func scene_changed_signal_compat():
	while current_scene == null: await process_frame
