extends RefCounted

const FinalCut = preload("res://scripts/relay/final_cut.gd")
const Reel = preload("res://scripts/relay/final_cut_reel.gd")
const Track = preload("res://scripts/ghost/ghost_track.gd")
const CaseState = preload("res://scripts/case/case_state.gd")
const Loc = preload("res://scripts/core/loc.gd")
const Session = preload("res://scripts/core/game_session.gd")


static func run(h, tree = null) -> void:
	h.begin("final cut clock, reel and localization")
	var data := sample_data()
	var controller := _start(tree, data)
	var signals := [0]
	controller.finished.connect(func() -> void: signals[0] += 1)
	var starts := [0.00, 1.05, 2.30, 3.10, 4.30, 5.30, 7.00, 8.70, 10.10, 11.90]
	var elapsed := 0.0
	for i in starts.size():
		var at: float = starts[i]
		if i > 0:
			controller.advance(at - elapsed - 0.001)
			h.eq("beat before %.2f" % at, controller.debug_state()["beat"], i)
			controller.advance(0.001)
		h.eq("beat at %.2f" % at, controller.debug_state()["beat"], i + 1)
		h.near("time at beat %d" % (i + 1), controller.debug_state()["elapsed"], at)
		elapsed = at
	controller.advance(0.699)
	h.eq("still playing at 12.599", controller.debug_state()["playing"], true)
	h.eq("no premature signal", signals[0], 0)
	controller.advance(0.001)
	h.eq("finished once at 12.60", signals[0], 1)
	h.near("the final cut is 12.60 seconds", controller.debug_state()["elapsed"], 12.60)
	controller.advance(25.0)
	controller.play(data)
	h.eq("finished cannot be replayed or emitted twice", signals[0], 1)
	var truth := controller.debug_state()
	h.eq("FILE branches to TRUTH", truth["ending"], "TRUTH")
	h.eq("twelve pieces", truth["fragment_count"], 12)
	h.eq("truth has no holes", truth["holes"], [])
	h.eq("truth includes completes and deaths", truth["include_takes"], [1, 2, 4, 5, 6])
	h.eq("truth prints three attached evidence rows", truth["evidence_rows"].size(), 3)
	h.ok("truth orders ascending takes", _ordered(truth["piece_takes"], false))
	h.ok("first-sample flag is preserved", truth["flights"].any(func(flight: Dictionary) -> bool:
		return not flight["alive"]))
	for flight: Dictionary in truth["flights"]:
		var distance: float = flight["offset"].length()
		h.ok("flight distance stays within 0.40–0.70m", distance >= 0.3999 and distance <= 0.7001)

	var twin := _start(tree, data)
	twin.advance(12.60)
	h.eq("same seed and reel produce the same completed state", twin.debug_state(), truth)
	data["seed"] = 173
	var alternate := _start(tree, data)
	h.ok("seed changes placement order", alternate.debug_state()["piece_order"] != truth["piece_order"])
	h.eq("seed leaves verdict intact", alternate.debug_state()["ending"], "TRUTH")

	data["verdict"] = "bury_registered"
	var cover := _start(tree, data)
	var cover_state := cover.debug_state()
	h.eq("BURY branches to COVER-UP", cover_state["ending"], "COVER-UP")
	h.eq("cover suppresses death and seized strips", cover_state["include_takes"], [2, 6])
	h.ok("cover leaves holes", cover_state["holes"].size() > 0)
	h.eq("cover puts only two evidence rows on screen", cover_state["evidence_rows"].size(), 2)
	var order: Array = cover_state["piece_takes"]
	h.ok("unsuppressed pieces come first", order.slice(0, order.count(2) + order.count(6)).all(
		func(take: int) -> bool: return take in [2, 6]))
	h.ok("suppressed pieces come last", order.slice(order.count(2) + order.count(6)).all(
		func(take: int) -> bool: return take in [1, 4, 5]))

	data["verdict"] = "reframe_held"
	var frame := _start(tree, data)
	var frame_state := frame.debug_state()
	h.eq("REFRAME branches to FRAME-UP", frame_state["ending"], "FRAME-UP")
	h.eq("frame keeps both holes", frame_state["holes"], [1, 7])
	h.eq("highest-severity fatal take lands last", frame_state["piece_takes"].back(), 1)
	h.eq("fatal piece lands on chest", frame_state["piece_order"].back(), 1)
	h.ok("other pieces descend by take", _ordered(frame_state["piece_takes"].slice(0, 11), true))
	h.eq("frame adds the unreturned row", frame_state["evidence_rows"].back(), Loc.ui("final_cut.unreturned"))

	var overflow := _start(tree, sample_data("file_closed", 12))
	h.eq("six full cards", overflow.debug_state()["cards"], 6)
	h.eq("three earliest archive tabs", overflow.debug_state()["stacked"], 3)
	h.eq("earliest stack starts with take 1", Reel.edit(sample_data("file_closed", 12))["stacked"][0]["take"], 1)
	var blank := _start(tree, {"verdict": "file_closed", "outtakes": data["outtakes"]})
	h.eq("no completion leaves one blank card", blank.debug_state()["cards"], 1)
	h.eq("returned verdict never starts playback", _start(tree, {"verdict": "file_rejected"}).debug_state()["playing"], false)
	h.eq("blank card is localized", Reel.card_text({}, data)["status"], Loc.ui("final_cut.empty"))
	h.eq("timecode keeps centiseconds", Reel.card_text({"at": 61.234}, data)["clock"], "01:01.23")
	h.eq("death card names the source", Reel.card_text(data["outtakes"][0], data)["status"], "DIED · STAGEHAND")
	_check_relay_source(h, tree, data)
	var prior: String = Loc.language
	for key: String in Loc.STRINGS:
		if not key.begins_with("final_cut."):
			continue
		for lang: String in Loc.SUPPORTED:
			Loc.set_language(lang)
			h.ok("%s translated in %s" % [key, lang], not str(Loc.STRINGS[key].get(lang, "")).is_empty())
			h.ok("%s resolves in %s" % [key, lang], not Loc.ui(key).is_empty())
	h.eq("two original verdict lines", Loc.ui("final_cut.line_one") + "\n" + Loc.ui("final_cut.line_two"),
		"NO SINGLE TAKE WAS GOOD ENOUGH.\nSO WE MADE A FINAL CUT.")
	Loc.set_language(prior)
	h.finish()


static func _check_relay_source(h, tree: SceneTree, data: Dictionary) -> void:
	var session := tree.root.get_node("GameSession") as Session
	var ledger: Variant = session.takes
	var previous_history: Array = ledger.history
	var previous_state: int = ledger.state
	ledger.history = [{"take": 1, "kind": "complete", "verdict": "file_closed"}]
	ledger.state = ledger.State.ROLLING
	var completed: Variant = data["takes"][0]["track"]
	var abandoned := Reel.relay_outtake(data["outtakes"][0]["track"], 12.34, "die", 2)
	h.eq("a verdict from an unfinished ledger cannot start a cut", Reel.from_run("", session, [], []), {})
	h.eq("nonterminal verdict does not start a cut", Reel.from_run("file_rejected", session, [], []), {})
	var relay := Reel.from_run("bury_registered", session, [completed], [abandoned])
	h.eq("relay track becomes completed footage", relay["takes"][0]["track"], completed)
	h.eq("relay death preserves its cause", relay["outtakes"][0]["source"], "stagehand")
	h.near("relay death keeps the original timestamp", relay["outtakes"][0]["at"], 12.34)
	var archived: Variant = relay["outtakes"][0]["track"]
	h.eq("relay archive preserves the ending pose", archived.raw_at(archived.size() - 1),
		data["outtakes"][0]["track"].raw_at(data["outtakes"][0]["track"].size() - 1))
	h.eq("relay archive preserves first sample flags", archived.flags[0], Track.FLAG_ALIVE)
	ledger.state = ledger.State.FINISHED
	h.eq("a committed report supplies the verdict", Reel.from_run("", session, [], [])["verdict"], "file_closed")
	h.eq("campaign reel is the actual take ledger", Reel.from_run("", session, [], [])["takes"], ledger.history)
	ledger.history = previous_history
	ledger.state = previous_state


static func _start(tree: SceneTree, data: Dictionary) -> FinalCut:
	var cut := FinalCut.new()
	cut.manual_time = true
	tree.root.add_child(cut)
	cut.play(data)
	cut.queue_free()
	return cut


static func _ordered(takes: Array, descending: bool) -> bool:
	for i in range(1, takes.size()):
		if (takes[i] > takes[i - 1]) if descending else (takes[i] < takes[i - 1]):
			return false
	return true


static func sample_data(verdict := "file_closed", length := 6) -> Dictionary:
	var case_state := CaseState.new()
	case_state.load_data(JSON.parse_string(FileAccess.get_file_as_string("res://data/case.json")))
	for id: String in case_state.evidence_ids().slice(0, 3):
		case_state.inspect(id)
		case_state.inspect(id)
	var takes: Array = []
	var outtakes: Array = []
	for i in range(1, length + 1):
		var track := Track.new()
		track.take_id = i
		for j in 24:
			var t := j * 0.1
			var position := Vector3(sin(t * 1.3 + i) * 1.6, 0.0, cos(t + i) * 1.9)
			track.add_sample(t, position, 1.37 * i + t, 0.70 * i + 0.25 * t, sin(t + i) * 0.13,
				0 if i == 4 and j == 0 else Track.FLAG_ALIVE)
		var row := {"take": i, "kind": "complete", "at": i * 2.253, "track": track,
			"stance": {"file_closed": "file", "bury_registered": "bury", "reframe_held": "reframe"}[verdict]}
		match i:
			1, 4:
				row["kind"] = "die"
				row["source"] = "stagehand" if i == 1 else "TAKE 02"
				row["severity"] = 9 if i == 1 else 2
				outtakes.append(row)
			3:
				row["kind"] = "cut"
				outtakes.append(row)
			_:
				row["seized"] = i == 5
				takes.append(row)
	return {"verdict": verdict, "takes": takes, "outtakes": outtakes, "case_state": case_state,
		"seed": 11613, "secs": 56.4, "deaths": outtakes.size() - 1, "legs": takes.size()}
