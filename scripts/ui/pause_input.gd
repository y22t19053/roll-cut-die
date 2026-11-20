extends Node
## Only the resume key remains active while the gameplay tree is paused.
signal resume_requested

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		resume_requested.emit()
