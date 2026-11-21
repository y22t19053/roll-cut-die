extends Node
## NightStageMusic — plays the title's original score (RelayScore), rendered
## off the main thread at startup and faded in quietly once ready.
##
## Both stems play on Master, so the saved mute / volume
## (GameSession.apply_engine_settings) govern them from the first sample and
## follow any change made in Settings at once. `still` (Reduce motion) drops
## the eighth-note pulse and leaves the slow bed: pad, bass and melody.

const RelayScore = preload("res://scripts/ui/relay_score.gd")

const FLOOR_DB := -60.0
const BED_DB := -15.0
const PULSE_DB := -21.0
const FADE_IN := 2.4

## Reduce motion: no rhythmic pulse. Safe to set before or after _ready.
var still := false:
	set(value):
		still = value
		_fade_pulse(0.8)

var _score: RelayScore
var _thread: Thread
var _bed: AudioStreamPlayer
var _pulse: AudioStreamPlayer
var _fade: Tween
var _pulse_fade: Tween
var _wanted := true


func _ready() -> void:
	_bed = _make_player("Bed")
	_pulse = _make_player("Pulse")
	_score = RelayScore.new()
	_thread = Thread.new()
	if _thread.start(_score.render) != OK:
		_thread = null
		set_process(false)


func _make_player(player_name: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.name = player_name
	p.bus = &"Master"
	p.volume_db = FLOOR_DB
	add_child(p)
	return p


## Polls the render thread; streams are built on the main thread.
func _process(_delta: float) -> void:
	if _thread == null or _thread.is_alive():
		return
	var data: Dictionary = _thread.wait_to_finish()
	_thread = null
	set_process(false)
	if data.is_empty():
		return
	_bed.stream = RelayScore.to_stream(data["bed"])
	_pulse.stream = RelayScore.to_stream(data["pulse"])
	if _wanted:
		start()


func start() -> void:
	_wanted = true
	if _bed == null or _bed.stream == null or _bed.playing:
		return
	_bed.volume_db = FLOOR_DB
	_pulse.volume_db = FLOOR_DB
	# Same frame, same mix buffer: the stems stay sample-aligned.
	_bed.play()
	_pulse.play()
	if _fade != null:
		_fade.kill()
	_fade = create_tween()
	_fade.tween_property(_bed, "volume_db", BED_DB, FADE_IN)
	_fade_pulse(FADE_IN)


func _fade_pulse(seconds: float) -> void:
	if _pulse == null or not _pulse.playing or not is_inside_tree():
		return
	if _pulse_fade != null:
		_pulse_fade.kill()
	_pulse_fade = create_tween()
	_pulse_fade.tween_property(_pulse, "volume_db", FLOOR_DB if still else PULSE_DB, seconds)


## Cut at once: called before a scene change and again when leaving the tree.
func halt() -> void:
	_wanted = false
	for t: Tween in [_fade, _pulse_fade]:
		if t != null:
			t.kill()
	_fade = null
	_pulse_fade = null
	if _bed != null:
		_bed.stop()
		_pulse.stop()


func _exit_tree() -> void:
	halt()
	# The render checks `cancelled` between notes, so this join is brief.
	if _thread != null:
		_score.cancelled = true
		_thread.wait_to_finish()
		_thread = null
