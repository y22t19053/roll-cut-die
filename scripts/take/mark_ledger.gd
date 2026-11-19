extends RefCounted
## MarkLedger — the player's personal anchors on the current timeline (D-005:
## MARK spends anchor capacity and nothing else).
##
## A point is a plain Dictionary so the CUT panel, the scene and the tests read
## the same record:
##   kind      "checkpoint" | "mark"
##   no        1-based MARK number (0 for the checkpoint)
##   take      take index it was recorded in
##   pos       Vector3 world position;  facing  body facing (rad)
##   cam_yaw   cam_roll  camera frame (rad)
##   evidence  deep copy of CaseState.evidence at that moment
##   time      TakeManager.elapsed (game clock shown to the player)
##   world_t   physics seconds the NPCs and ghosts had run
##   rec_t     GhostRecorder.elapsed(), where the ghost track resumes
##
## Full ledger refuses a new MARK instead of dropping the oldest one: an anchor
## is a promise the player made to themselves, and losing it silently at the
## moment they make another is the worst time to find out. Capacity comes back
## by cutting to an earlier point, which voids every MARK made after it.

const CAPACITY := 3

var capacity := CAPACITY
var marks: Array = []
## The system point: where control was handed over on this timeline.
var checkpoint: Dictionary = {}


func count() -> int:
	return marks.size()


func is_full() -> bool:
	return marks.size() >= capacity


## Store a MARK. Returns false (and stores nothing) when the ledger is full.
func add(point: Dictionary) -> bool:
	if is_full():
		return false
	point["kind"] = "mark"
	point["no"] = marks.size() + 1
	marks.append(point)
	return true


## Cutting to MARK n keeps MARK 1..n; later ones belonged to the abandoned take.
func keep_through(no: int) -> void:
	marks.resize(clampi(no, 0, marks.size()))


func clear() -> void:
	marks.clear()


## Every point the CUT panel can offer, oldest first: checkpoint, then MARKs.
func points() -> Array:
	var out: Array = []
	if not checkpoint.is_empty():
		out.append(checkpoint)
	out.append_array(marks)
	return out


static func label(p: Dictionary) -> String:
	if str(p.get("kind", "")) == "mark":
		return "MARK %d" % int(p.get("no", 0))
	return "START"


## [seen-or-taken count, taken count] of an evidence snapshot.
static func evidence_counts(evidence: Dictionary) -> Vector2i:
	var seen := 0
	var taken := 0
	for id: String in evidence:
		var e: Dictionary = evidence[id]
		if e.get("seen", false) or e.get("taken", false):
			seen += 1
		if e.get("taken", false):
			taken += 1
	return Vector2i(seen, taken)


static func clock(seconds: float) -> String:
	var s := maxf(seconds, 0.0)
	return "%02d:%04.1f" % [int(s / 60.0), fmod(s, 60.0)]


## One line of the CUT panel, from the record alone.
static func describe(p: Dictionary) -> String:
	var ev := evidence_counts(p.get("evidence", {}))
	var pos: Vector3 = p.get("pos", Vector3.ZERO)
	return "%-7s TAKE %02d   T %s   EVIDENCE %d (%d TAKEN)   X %.2f  Z %.2f" % [
		label(p), int(p.get("take", 0)), clock(float(p.get("time", 0.0))),
		ev.x, ev.y, pos.x, pos.z]
