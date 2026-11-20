extends "res://tests/probe_junction_retry.gd"
## Identical geometry and controls; the first performer waits before crossing.
func actor_wait_ticks() -> int:
	return 60
