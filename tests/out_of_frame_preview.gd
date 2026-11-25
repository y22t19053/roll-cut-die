extends Node
## Windowed evidence from the real run and controller; never used by the test suite.
func _ready() -> void:
	var run = load("res://scenes/relay/run.tscn").instantiate()
	add_child(run)
	await get_tree().process_frame
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	get_window().size = Vector2i(1920,1080)
	get_window().content_scale_size = Vector2i(1600,900)
	await get_tree().process_frame
	run.process_mode = Node.PROCESS_MODE_DISABLED
	run._prologue = 1
	run.slate.hide_slate()
	run._dying = false
	run.phase = run.Mode.PLAY
	run.player.set_frozen(false)
	var frame = run.out_of_frame
	for i in 3: frame.note_ng()
	frame.advance(0.35)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://visual/preview/sprint6_out_of_frame_warn.png")
	frame.advance(2.15)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://visual/preview/sprint6_out_of_frame_out.png")
	run.queue_free()
	await get_tree().process_frame
	get_tree().quit()
