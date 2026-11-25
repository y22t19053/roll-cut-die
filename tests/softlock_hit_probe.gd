extends "res://scripts/relay/relay_run.gd"

var hit_calls := 0


func _hit(source: int) -> bool:
	hit_calls += 1
	return super._hit(source)
