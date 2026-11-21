extends RefCounted
## Backlot's cuts of the five-shot rescue, on top of the immutable CutArchive.
##
## A cut is a list of successful shots plus the mission state the cut is standing
## in right now. Forking copies a prefix of shot IDs; the recordings themselves
## are never copied, renumbered or dropped, so every older cut stays playable.
## Nothing here knows about the Retake stock or the take counter.
const Archive = preload("res://scripts/take/cut_archive.gd")

var archive := Archive.new()
## cut -> mission state the cut is waiting in (entry of its next shot, or the
## finished state once its last shot is on screen).
var _standing := {}
## cut -> {"source": cut, "ordinal": n}; cut 1 has no parent.
var _parents := {}
var _order: Array = [1]

var active: int:
	get: return archive.active


## The active cut's current mission state (called on every take start and success).
func stand(state: Dictionary) -> void:
	_standing[active] = state.duplicate(true)


func standing(cut: int) -> Dictionary:
	return _standing.get(cut, {}).duplicate(true)


## `ghost` is the GameSession ghost entry {"take", "track"} of the finished take,
## or {} when the take left no usable track.
func record_success(take_id: int, entry: Dictionary, ghost: Dictionary) -> int:
	return archive.record_success(take_id, entry, ghost)


## Fork `source` immediately before its `ordinal`-th success. The new cut keeps
## successes 1..ordinal-1, becomes active, and stands in that success's recorded
## entry state. Returns {} (and changes nothing) when there is no such success.
func fork(source: int, ordinal: int) -> Dictionary:
	var made := archive.recut(source, ordinal)
	if made.is_empty():
		return {}
	var cut := int(made.cut)
	_order.append(cut)
	_parents[cut] = {"source": source, "ordinal": ordinal}
	_standing[cut] = (made.entry as Dictionary).duplicate(true)
	return made


## Make an existing cut the one new successes are appended to.
func open(cut: int) -> Dictionary:
	if not _standing.has(cut) or not _order.has(cut):
		return {}
	archive.active = cut
	return standing(cut)


func cuts() -> Array:
	return _order.duplicate()


func cut_count() -> int:
	return _order.size()


## The cut V switches to: the next one in creation order, wrapping.
func next_cut() -> int:
	return _order[(_order.find(active) + 1) % _order.size()]


func parent(cut: int) -> Dictionary:
	return _parents.get(cut, {}).duplicate()


func success_count(cut: int) -> int:
	return archive.shot_ids(cut).size()


## Take ids of a cut's successes, in shot order.
func takes(cut: int) -> Array:
	var out: Array = []
	for id: int in archive.shot_ids(cut):
		out.append(int(archive.shot(id).take))
	return out


## GameSession-shaped ghost entries for a cut: the same track objects that were
## recorded, in shot order. Successes without a track are skipped.
func ghosts(cut: int) -> Array:
	var out: Array = []
	for id: int in archive.shot_ids(cut):
		var rec: Dictionary = archive.shot(id).recording
		if rec.get("track") != null:
			out.append({"take": int(rec.get("take", 0)), "track": rec.track})
	return out


## Recorded entry state of a cut's `ordinal`-th success ({} if none).
func entry(cut: int, ordinal: int) -> Dictionary:
	var ids := archive.shot_ids(cut)
	if ordinal < 1 or ordinal > ids.size():
		return {}
	return archive.shot(ids[ordinal - 1]).entry
