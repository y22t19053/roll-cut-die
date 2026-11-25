extends Node2D
## Render the cutting desk phase to exercise all four live button slots.

class PreviewPad extends "res://scripts/relay/touch_pad.gd":
	func pad_preference() -> String:
		return "on"

	func _mode() -> int:
		return M_CUT


func _ready() -> void:
	RenderingServer.set_default_clear_color(PreviewPad.INK)
	add_child(PreviewPad.new())
	await get_tree().process_frame
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	for size_px: Vector2i in [Vector2i(640, 360), Vector2i(844, 390)]:
		DisplayServer.window_set_size(size_px)
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var frame := get_viewport().get_texture().get_image()
		var path := "res://visual/preview/sprint9_touch_%d.png" % size_px.x
		if frame.get_size() != size_px or frame.save_png(path) != OK:
			push_error("Failed capture for %s (window %s, image %s)" % [size_px, get_window().size, frame.get_size()])
			get_tree().quit(1)
			return
	get_tree().quit()
