extends RefCounted
## The case is the only place where "what the player knows" gates "what the game
## will say". Both directions are tested: state produces the verdict, and the
## verdict table has text for every id the code can produce.

const CaseState = preload("res://scripts/case/case_state.gd")
const Harness = preload("res://tests/harness.gd")

const EVIDENCE := ["clapboard", "script_page", "walkie", "receipt"]
const NPCS := ["director", "stagehand"]
const VERDICTS := ["file_closed", "file_insufficient", "file_rejected", "bury_registered",
	"bury_failed", "reframe_held", "reframe_unravelled"]


static func run(h, _tree = null) -> void:
	h.begin("case")

	var data: Variant = Harness.read_json("res://data/case.json")
	h.ok("case.json parses", data is Dictionary)
	if not (data is Dictionary):
		return

	var cs = CaseState.new()
	cs.load_data(data)

	h.eq("four evidence items", cs.evidence_ids().size(), 4)
	h.eq("three stances", cs.stance_ids().size(), 3)

	# --- inspect is two steps ---------------------------------------------
	h.eq("first look marks seen", cs.inspect("receipt"), "seen")
	h.ok("seen is recorded", cs.is_seen("receipt"))
	h.ok("seen is not taken", not cs.is_taken("receipt"))
	h.eq("second press seizes", cs.inspect("receipt"), "taken")
	h.ok("taken is recorded", cs.is_taken("receipt"))
	h.ok("seized items start attached", cs.is_attached("receipt"))
	h.eq("third press is a no-op", cs.inspect("receipt"), "")

	# --- attach requires seized -------------------------------------------
	h.ok("cannot attach what you never took", not cs.toggle_attach("walkie"))

	# --- verdict matrix ----------------------------------------------------
	# Fresh case, nothing done: filing is rejected, burial fails, a thin rewrite
	# survives.
	h.eq("empty file -> rejected", cs.verdict("file"), "file_rejected")
	h.eq("empty bury -> failed", cs.verdict("bury"), "bury_failed")
	h.eq("empty reframe -> holds", cs.verdict("reframe"), "reframe_held")

	# Seizing takes two presses, so "two attached" has to press each item twice;
	# one press only marks it seen and nothing lands on the record.
	var two = _fresh(data)
	for id: String in ["receipt", "walkie"]:
		two.inspect(id)
		two.inspect(id)
	h.eq("two attached -> sent back", two.verdict("file"), "file_insufficient")
	h.eq("two attached -> rewrite holds", two.verdict("reframe"), "reframe_held")
	h.eq("two taken, two attached -> buried", two.verdict("bury"), "bury_registered")

	var kept = _fresh(data)
	for id: String in ["clapboard", "walkie"]:
		kept.inspect(id)
		kept.inspect(id)
	kept.toggle_attach("clapboard")  # keep one back
	h.eq("keeping one back breaks the burial", kept.verdict("bury"), "bury_failed")

	var full = _fresh(data)
	for id: String in EVIDENCE:
		full.inspect(id)
		full.inspect(id)
	full.ask("director")
	full.ask("stagehand")
	h.eq("all four attached + both asked -> holds", full.verdict("file"), "file_closed")
	h.eq("all four attached -> too much paper", full.verdict("reframe"), "reframe_unravelled")
	h.eq("all four attached + both asked -> buried", full.verdict("bury"), "bury_registered")

	var three = _fresh(data)
	for id in ["clapboard", "script_page", "walkie"]:
		three.inspect(id)
		three.inspect(id)
	three.ask("director")
	h.ok("three attached, one voice -> not closed", three.verdict("file") != "file_closed")
	h.eq("three attached, one voice -> rejected", three.verdict("file"), "file_rejected")

	# --- interview gating --------------------------------------------------
	var talk = _fresh(data)
	var l1: Dictionary = talk.ask("director")
	h.ok("first answer is the flat denial", str(l1.get("text", {}).get("en", "")).begins_with("The room"))
	var l1b: Dictionary = talk.ask("director")
	h.ok("without inspecting, the door stays shut",
		str(l1b.get("text", {}).get("en", "")) == str(l1.get("text", {}).get("en", "")))
	h.eq("a repeated answer is not a new question", talk.asks("director"), 1)

	talk.inspect("script_page")
	var l2: Dictionary = talk.ask("director")
	h.ok("inspecting the script page opens the second answer",
		str(l2.get("text", {}).get("en", "")).begins_with("Not my handwriting"))
	var l3: Dictionary = talk.ask("director")
	h.ok("third pressure gets the third answer",
		str(l3.get("text", {}).get("en", "")).begins_with("Is there a receiving"))

	h.eq("director asked three times", talk.asks("director"), 3)
	talk.ask("stagehand")
	h.ok("both asked once both have spoken", talk.both_asked())

	# --- every verdict has text in both languages --------------------------
	for v: String in VERDICTS:
		var txt: Dictionary = cs.verdict_text(v)
		h.ok("verdict text exists: " + v, txt.has("zh") and txt.has("en"))
		h.ok("verdict text is not empty: " + v,
			str(txt.get("zh", "")).length() > 4 and str(txt.get("en", "")).length() > 4)

	# --- retake semantics --------------------------------------------------
	# Looking is undone, seizing is not: the sealed item is on the SCENE axis.
	# The question is asked before the script page is looked at, so it is the
	# first answer and the counter is 1 — asking after inspecting would already
	# deliver the second answer.
	var rt = _fresh(data)
	rt.inspect("receipt")
	rt.inspect("receipt")         # seized
	rt.ask("director")            # first answer
	rt.inspect("script_page")     # seen only
	rt.on_retake()
	h.ok("retake forgets what was only looked at", not rt.is_seen("script_page"))
	h.ok("retake keeps what was seized", rt.is_taken("receipt"))
	h.ok("retake keeps the sealed item attached", rt.is_attached("receipt"))
	h.eq("retake does not forget a question", rt.asks("director"), 1)

	# --- save round-trip ---------------------------------------------------
	var snap: Dictionary = rt.to_dict()
	var restored = _fresh(data)
	restored.from_dict(snap)
	h.ok("state survives serialisation", restored.is_taken("receipt"))
	h.eq("counters survive serialisation", restored.asks("director"), 1)


static func _fresh(data: Dictionary):
	var cs = CaseState.new()
	cs.load_data(data)
	return cs
