extends RefCounted
## Owned by the current run, never by a MARK. `now` is the run's monotonic
## active physics time, not the rewound take clock or elapsed wall time.
const DURATION := 1.5
var _held := false
var _protected_until := -INF

func offer() -> void:
	_held = true

func has_splice() -> bool:
	return _held

func seconds_left(now: float) -> float:
	return maxf(0.0, _protected_until - now)

func protect(now: float) -> bool:
	if now < _protected_until: return true
	if not _held: return false
	_held = false
	_protected_until = now + DURATION
	return true
