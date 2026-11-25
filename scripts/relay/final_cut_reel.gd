extends RefCounted
## Resolve the edit once. The timeline only reads the resulting reel.
const Loc = preload("res://scripts/core/loc.gd")
const Track = preload("res://scripts/ghost/ghost_track.gd")

const ENDINGS := {
	"file_closed": "TRUTH",
	"bury_registered": "COVER-UP",
	"reframe_held": "FRAME-UP",
}
const PIECE_COUNT := 12
const CARD_COUNT := 6
const STACK_COUNT := 3
const STANCES := {"file": "final_cut.file", "bury": "final_cut.bury", "reframe": "final_cut.reframe"}


## A relay run never files a case report, so the wrap reads the run's own ledger:
## a clean run files itself, a death that was spliced out gets buried, and a death
## left in the cut is the take the reel frames. The animation still does not judge
## anything — the three endings stay the ones the design already names.
static func relay_verdict(deaths: int, cuts: int) -> String:
	if deaths <= 0:
		return "file_closed"
	if cuts >= 1:
		return "bury_registered"
	return "reframe_held"


static func from_run(verdict: String, session: Node, tracks: Array, relay_outtakes: Array) -> Dictionary:
	var ledger: Variant = session.takes
	var latest: Dictionary = ledger.history.back() if not ledger.history.is_empty() else {}
	var filed: String = latest.get("verdict", "")
	if verdict.is_empty() and ledger.state == ledger.State.FINISHED:
		verdict = filed
	if not ENDINGS.has(verdict):
		return {}
	if ledger.state == ledger.State.FINISHED and filed == verdict:
		return {"verdict": verdict, "takes": ledger.history, "outtakes": ledger.outtakes,
			"tracks": session.ghosts, "case_state": session.case_state}
	return from_relay(verdict, tracks, relay_outtakes)


## The relay's own reel: the tracks this run recorded and the deaths and splices
## it paid for. The case ledger is deliberately not read here, so a case session
## left finished in the same boot cannot change the edit.
static func from_relay(verdict: String, tracks: Array, relay_outtakes: Array) -> Dictionary:
	if not ENDINGS.has(verdict):
		return {}
	var takes: Array = []
	for track in tracks:
		takes.append({"take": track.take_id, "kind": "complete", "at": track.duration(), "track": track})
	var outtakes: Array = []
	for row: Dictionary in relay_outtakes:
		var entry := row.duplicate()
		entry["track"] = Track.from_dict(entry.get("strip", {}))
		outtakes.append(entry)
	return {"verdict": verdict, "takes": takes, "outtakes": outtakes}


static func relay_outtake(live: Variant, at: float, kind: String, source := -1) -> Dictionary:
	# Only the first two samples (flight) and final second (playback) are needed.
	var strip: Variant = Track.new()
	strip.take_id = live.take_id
	for i in live.size():
		var seconds := Track.dequant_time(live.times[i])
		if i >= 2 and seconds < live.duration() - 1.1:
			continue
		var pose: Dictionary = live.raw_at(i)
		strip.add_sample(seconds, pose.position, pose.facing, pose.cam_yaw, pose.cam_roll, live.flags[i])
	var sources := {0: "dolly", 2: "stagehand", 3: "shot"}
	var cause: String = "" if source < 0 else sources.get(source, "TAKE %02d" % source)
	return {"take": live.take_id, "kind": kind, "source": cause, "at": at, "strip": strip.to_dict()}


static func edit(data: Dictionary) -> Dictionary:
	var ending: String = ENDINGS.get(data.get("verdict", ""), "")
	var indexed_tracks := {}
	for entry: Dictionary in data.get("tracks", []):
		indexed_tracks[int(entry["take"])] = entry.get("track")

	var entries: Array[Dictionary] = []
	for collection: String in ["takes", "outtakes"]:
		for row: Dictionary in data.get(collection, []):
			var entry := row.duplicate()
			entry["track"] = row.get("track", indexed_tracks.get(int(row.get("take", 0))))
			entry["serial"] = entries.size()
			entry["hidden"] = entry.get("kind") == "die" or bool(entry.get("seized", false)) \
				or data.get("seized_takes", []).has(entry.get("take"))
			entries.append(entry)
	entries.sort_custom(_chronological)

	var completed: Array[Dictionary] = entries.filter(func(row: Dictionary) -> bool: return row.get("kind") == "complete")
	var cards: Array[Dictionary] = []
	var stacked: Array[Dictionary] = []
	if not completed.is_empty():
		var overflow := maxi(0, entries.size() - CARD_COUNT)
		cards.assign(entries.slice(overflow))
		stacked.assign(entries.slice(0, mini(overflow, STACK_COUNT)))
	else:
		cards.append({})

	var candidates: Array[Dictionary] = entries.filter(func(row: Dictionary) -> bool: return row.get("kind") != "cut")
	if candidates.is_empty():
		candidates.assign(entries if not entries.is_empty() else [{}])
	var fatal := _fatal(candidates)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(data.get("seed", 0))
	var positions := []
	for index in PIECE_COUNT:
		positions.append(index)
	for index in range(PIECE_COUNT - 1, 0, -1):
		var swap := rng.randi_range(0, index)
		var value: int = positions[index]
		positions[index] = positions[swap]
		positions[swap] = value

	var pieces: Array[Dictionary] = []
	for index in PIECE_COUNT:
		var row: Dictionary = candidates[int(floor(float(index) * candidates.size() / PIECE_COUNT))]
		var piece_id: int = positions[index]
		pieces.append({"id": piece_id, "row": row, "flight": _flight(row, rng)})
	if not fatal.is_empty():
		var selected := pieces.any(func(piece: Dictionary) -> bool: return piece["row"] == fatal)
		if ending == "FRAME-UP" or not selected:
			# Keep a death visible even when the full reel is longer than the
			# silhouette. FRAME-UP uses the chest as the last landing point.
			for piece: Dictionary in pieces:
				if piece["id"] == 1:
					piece["row"] = fatal
					piece["flight"] = _flight(fatal, rng)
					break
	pieces.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var left: Dictionary = a["row"]
		var right: Dictionary = b["row"]
		if ending == "COVER-UP" and bool(left.get("hidden", false)) != bool(right.get("hidden", false)):
			return not bool(left.get("hidden", false))
		if ending == "FRAME-UP":
			if (a["id"] == 1) != (b["id"] == 1):
				return b["id"] == 1
			if (left == fatal) != (right == fatal):
				return right == fatal
			if left.get("serial") != right.get("serial"):
				return _chronological(right, left)
		if left.get("serial") != right.get("serial"):
			return _chronological(left, right)
		return a["id"] < b["id"])
	var holes: Array[int] = []
	if ending == "COVER-UP":
		for piece: Dictionary in pieces:
			if piece["row"].get("hidden", false):
				holes.append(piece["id"])
		if holes.is_empty():
			holes.append(pieces.back()["id"])
	elif ending == "FRAME-UP":
		holes.assign([1, 7])

	var included: Array = candidates.filter(func(row: Dictionary) -> bool:
		return not row.is_empty() and (ending != "COVER-UP" or not row.get("hidden", false)))
	return {"ending": ending, "cards": cards, "stacked": stacked, "pieces": pieces, "holes": holes,
		"included": included.map(func(row: Dictionary) -> int: return int(row["take"])),
		"evidence_rows": _evidence(data, ending)}


static func card_text(row: Dictionary, data: Dictionary) -> Dictionary:
	if row.is_empty():
		return {"number": "", "status": Loc.ui("final_cut.empty"), "clock": ""}
	var status := ""
	match row.get("kind"):
		"complete":
			var stance: String = row.get("stance", "")
			status = Loc.ui("status.complete") if not STANCES.has(stance) else \
				Loc.ui("final_cut.complete", [Loc.ui(STANCES[stance])])
		"die":
			status = Loc.ui("final_cut.died", [_source(str(row.get("source", "")), data)])
		"cut":
			status = Loc.ui("final_cut.manual")
	var time := maxi(0, Track.quant_time(float(row.get("at", 0.0))))
	return {"number": Loc.ui("source.take", [int(row.get("take", 0))]), "status": status,
		"clock": "%02d:%02d.%02d" % [floori(time / 6000.0), floori(time / 100.0) % 60, time % 100]}


static func _source(source: String, data: Dictionary) -> String:
	var case_state: Variant = data.get("case_state")
	if case_state != null:
		var name := Loc.t(case_state.npc_meta(source).get("name", {}))
		if not name.is_empty():
			return name.to_upper()
	if Loc.STRINGS.has("final_cut.source_" + source):
		return Loc.ui("final_cut.source_" + source)
	if source.begins_with("TAKE "):
		return Loc.ui("source.take", [int(source.trim_prefix("TAKE "))])
	return source if not source.is_empty() else Loc.ui("final_cut.source_unknown")


static func _chronological(a: Dictionary, b: Dictionary) -> bool:
	if a.get("take", 0) != b.get("take", 0):
		return int(a.get("take", 0)) < int(b.get("take", 0))
	return int(a.get("serial", 0)) < int(b.get("serial", 0))


static func _fatal(entries: Array[Dictionary]) -> Dictionary:
	var best := {}
	for row: Dictionary in entries:
		if row.get("kind") != "die":
			continue
		# If the archive has no case position, use the deepest take in the reel.
		if best.is_empty() or float(row.get("severity", row["take"])) >= float(best.get("severity", best["take"])):
			best = row
	return best


static func _flight(row: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var heading := rng.randf_range(-PI, PI)
	var speed := 0.0
	var alive := true
	var track: Variant = row.get("track")
	if track != null and track.size() > 0:
		var first: Dictionary = track.raw_at(0)
		heading = float(first["facing"])
		alive = (track.flags[0] & Track.FLAG_ALIVE) != 0
		if track.size() > 1:
			var second: Dictionary = track.raw_at(1)
			var dt := Track.dequant_time(track.times[1] - track.times[0])
			speed = (second["position"] as Vector3).distance_to(first["position"]) / maxf(dt, 0.01)
	var direction := Vector2(-sin(heading), -cos(heading))
	return {"offset": direction * lerpf(0.40, 0.70, clampf(speed / 5.0, 0.0, 1.0)), "alive": alive}


static func _evidence(data: Dictionary, ending: String) -> Array[String]:
	var rows: Array[String] = []
	var case_state: Variant = data.get("case_state")
	if case_state != null:
		var ids: Array = case_state.attached_ids() if ending == "TRUTH" else case_state.taken_ids()
		var limit := 4 if ending == "TRUTH" else 2
		for id: String in ids.slice(0, limit):
			rows.append(Loc.t(case_state.evidence_meta(id).get("name", {})))
	if ending == "FRAME-UP":
		rows.append(Loc.ui("final_cut.unreturned"))
	return rows
