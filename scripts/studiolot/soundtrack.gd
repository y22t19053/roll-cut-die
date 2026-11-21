extends Node
## Quiet original felt-mallet score and a shutter/motor loop, both on Master.
## Add an instance to the lot; set_screening(true) when projection starts.
const SCORE := preload("res://assets/audio/studiolot/after_wrap.res")
const GATE := preload("res://assets/audio/studiolot/projector_gate.res")
const FLOOR_DB := -60.0
var _score: AudioStreamPlayer
var _gate: AudioStreamPlayer
var _fade: Tween
var _screening := false

func _ready() -> void:
	_score = _player(SCORE)
	_gate = _player(GATE)
	_score.play()
	_mix()

func _player(source: AudioStreamOggVorbis) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = source # Native resources already contain their Vorbis packets and loop flag.
	p.bus = &"Master"
	p.volume_db = FLOOR_DB
	add_child(p)
	return p

func set_screening(active: bool) -> void:
	if active == _screening:
		return
	_screening = active
	if _score != null:
		_mix()

func _mix() -> void:
	if _fade != null:
		_fade.kill()
	if _screening and not _gate.playing:
		_gate.play()
	_fade = create_tween().set_parallel(true)
	_fade.tween_property(_score, "volume_db", -24.0 if _screening else -19.0, 0.6)
	_fade.tween_property(_gate, "volume_db", -19.0 if _screening else FLOOR_DB, 0.4)
	if not _screening:
		_fade.chain().tween_callback(_gate.stop)
