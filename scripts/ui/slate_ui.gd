extends CanvasLayer
## SlateUI — the clapperboard as a timed sequence.
##
## One place decides what the slate says and when it clacks. ROLL, CUT and DIE
## are the same board with different scripts, which is the point: the player
## learns one object and reads three events off it.
##
## The sequence emits `sequence_finished(kind)` exactly once, and the caller
## decides what happens next. The slate never changes game state itself.

signal sequence_finished(kind: String)

const BoardScript = preload("res://scripts/ui/slate_board.gd")
const SlateAudio = preload("res://scripts/ui/slate_audio.gd")
const Loc = preload("res://scripts/core/loc.gd")

const OPEN := -BoardScript.OPEN_MAX

var board: Control
var enabled := true

var _take := 0
var _audio: AudioStreamPlayer
var _clack: AudioStreamWAV
var _kind := ""
var _t := 0.0
var _dur := 0.0
var _running := false
var _steps: Array = []
var _next := 0
var _stick_from := OPEN
var _stick_to := OPEN
var _stick_t := 0.0
var _stick_dur := 0.001


func _ready() -> void:
	layer = 20
	board = BoardScript.new()
	board.name = "Board"
	add_child(board)
	board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	board.alpha = 0.0
	board.stick = OPEN

	if DisplayServer.get_name() != "headless":
		_audio = AudioStreamPlayer.new()
		_audio.name = "Clack"
		_clack = SlateAudio.clack_stream()
		_audio.stream = _clack
		_audio.volume_db = -3.0
		add_child(_audio)


func is_running() -> bool:
	return _running


## First take of a session: the board opens, shuts, clacks, says ROLL.
## Headlines ROLL./CUT!/DIE. are the game's name and stay as written; the
## corner and subline follow the language and re-render on a switch.
func play_roll(take_index: int) -> void:
	_take = take_index
	_run("roll", 1.95, [
		{"at": 0.0, "fn": func() -> void:
			board.headline = "ROLL."
			_apply_text()},
		{"at": 0.34, "fn": func() -> void:
			_animate_stick(0.0, 0.07)
			_clack_now(-3.0)},
	])


## Deliberate cut: no death wording, the player did this.
func play_cut(take_index: int) -> void:
	_take = take_index
	_run("cut", 1.35, [
		{"at": 0.0, "fn": func() -> void:
			board.headline = "CUT!"
			_apply_text()},
		{"at": 0.02, "fn": func() -> void:
			_animate_stick(0.0, 0.06)
			_clack_now(-2.0)},
	])


## Death: DIE first, then the slate shuts on it. The cause is the HUD's line,
## not the board's: two copies of it on screen at once read as two events.
func play_die(take_index: int) -> void:
	_take = take_index
	_run("die", 2.05, [
		{"at": 0.0, "fn": func() -> void:
			board.headline = "DIE."
			_apply_text()},
		{"at": 0.62, "fn": func() -> void:
			board.headline = "CUT!"
			_animate_stick(0.0, 0.06)
			_clack_now(0.0)},
	])


## Re-render the language-dependent lines of a board that is up right now.
func relocalize() -> void:
	if _running and board != null and _next > 0:
		_apply_text()
		board.queue_redraw()


func _apply_text() -> void:
	if board == null:
		return
	match _kind:
		"roll":
			board.corner = Loc.ui("slate.roll_corner", [_take])
			board.subline = Loc.ui("slate.roll_sub")
		"cut":
			board.corner = Loc.ui("slate.cut_corner", [_take])
			board.subline = ""
		"die":
			board.corner = Loc.ui("slate.die_corner", [_take])
			board.subline = ""


func play_out() -> void:
	_run("out", 0.35, [])


func hide_slate() -> void:
	_running = false
	_kind = ""
	if board != null:
		board.alpha = 0.0
		board.queue_redraw()


func _run(kind: String, dur: float, steps: Array) -> void:
	_kind = kind
	_t = 0.0
	_dur = dur
	_running = enabled
	_steps = steps
	_next = 0
	_stick_from = OPEN
	_stick_to = OPEN
	_stick_t = 0.0
	_stick_dur = 0.001
	if board == null:
		return
	board.headline = ""
	board.subline = ""
	board.corner = ""
	board.stick = OPEN
	board.alpha = 0.0
	if not enabled:
		# Slate disabled (accessibility / fast iteration): still schedule the
		# completion so the game flow is identical.
		_finish_later(dur)
		return


func _finish_later(dur: float) -> void:
	var t := get_tree().create_timer(dur)
	t.timeout.connect(func() -> void:
		var k := _kind
		_running = false
		sequence_finished.emit(k)
	)


func _animate_stick(to: float, over: float) -> void:
	_stick_from = board.stick
	_stick_to = to
	_stick_t = 0.0
	_stick_dur = maxf(over, 0.001)


func _clack_now(volume_db: float) -> void:
	if _audio == null:
		return
	_audio.volume_db = volume_db
	_audio.play()


func _process(dt: float) -> void:
	if not _running or board == null:
		return
	_t += dt

	while _next < _steps.size() and _t >= float(_steps[_next]["at"]):
		var fn: Callable = _steps[_next]["fn"]
		_next += 1
		fn.call()

	if _stick_t < _stick_dur:
		_stick_t += dt
		var a := clampf(_stick_t / _stick_dur, 0.0, 1.0)
		# fast out, hard stop: the boards hit, they do not ease.
		board.stick = lerpf(_stick_from, _stick_to, a * a)

	var fade_in := 0.10
	var fade_out := 0.30
	if _t < fade_in:
		board.alpha = _t / fade_in
	elif _t > _dur - fade_out:
		board.alpha = maxf(0.0, (_dur - _t) / fade_out)
	else:
		board.alpha = 1.0

	board.queue_redraw()

	if _t >= _dur:
		_running = false
		board.alpha = 0.0
		board.queue_redraw()
		sequence_finished.emit(_kind)
