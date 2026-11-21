extends Node
## Attach once to the run (not a room). The score never receives a gameplay
## transport command. A second, monophonic player articulates the edit points.
const Harmony = preload("res://scripts/ui/relay_score.gd")
const Foley = preload("res://scripts/ui/foley.gd")
const RATE := 16000
const BPM := 108.0
const BEAT := 60.0 / BPM
# beat, pitch, level. Short answers to the title's D-minor mallet phrase;
# alternating register says 'out / back' without tracking the runner's speed.
const ANSWERS := [[1.5,69,0.18],[2.25,74,0.20],[3.5,72,0.15],
	[6.5,69,0.18],[7.25,65,0.16],[9.5,72,0.18],[10.25,77,0.20],
	[11.5,76,0.14],[14.5,67,0.16],[15.25,64,0.16],
	[17.5,69,0.19],[18.25,74,0.22],[19.5,77,0.16],
	[22.5,74,0.16],[23.25,70,0.16],[25.5,65,0.16],[26.25,69,0.19],
	[27.5,74,0.14],[29.5,69,0.14],[30.5,73,0.16]]
const TUNES := {
	"line": [[0,74,0.28],[0.07,81,0.35]], # two passes through a film gate
	"near": [[0,79,0.12],[0.04,76,0.09]],
	"draw": [[0,62,0.12],[0.045,65,0.18],[0.09,69,0.24]],
	"choose": [[0,69,0.29],[0.055,62,0.35]],
	"clear": [[0,62,0.32],[0.10,69,0.32],[0.22,74,0.40]],
	"win": [[0,62,0.35],[0.14,65,0.31],[0.28,69,0.34],[0.54,74,0.42],[0.54,65,0.19]]}
const PRIORITY := {"near":0,"line":1,"draw":2,"choose":3,"pickup":4,"trap":5,"hit":6,"clear":7,"win":8}
static var _score: AudioStreamWAV
static var _cues := {}
static var _danger_stream: AudioStreamWAV
const DANGER_BEATS := 4.0
## Bed of tension: a four-beat pulse under the score. It is not a warning label;
## it says the room is being watched from somewhere close.
var _danger := AudioStreamPlayer.new()
var _danger_target := -60.0
var _ducked := false
var _music := AudioStreamPlayer.new()
var _fx := AudioStreamPlayer.new()
var _lock_until := 0
var _rank := -1
var _last := {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_music.name = "Score"
	_fx.name = "Edit"
	for p in [_music,_fx]:
		p.bus = &"Master"
		add_child(p)
	if _score == null:
		_score = _compose()
		for k: String in TUNES: _cues[k] = _sting(k)
		_cues["pickup"] = Foley.make_stream("pickup")
		_cues["trap"] = Foley.make_stream("deny")
		_cues["hit"] = Foley.make_stream("death")
	_music.volume_db = -12.0
	_music.stream = _score
	_music.play()
	_danger.name = "Tension"
	_danger.bus = &"Master"
	add_child(_danger)
	if _danger_stream == null:
		_danger_stream = _compose_danger()
	_danger.stream = _danger_stream
	_danger.volume_db = -60.0
	_danger.play()


## How close the nearest armed ghost is, 0..1. The score is being listened to
## from across the room or from inside it; nothing here is a rule.
func set_danger(v: float) -> void:
	if not is_node_ready() or _danger.stream == null:
		return
	var target := -60.0 if v <= 0.01 else lerpf(-24.0, -9.0, clampf(v, 0.0, 1.0))
	if absf(target - _danger_target) < 0.4:
		return
	_danger_target = target
	create_tween().tween_property(_danger, "volume_db", target, 0.22)


## The board is talking: step the score back so the clack is the loudest thing
## in the room, then bring it back.
func duck(on: bool) -> void:
	if not is_node_ready() or on == _ducked:
		return
	_ducked = on
	var target := -20.0 if on else -12.0
	create_tween().tween_property(_music, "volume_db", target, 0.18)


static func _compose_danger() -> AudioStreamWAV:
	var buf := PackedFloat32Array()
	buf.resize(roundi(DANGER_BEATS * BEAT * RATE))
	for b in int(DANGER_BEATS):
		var at := roundi(float(b) * BEAT * RATE)
		var n := ceili(0.42 * RATE)
		for i in n:
			var t := float(i) / RATE
			var s := sin(TAU * 55.0 * t) * 0.55 + sin(TAU * 82.5 * t) * 0.22
			if b % 2 == 1:
				s += sin(TAU * 1760.0 * t) * exp(-90.0 * t) * 0.25
			buf[(at + i) % buf.size()] += s * exp(-9.0 * t) * minf(t / 0.004, 1.0) * 0.5
	return _wav(buf, true)

func cue(kind: String) -> void:
	if not is_node_ready() or not _cues.has(kind): return
	var now := Time.get_ticks_msec()
	var refractory := 850 if kind == "near" else 100
	if now - int(_last.get(kind,-1000)) < refractory: return
	if now < _lock_until and int(PRIORITY[kind]) < _rank: return
	_rank = PRIORITY[kind]
	_lock_until = now + (300 if kind in ["clear","win"] else 100)
	_last[kind] = now
	_fx.stream = _cues[kind]
	_fx.volume_db = -4 if kind != "near" else -8
	_fx.play()

static func _compose() -> AudioStreamWAV:
	var buf := PackedFloat32Array()
	buf.resize(roundi(32*BEAT*RATE))
	# Render each pitched instrument once; lay out its notes by offset. The
	# loop owns one clock, including note tails that cross bar eight into one.
	var bank := {}
	for chord: Array in Harmony.CHORDS:
		var count := int(chord[1])
		var tones: Array = chord[3]
		for b in count:
			var at := (float(chord[0])+b)*BEAT
			if b % 2 == 0: _lay(buf,bank,at,chord[2],0,0.36)
			_lay(buf,bank,at+0.5*BEAT,tones[b%tones.size()],1,0.22)
			if b % 2 == 1: _lay(buf,bank,at+0.75*BEAT,tones[0]+12,1,0.09)
	for n: Array in ANSWERS: _lay(buf,bank,n[0]*BEAT,n[1],2,n[2])
	return _wav(buf,true)

static func _sting(kind: String) -> AudioStreamWAV:
	var notes: Array = TUNES[kind]
	var buf := PackedFloat32Array()
	var voice := 1 if kind in ["draw","near","choose"] else 2
	buf.resize(ceili((float(notes.back()[0])+_length(voice))*RATE)+2)
	var bank := {}
	for n: Array in notes: _lay(buf,bank,n[0],n[1],voice,n[2])
	return _wav(buf,false)

static func _length(voice: int) -> float:
	return [0.49,0.16,0.42][voice]

static func _lay(buf: PackedFloat32Array, bank: Dictionary, at: float, midi: int, voice: int, amp: float) -> void:
	var key := midi*3+voice
	if not bank.has(key):
		var note := PackedFloat32Array()
		note.resize(ceili(_length(voice)*RATE))
		var step := TAU*440*pow(2.0,(midi-69)/12.0)/RATE
		for i in note.size():
			var t := float(i)/RATE
			var ph := step*i
			var tone := sin(ph)
			if voice == 0: tone += 0.33*sin(2*ph) # rounded, felt-covered bass
			elif voice == 1: tone += 0.52*sin(3.01*ph)*exp(-40*t) # dry wood
			else: tone += 0.30*sin(4.02*ph)*exp(-16*t) # bright gate tine
			note[i] = tone*exp(-4*t/_length(voice))*minf(t/0.004,1)*minf((note.size()-1-i)/120.0,1)
		bank[key] = note
	var note: PackedFloat32Array = bank[key]
	var offset := roundi(at*RATE)
	for i in note.size(): buf[(offset+i)%buf.size()] += note[i]*amp

static func _wav(buf: PackedFloat32Array, looped: bool) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(buf.size()*2)
	for i in buf.size(): bytes.encode_s16(i*2,roundi(clampf(buf[i],-1,1)*32767))
	var wav := AudioStreamWAV.new()
	wav.mix_rate = RATE
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.data = bytes
	if looped:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_end = buf.size()
	return wav
