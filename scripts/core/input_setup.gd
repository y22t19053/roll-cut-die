extends RefCounted
## InputSetup — the only place the input map is defined.
##
## The map is built at runtime instead of being stored in project.godot so that
## headless test runs and the editor see exactly the same bindings, and so the
## bindings can be asserted by a test. Re-running is idempotent.

## action -> physical keycodes (KEY_* constants from @GlobalScope)
const ACTIONS := {
	"move_forward": [KEY_W, KEY_UP],
	"move_back": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"interact": [KEY_E],
	"cut": [KEY_C],
	"mark": [KEY_M],
	"report": [KEY_R],
	"retake": [KEY_SPACE],
	"pause": [KEY_ESCAPE],
	"toggle_language": [KEY_F2],
	"debug_toggle": [KEY_F3],
	"debug_ghost": [KEY_F4],
}

const DEADZONE := 0.2


## (Re)build every action. Returns the number of actions configured.
static func ensure_actions() -> int:
	for action: String in ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action, DEADZONE)
		InputMap.action_erase_events(action)
		for key: int in ACTIONS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
	return ACTIONS.size()


## True when every action exists and carries at least one event.
static func verify_actions() -> Array:
	var problems: Array = []
	for action: String in ACTIONS:
		if not InputMap.has_action(action):
			problems.append("missing action " + action)
			continue
		if InputMap.action_get_events(action).is_empty():
			problems.append("action has no events " + action)
	return problems
