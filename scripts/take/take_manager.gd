extends RefCounted
## TakeManager — the life of one take, and the ledger of all of them.
##
## Exactly one state machine governs the take, so "what is happening now" has a
## single answer. Death and manual cut are different states with different
## wording and different consequences, even though both show the slate:
##
##   ROLLING --die-->     DIED    --retake--> ROLLING (take+1)
##   ROLLING --C-->       CUT     --retake--> ROLLING (take+1)
##   ROLLING --report-->  FINISHED (the take is a success; it can become a ghost)
##
## Only FINISHED takes are eligible to become ghosts. DIED and CUT become
## outtakes.

signal state_changed(prev: int, next: int)
signal take_started(index: int)
signal take_died(source: String)
signal take_cut()
signal take_finished(result: String)
signal report_filed(stance: String, verdict: String)

enum State {
	ROLLING,
	DIED,
	CUT,
	REPORTING,
	FINISHED,
}

var state: int = State.ROLLING
## 1-based attempt number shown on the slate as TAKE nn.
var take_index := 1
var elapsed := 0.0
## Set when the take ends by death. "" otherwise.
var death_source := ""
## One record per finished attempt.
var history: Array = []
## One record per death or manual cut.
var outtakes: Array = []


func _init() -> void:
	state = State.ROLLING


func start_take(index: int) -> void:
	take_index = maxi(index, 1)
	elapsed = 0.0
	death_source = ""
	_set_state(State.ROLLING)
	take_started.emit(take_index)


func tick(dt: float) -> void:
	if state == State.ROLLING:
		elapsed += dt


func can_act() -> bool:
	return state == State.ROLLING


func state_name() -> String:
	match state:
		State.ROLLING:
			return "ROLLING"
		State.DIED:
			return "DIED"
		State.CUT:
			return "CUT"
		State.REPORTING:
			return "REPORTING"
		State.FINISHED:
			return "FINISHED"
	return "?"


## The player walked into somebody. `source` is an npc id, "TAKE 03", or similar.
func die(source: String) -> bool:
	if state != State.ROLLING:
		return false
	death_source = source
	outtakes.append({
		"take": take_index,
		"kind": "die",
		"source": source,
		"at": elapsed,
	})
	_set_state(State.DIED)
	take_died.emit(source)
	return true


## The player pressed C. Deliberate, so the wording is not "you died".
func manual_cut() -> bool:
	if state != State.ROLLING:
		return false
	outtakes.append({
		"take": take_index,
		"kind": "cut",
		"source": "",
		"at": elapsed,
	})
	_set_state(State.CUT)
	take_cut.emit()
	return true


## Begin filing the report. The player can still back out to ROLLING.
func begin_report() -> bool:
	if state != State.ROLLING:
		return false
	_set_state(State.REPORTING)
	return true


func cancel_report() -> void:
	if state == State.REPORTING:
		_set_state(State.ROLLING)


## Commit the report: this ends the take as a success.
func commit_report(stance: String, verdict: String) -> bool:
	if state != State.REPORTING:
		return false
	history.append({
		"take": take_index,
		"kind": "complete",
		"stance": stance,
		"verdict": verdict,
		"at": elapsed,
	})
	report_filed.emit(stance, verdict)
	_set_state(State.FINISHED)
	take_finished.emit(verdict)
	return true


## Move to the next attempt. Works from DIED, CUT and FINISHED.
func retake() -> int:
	take_index += 1
	elapsed = 0.0
	death_source = ""
	start_take(take_index)
	return take_index


func _set_state(next: int) -> void:
	if next == state:
		return
	var prev := state
	state = next
	state_changed.emit(prev, next)
