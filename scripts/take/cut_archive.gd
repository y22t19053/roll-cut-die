extends RefCounted
## In-memory edit histories. A cut stores IDs of immutable successful shots;
## snapshots contain branch-local scene data only, never the global Retake stock.
var _shots := {}
var _cuts := {1: []}
var _next_shot := 1
var _next_cut := 2
var active := 1

func record_success(take_id: int, entry: Dictionary, recording: Dictionary) -> int:
	var id := _next_shot
	_next_shot += 1
	_shots[id] = {"take": take_id, "entry": entry.duplicate(true), "recording": recording.duplicate(true)}
	_cuts[active].append(id)
	return id

## Fork immediately before a selected success. Caller restores the returned entry
## and rebuilds hazard actors only from the selected cut's surviving prefix.
func recut(source: int, ordinal: int) -> Dictionary:
	if not _cuts.has(source) or ordinal < 1 or ordinal > _cuts[source].size():
		return {}
	var ids: Array = _cuts[source]
	var entry: Dictionary = _shots[ids[ordinal - 1]].entry.duplicate(true)
	active = _next_cut
	_next_cut += 1
	_cuts[active] = ids.slice(0, ordinal - 1)
	return {"cut": active, "source": source, "ordinal": ordinal, "entry": entry}

func shot_ids(cut: int) -> Array:
	return _cuts.get(cut, []).duplicate()

func shot(id: int) -> Dictionary:
	return _shots.get(id, {}).duplicate(true)
