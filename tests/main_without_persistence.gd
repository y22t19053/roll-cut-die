extends "res://scripts/main.gd"
## For gameplay probes only: exercise production interaction logic, not disk persistence.
var intercepted_writes := 0

func _commit_state() -> void:
	intercepted_writes += 1

func _load_latest_state() -> void:
	pass
