extends RefCounted
## CaseState — what the player has seen, taken, listed and asked.
##
## This is the single source of truth for the case. The report verdict is a pure
## function of these flags plus the chosen stance: it never looks at which keys
## were pressed, so a verdict can always be explained by pointing at state.

## Inspect once: the item enters the record.
const SEEN := 1
## Pick up: the item is in your hands, and is listed on the report by default.
const TAKEN := 2

var data: Dictionary = {}
var evidence: Dictionary = {}  # id -> {"seen": bool, "taken": bool, "attached": bool}
var asked: Dictionary = {}  # npc_id -> int
var stance := ""


func load_data(d: Dictionary) -> void:
	data = d
	evidence.clear()
	asked.clear()
	stance = ""
	for e: Dictionary in data.get("evidence", []):
		var id := str(e.get("id", ""))
		if id.is_empty():
			continue
		evidence[id] = {"seen": false, "taken": false, "attached": false}
	for n: Dictionary in data.get("npcs", []):
		asked[str(n.get("id", ""))] = 0


func evidence_ids() -> Array:
	return evidence.keys()


func evidence_meta(id: String) -> Dictionary:
	for e: Dictionary in data.get("evidence", []):
		if str(e.get("id", "")) == id:
			return e
	return {}


func npc_meta(id: String) -> Dictionary:
	for n: Dictionary in data.get("npcs", []):
		if str(n.get("id", "")) == id:
			return n
	return {}


func is_seen(id: String) -> bool:
	return evidence.has(id) and evidence[id]["seen"]


func is_taken(id: String) -> bool:
	return evidence.has(id) and evidence[id]["taken"]


func is_attached(id: String) -> bool:
	return evidence.has(id) and evidence[id]["attached"]


func seen_ids() -> Array:
	return _filter("seen")


func taken_ids() -> Array:
	return _filter("taken")


func attached_ids() -> Array:
	return _filter("attached")


func _filter(key: String) -> Array:
	var out: Array = []
	for id: String in evidence:
		if evidence[id][key]:
			out.append(id)
	return out


## Inspect (or pick up) an evidence item.
## First press: SEEN. Second press: TAKEN, which also lists it on the report.
## Returns "taken", "seen" or "" (already fully taken).
func inspect(id: String) -> String:
	if not evidence.has(id):
		return ""
	var e: Dictionary = evidence[id]
	if e["taken"]:
		return ""
	if e["seen"]:
		e["taken"] = true
		e["attached"] = true
		return "taken"
	e["seen"] = true
	return "seen"


## List or unlist an item on the report. Only items you are holding can be
## listed — you cannot cite something you left on the table.
func toggle_attach(id: String) -> bool:
	if not evidence.has(id):
		return false
	var e: Dictionary = evidence[id]
	if not e["taken"]:
		return false
	e["attached"] = not e["attached"]
	return e["attached"]


func asks(npc_id: String) -> int:
	return int(asked.get(npc_id, 0))


## The line that applies at a given ask count: the LAST line whose min_asks is
## already reached and whose requires_inspected list is fully inspected.
func _select_index(meta: Dictionary, count: int) -> int:
	var lines: Array = meta.get("lines", [])
	var best := -1
	for i in range(lines.size()):
		var line: Dictionary = lines[i]
		if count < int(line.get("min_asks", 0)):
			continue
		var ok := true
		for req: String in line.get("requires_inspected", []):
			if not is_seen(req):
				ok = false
				break
		if ok:
			best = i
	return best


## Ask an NPC. Returns the line that applies right now.
##
## The counter is "how many distinct answers this person has given", not "how
## many times the key was pressed". A press only advances it when the line it
## produces sits at or past the counter — that is, when there is new material to
## press on. Repeating the same answer leaves the counter alone, so hammering the
## key cannot grind the interview open; what moves the conversation is what you
## inspected. A line whose min_asks was skipped over advances the counter past
## it, so the numbering never deadlocks.
func ask(npc_id: String) -> Dictionary:
	var meta := npc_meta(npc_id)
	if meta.is_empty():
		return {}
	var count := asks(npc_id)
	var idx := _select_index(meta, count)
	if idx >= count:
		asked[npc_id] = maxi(count + 1, idx + 1)
	if idx < 0:
		return {"text": {"zh": "……", "en": "..."}}
	var lines: Array = meta.get("lines", [])
	return lines[idx]


func both_asked() -> bool:
	for id: String in asked:
		if int(asked[id]) <= 0:
			return false
	return asked.size() > 0


func stance_ids() -> Array:
	var out: Array = []
	for s: Dictionary in data.get("report", {}).get("stances", []):
		out.append(str(s.get("id", "")))
	return out


func stance_meta(id: String) -> Dictionary:
	for s: Dictionary in data.get("report", {}).get("stances", []):
		if str(s.get("id", "")) == id:
			return s
	return {}


## The verdict id for a stance, from state alone.
func verdict(stance_id: String) -> String:
	var attached := attached_ids().size()
	var taken := taken_ids().size()
	var both := both_asked()
	match stance_id:
		"file":
			if attached >= 3 and both:
				return "file_closed"
			if attached == 2:
				return "file_insufficient"
			return "file_rejected"
		"bury":
			# You must have removed at least two items, and every item you
			# removed must stay off the record. Keeping one for yourself is the
			# one thing this stance cannot survive.
			if taken >= 2 and attached >= taken:
				return "bury_registered"
			return "bury_failed"
		"reframe":
			if attached <= 2:
				return "reframe_held"
			return "reframe_unravelled"
	return ""


## A retake rewinds what was only looked at. Anything already seized stays
## seized, and the interview counters stay where they are: a person who has
## answered does not forget the question.
func on_retake() -> void:
	for id: String in evidence:
		if not evidence[id]["taken"]:
			evidence[id]["seen"] = false


func verdict_text(verdict_id: String) -> Dictionary:
	var table: Dictionary = data.get("report", {}).get("verdicts", {})
	if not table.has(verdict_id):
		return {"zh": "（无判决文本）", "en": "(no verdict text)"}
	var entry: Dictionary = table[verdict_id]
	# case.json stores a title and a body separately; everything downstream
	# wants one string per language.
	if entry.has("zh") or entry.has("en"):
		return entry
	var out := {}
	for lang: String in ["zh", "en"]:
		var title: String = str(entry.get("title", {}).get(lang, ""))
		var body: String = str(entry.get("body", {}).get(lang, ""))
		out[lang] = title if body.is_empty() else title + "\n" + body
	return out


## Snapshot for the save file.
func to_dict() -> Dictionary:
	return {"evidence": evidence.duplicate(true), "asked": asked.duplicate(true), "stance": stance}


func from_dict(d: Dictionary) -> void:
	if d.has("evidence") and d["evidence"] is Dictionary:
		for id: String in evidence:
			if d["evidence"].has(id):
				var src: Dictionary = d["evidence"][id]
				evidence[id] = {
					"seen": bool(src.get("seen", false)),
					"taken": bool(src.get("taken", false)),
					"attached": bool(src.get("attached", false)),
				}
	if d.has("asked") and d["asked"] is Dictionary:
		for id: String in asked:
			asked[id] = int(d["asked"].get(id, 0))
	stance = str(d.get("stance", ""))
