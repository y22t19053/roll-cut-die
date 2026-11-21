extends RefCounted
## TakeManager is the game's spine: every other system asks it what state the
## shoot is in. The states are the design, so they are tested as a table.

const TakeManager = preload("res://scripts/take/take_manager.gd")


static func run(h, _tree = null) -> void:
	h.begin("take")

	var m = TakeManager.new()
	h.eq("starts idle-ish", m.state, TakeManager.State.ROLLING)
	h.eq("first take is 1", m.take_index, 1)

	m.start_take(1)
	h.ok("can act while rolling", m.can_act())
	m.tick(1.0)
	h.near("clock advances", m.elapsed, 1.0, 0.0001)

	# --- death -------------------------------------------------------------
	h.ok("dying changes state", m.die("director"))
	h.eq("state is DIED", m.state, TakeManager.State.DIED)
	h.eq("death source recorded", m.death_source, "director")
	h.ok("cannot act while dead", not m.can_act())
	h.eq("one outtake", m.outtakes.size(), 1)
	h.eq("outtake kind", str(m.outtakes[0]["kind"]), "die")
	h.eq("outtake names the culprit", str(m.outtakes[0]["source"]), "director")
	h.ok("dying twice is refused", not m.die("stagehand"))
	h.eq("still one outtake", m.outtakes.size(), 1)

	# --- retake ------------------------------------------------------------
	var next: int = m.retake()
	h.eq("retake bumps the take", next, 2)
	h.eq("state back to rolling", m.state, TakeManager.State.ROLLING)
	h.eq("clock reset", m.elapsed, 0.0)
	h.ok("can act again", m.can_act())
	h.eq("death source cleared", m.death_source, "")

	# --- manual cut --------------------------------------------------------
	h.ok("cut while rolling", m.manual_cut())
	h.eq("state is CUT", m.state, TakeManager.State.CUT)
	h.eq("preview leaves outtakes untouched", m.outtakes.size(), 1)
	h.ok("cannot cut twice", not m.manual_cut())
	m.retake()
	h.eq("third take", m.take_index, 3)

	# --- report ------------------------------------------------------------
	# Filing is a rolling-state action: the player walks to the desk and opens
	# the file. It is refused in every take-ending state, never while rolling.
	m.begin_report()
	h.eq("state is REPORTING", m.state, TakeManager.State.REPORTING)
	h.ok("cannot act while filing", not m.can_act())
	h.ok("reports cannot be opened twice", not m.begin_report())
	m.cancel_report()
	h.eq("cancelling returns to rolling", m.state, TakeManager.State.ROLLING)

	m.begin_report()
	h.ok("filing commits", m.commit_report("file", "file_closed"))
	h.eq("state is FINISHED", m.state, TakeManager.State.FINISHED)
	h.eq("one completed take in history", m.history.size(), 1)
	h.eq("history kind", str(m.history[0]["kind"]), "complete")
	h.eq("history keeps the verdict", str(m.history[0]["verdict"]), "file_closed")
	h.ok("cannot commit twice", not m.commit_report("bury", "bury_registered"))
	h.ok("cannot open a report after finishing", not m.begin_report())

	# --- names are used in UI and in logs, so they are fixed ---------------
	var names: Array = []
	for s in [TakeManager.State.ROLLING, TakeManager.State.DIED, TakeManager.State.CUT,
			TakeManager.State.REPORTING, TakeManager.State.FINISHED]:
		var probe = TakeManager.new()
		probe.state = s
		names.append(probe.state_name())
	h.eq("state names", str(names), "[\"ROLLING\", \"DIED\", \"CUT\", \"REPORTING\", \"FINISHED\"]")

	# --- resources: DIE spends a Retake, CUT does not (D-005) -------------
	var r = TakeManager.new()
	var stock0: int = r.retake_stock
	h.eq("stock starts full", stock0, TakeManager.RETAKE_STOCK)
	r.die("director")
	h.eq("death spends one Retake", r.retake_stock, stock0 - 1)
	r.retake()
	r.tick(2.5)
	h.eq("resume refused while rolling", r.resume_after_cut("MARK 1", 1.0), -1)
	r.manual_cut()
	h.eq("CUT spends no Retake", r.retake_stock, stock0 - 1)
	var took: int = r.take_index
	h.eq("resume after CUT starts the next take", r.resume_after_cut("MARK 2", 1.75), took + 1)
	h.eq("resume is rolling", r.state, TakeManager.State.ROLLING)
	h.near("resume runs on the point's clock", r.elapsed, 1.75, 0.0001)
	h.eq("resume spends no Retake", r.retake_stock, stock0 - 1)
	h.eq("cut take stays an outtake", str(r.outtakes[-1]["kind"]), "cut")
	h.eq("outtake names where it resumed", str(r.outtakes[-1].get("resume", "")), "MARK 2")
	h.eq("outtake belongs to the cut take", int(r.outtakes[-1]["take"]), took)
	h.eq("resume twice is refused", r.resume_after_cut("MARK 1", 0.0), -1)
	for i in 10:
		r.die("x")
		r.retake()
	h.eq("stock never goes negative", r.retake_stock, 0)
