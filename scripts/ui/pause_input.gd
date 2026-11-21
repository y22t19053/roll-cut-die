extends Node
## The only gameplay keys that stay live while the tree is paused: ESC (back /
## resume) and F2 (language). Everything else waits for the take to resume.
signal resume_requested
signal language_requested

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			resume_requested.emit()
		KEY_F2:
			get_viewport().set_input_as_handled()
			language_requested.emit()
