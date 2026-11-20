extends "res://tools/junction_lab.gd"
## Single variable: after a successful report the same set is filmed in reverse.
## CUT and DIE do not count as successes. Never mirror the recorded track.
const SOUTH := Vector3(6,0.05,13)
const NORTH := Vector3(6,0.05,2)

func _begin_take() -> void:
	var reverse := GameSession.ghost_count() % 2 == 1
	spawn_pos = NORTH if reverse else SOUTH
	report_pos = SOUTH if reverse else NORTH
	report_sign.position = Vector3(report_pos.x,0.42,report_pos.z)
	super._begin_take()
