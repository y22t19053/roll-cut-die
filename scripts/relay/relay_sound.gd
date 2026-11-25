extends Node
## Attach once to the run (not a room). The score never receives a gameplay
## transport command. A second, monophonic player articulates the edit points.
const Harmony = preload("res://scripts/ui/relay_score.gd")
const Foley = preload("res://scripts/ui/foley.gd")
const RATE := 22050
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
const PRIORITY := {"sprint":7,"light_bonus":8,"belt":1,"wire":3,"key_safe":2,"catwalk":2,"stage_turn":4,"near":0,"line":1,"draw":2,"choose":3,"pickup":4,"trap":9,"hit":10,"clear":7,"win":11}
static var _score: AudioStreamWAV
static var _cues := {}
static var _danger_stream: AudioStreamWAV
const DANGER_BEATS := 4.0
## Bed of tension: a four-beat pulse under the score. It is not a warning label;
## it says the room is being watched from somewhere close.
var _danger := AudioStreamPlayer.new()
var _danger_target := -60.0
var _ducked := false
var _act_lift := 0.0
var _act_index: int = 0
var _final_sprint: bool = false
var _still_seconds: float = 0.0
var _drive := AudioStreamPlayer.new()
var _murmur := AudioStreamPlayer.new()
static var _drive_stream: AudioStreamWAV
static var _murmur_stream: AudioStreamWAV
var _music := AudioStreamPlayer.new()
var _fx := AudioStreamPlayer.new()
var _lock_until := 0
var _rank := -1
var _last := {}
## Three states of the same four notes. The recordings in assets/audio are used
## when the project has imported them; the same parts are also synthesised here,
## so a fresh checkout still has a score.
const BED_PATHS := {"calm": "res://assets/audio/bed_calm.wav",
	"tense": "res://assets/audio/bed_tense.wav", "halt": "res://assets/audio/bed_halt.wav"}
const BED_BPM := 72.0
const BED_BEAT := 60.0 / BED_BPM
const MOTIF := [146.83, 174.61, 220.00, 261.63] # D3 F3 A3 C4
var _calm := AudioStreamPlayer.new()
var _tense := AudioStreamPlayer.new()
var _halt := AudioStreamPlayer.new()
var _calm_db := -22.0
var _tense_db := -60.0
var _beds_muted := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_music.name = "Score"
	_fx.name = "Edit"
	for p: AudioStreamPlayer in [_music,_fx,_drive,_murmur]:
		p.bus = &"Master"
		add_child(p)
	if _score == null:
		_score = _compose()
		for k: String in TUNES: _cues[k] = _sting(k)
		_cues["pickup"] = Foley.make_stream("pickup")
		_cues["trap"] = Foley.make_stream("deny")
		_cues["hit"] = Foley.make_stream("death")
		for kind: String in ["sprint", "light_bonus", "belt", "wire", "key_safe", "catwalk", "stage_turn"]:
			_cues[kind] = Foley.make_stream(kind)
		_drive_stream = _compose_drive()
		_murmur_stream = _compose_murmur()
	_drive.name = "Drive"
	_drive.stream = _drive_stream
	_drive.volume_db = -28.0
	_murmur.name = "Murmur"
	_murmur.stream = _murmur_stream
	_murmur.volume_db = -60.0
	_murmur.play()
	_music.volume_db = -11.5
	_music.stream = _score
	# Start both equal-length stems in the same audio mix block.
	_music.play()
	_drive.play()
	_danger.name = "Tension"
	_danger.bus = &"Master"
	add_child(_danger)
	if _danger_stream == null:
		_danger_stream = _compose_danger()
	_danger.stream = _danger_stream
	_danger.volume_db = -60.0
	_danger.play()
	for pair: Array in [["calm", _calm, _calm_db], ["tense", _tense, -60.0], ["halt", _halt, -60.0]]:
		var key: String = pair[0]
		var deck: AudioStreamPlayer = pair[1]
		deck.name = "Bed_%s" % key
		deck.bus = &"Master"
		add_child(deck)
		deck.stream = _bed(key)
		deck.volume_db = float(pair[2])
		if key != "halt":
			deck.play()
	_dress.name = "Dress"
	_dress.bus = &"Master"
	_dress.volume_db = -26.0
	add_child(_dress)
	_dress_fx.name = "DressHit"
	_dress_fx.bus = &"Master"
	_dress_fx.volume_db = -14.0
	add_child(_dress_fx)


## How close the nearest armed ghost is, 0..1. The score is being listened to
## from across the room or from inside it; nothing here is a rule.
func set_danger(v: float) -> void:
	if not is_node_ready() or _danger.stream == null:
		return
	var w: float = clampf(v, 0.0, 1.0)
	var target: float = -60.0 if v <= 0.01 else lerpf(-24.0, -9.0, w)
	if absf(target - _danger_target) >= 0.4:
		_danger_target = target
	# The bed changes state with the same information: one note of the world.
	if _beds_muted:
		return
	var calm_target := lerpf(-22.0, -31.0, w)
	var tense_target: float = -60.0 if w <= 0.02 else lerpf(-24.0, -12.0, w)
	# The last act never goes fully quiet: the room has been counting takes.
	tense_target += _act_lift
	if absf(calm_target - _calm_db) >= 0.5:
		_calm_db = calm_target
	if absf(tense_target - _tense_db) >= 0.5:
		_tense_db = tense_target


## The last act does not go quiet: the room has been counting takes all along.
func set_act(act_index: int) -> void:
	_act_index = clampi(act_index, 0, 3)
	_act_lift = clampf(float(act_index) * 1.4, 0.0, 3.2)


func set_final_sprint(active: bool) -> void:
	_final_sprint = active


func set_stillness(still_seconds: float) -> void:
	_still_seconds = still_seconds


func _process(delta: float) -> void:
	# One owner per gain: no accumulating per-frame volume tweens.
	var quiet: bool = _beds_muted or _ducked
	var duck_db: float = -8.5 if _ducked else 0.0
	var music_db: float = -60.0 if _beds_muted else -11.5 + duck_db
	_music.volume_db = move_toward(_music.volume_db, music_db, delta * 100.0)
	for pair: Array in [[_calm, _calm_db], [_tense, _tense_db], [_danger, _danger_target], [_dress, -26.0]]:
		var deck: AudioStreamPlayer = pair[0]
		var level: float = -60.0 if _beds_muted else maxf(-60.0, float(pair[1]) + duck_db)
		deck.volume_db = move_toward(deck.volume_db, level, delta * 140.0)
	var drive_db: float = lerpf(-28.0, -15.0, float(_act_index) / 3.0)
	if _final_sprint: drive_db += 3.5
	if _reduce_motion(): drive_db -= 12.0
	if _ducked: drive_db -= 8.5
	if _beds_muted: drive_db = -60.0
	_drive.volume_db = move_toward(_drive.volume_db, drive_db, delta * 48.0)
	var murmur_db: float = -34.0 if _still_seconds >= 2.0 and not quiet else -60.0
	_murmur.volume_db = move_toward(_murmur.volume_db, murmur_db, delta * (104.0 if quiet or _still_seconds < 0.2 else 26.0))
	_music.pitch_scale = 1.0
	_drive.pitch_scale = 1.0


## Each family of set has its own pitch for the same two beds, plus one layer of
## its own sound: the ear should place the room before the eye finishes looking.
## A strip room is bare and ticking; crates knock wood; the ring rings metal; the
## rigging thuds and chains; the vents hiss. All five are two-second loops.
static var _dress_streams := {}
var _dress := AudioStreamPlayer.new()
var _dress_fx := AudioStreamPlayer.new()

func set_family(kind: String) -> void:
	if not is_node_ready():
		return
	var p := 1.0
	match kind:
		"i": p = 1.03
		"l": p = 0.96
		"o": p = 0.92
		"h": p = 1.05
		"s": p = 1.09
	for bed: AudioStreamPlayer in [_calm, _tense]:
		if bed != null:
			bed.pitch_scale = p
	if _dress != null:
		_dress.stream = dress_for(kind)
		if not _dress.playing:
			_dress.play()


## The board is talking: step the score back so the clack is the loudest thing
## in the room, then bring it back.
func duck(on: bool) -> void:
	if not is_node_ready() or on == _ducked:
		return
	_ducked = on
	if on: _still_seconds = 0.0


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

## The bed: the recorded loop when the project has imported it, otherwise the
## same four notes rendered here. Either way the score has a state.
static func _bed(kind: String) -> AudioStream:
	var wav := _wav_on_disk(str(BED_PATHS.get(kind, "")))
	if wav == null:
		var path := str(BED_PATHS.get(kind, ""))
		if path != "" and ResourceLoader.exists(path):
			var loaded = load(path)
			if loaded is AudioStreamWAV:
				wav = (loaded as AudioStreamWAV).duplicate()
	if wav == null:
		return _compose_bed(kind)
	if kind != "halt":
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_end = roundi(wav.get_length() * wav.mix_rate)
	return wav


## Read a 16-bit PCM wav straight off disk. A build that never ran the editor
## has no import cache for these files, and the score would silently fall back
## to the synthesised version forever.
static func _wav_on_disk(path: String) -> AudioStreamWAV:
	if path == "" or not FileAccess.file_exists(path):
		return null
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.size() < 44 or bytes.slice(0, 4).get_string_from_ascii() != "RIFF":
		return null
	var at := 12
	var rate := 44100
	var channels := 1
	var bits := 16
	var data := PackedByteArray()
	while at + 8 <= bytes.size():
		var tag := bytes.slice(at, at + 4).get_string_from_ascii()
		var size := bytes.decode_u32(at + 4)
		var body := at + 8
		if tag == "fmt " and body + 16 <= bytes.size():
			channels = bytes.decode_u16(body + 2)
			rate = bytes.decode_u32(body + 4)
			bits = bytes.decode_u16(body + 14)
		elif tag == "data":
			data = bytes.slice(body, mini(body + size, bytes.size()))
			break
		at = body + size + (size & 1)
	if data.is_empty() or bits != 16:
		return null
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = channels > 1
	wav.data = data
	return wav


static func _compose_bed(kind: String) -> AudioStreamWAV:
	if kind == "halt": return _compose_halt()
	var beats := 16.0
	var buf := PackedFloat32Array()
	buf.resize(roundi(beats * BED_BEAT * RATE))
	# A pad that breathes rather than holds: three low sines and a slow swell.
	for pair: Array in [[73.42, 0.16], [110.0, 0.09], [146.83, 0.07]]:
		var step := TAU * float(pair[0]) / RATE
		for i in buf.size():
			var t := float(i) / RATE
			buf[i] += sin(step * i) * (0.75 + 0.25 * sin(TAU * 0.05 * t)) * float(pair[1])
	# The motif: four notes. Calm leaves them to ring, tense runs them short.
	var tense := kind == "tense"
	for rep in (2 if tense else 1):
		var gap := BED_BEAT * (0.5 if tense else 1.0)
		for k in MOTIF.size():
			_add_tone(buf, (float(rep) * 8.0 * BED_BEAT) + float(k) * gap, float(MOTIF[k]),
				0.9 if tense else 2.4, 0.15 if tense else 0.17)
	if tense:
		for step_i in int(beats * 2.0):
			_add_pulse(buf, float(step_i) * BED_BEAT * 0.5, 41.2 if step_i % 4 == 0 else 55.0)
	else:
		for bar in int(beats / 4.0):
			_add_tick(buf, float(bar) * 4.0 * BED_BEAT + 0.11)
	return _wav(buf, true)


## The take is over: the pad loses its pitch like a tape losing its capstan.
static func _compose_halt() -> AudioStreamWAV:
	var n := roundi(5.0 * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := 73.42 * (1.0 - 0.34 * pow(t / 5.0, 1.4))
		phase += TAU * f / RATE
		buf[i] = (sin(phase) * 0.22 + sin(phase * 2.0) * 0.08) * exp(-t / 1.6)
	return _wav(buf, false)


static func _add_tone(buf: PackedFloat32Array, at: float, freq: float, dur: float, amp: float) -> void:
	var start := roundi(at * RATE)
	var n := ceili(dur * RATE)
	var step := TAU * freq / RATE
	for i in n:
		var t := float(i) / RATE
		var s := sin(step * i) * 0.62 + sin(step * 2.0 * i) * 0.18 + sin(step * 3.01 * i) * 0.07
		var a := minf(t / 0.02, 1.0) * exp(-t / (dur * 0.45))
		buf[(start + i) % buf.size()] += s * a * amp


static func _add_pulse(buf: PackedFloat32Array, at: float, freq: float) -> void:
	var start := roundi(at * RATE)
	var n := ceili(0.34 * RATE)
	var step := TAU * freq / RATE
	for i in n:
		var t := float(i) / RATE
		var a := minf(t / 0.006, 1.0) * exp(-t / 0.09)
		buf[(start + i) % buf.size()] += sin(step * i) * a * 0.20


static func _add_tick(buf: PackedFloat32Array, at: float) -> void:
	var start := roundi(at * RATE)
	var n := ceili(0.05 * RATE)
	for i in n:
		var t := float(i) / RATE
		var a := exp(-t / 0.008)
		buf[(start + i) % buf.size()] += (sin(TAU * 180.0 * t) * 0.5 + sin(TAU * 2400.0 * t) * 0.2) * a * 0.06


static func _add_rub(buf: PackedFloat32Array, at: float, dur: float, amp: float, cut: float) -> void:
	var start := roundi(at * RATE)
	var n := ceili(dur * RATE)
	var low := 0.0
	var a := clampf(cut / RATE * TAU, 0.0, 1.0)
	for i in n:
		var noise := randf() * 2.0 - 1.0
		low += (noise - low) * a
		var t := float(i) / RATE
		var env := minf(t / 0.15, 1.0) * minf((dur - t) / 0.2, 1.0)
		buf[(start + i) % buf.size()] += low * env * amp


## One two-second loop per family, synthesised at load time — the ear should place
## the room before the eye finishes looking. Nothing extra ships for this layer.
static func dress_for(kind: String) -> AudioStreamWAV:
	if _dress_streams.has(kind):
		return _dress_streams[kind]
	var n := roundi(2.0 * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	match kind:
		"i":
			_add_tick(buf, 1.00)
		"l":
			_add_pulse(buf, 0.20, 180.0)
			_add_tick(buf, 0.21)
			_add_pulse(buf, 0.95, 150.0)
			_add_tick(buf, 0.96)
		"o":
			_add_tone(buf, 0.25, 880.0, 1.60, 0.16)
			_add_tone(buf, 0.25, 1320.0, 1.60, 0.09)
		"h":
			_add_pulse(buf, 0.30, 82.0)
			for i: int in 4:
				_add_tick(buf, 0.34 + float(i) * 0.05)
			_add_pulse(buf, 1.30, 70.0)
		"s":
			_add_rub(buf, 0.0, 1.95, 0.05, 700.0)
	var wav := _wav(buf, true)
	_dress_streams[kind] = wav
	return wav


## The same voice, once, when you actually brush past the thing that owns it. The
## loop tells you which room you are in; this tells you where in the room you are.
static func hit_for(kind: String) -> AudioStreamWAV:
	var key := "hit_" + kind
	if _dress_streams.has(key):
		return _dress_streams[key]
	var n := roundi(0.9 * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	match kind:
		"i":
			_add_tick(buf, 0.02)
		"l":
			_add_pulse(buf, 0.02, 180.0)
			_add_tick(buf, 0.03)
			_add_pulse(buf, 0.16, 150.0)
		"o":
			_add_tone(buf, 0.02, 1180.0, 0.80, 0.20)
			_add_tone(buf, 0.02, 1770.0, 0.70, 0.10)
		"h":
			_add_pulse(buf, 0.02, 82.0)
			for i: int in 3:
				_add_tick(buf, 0.10 + float(i) * 0.055)
		"s":
			_add_rub(buf, 0.02, 0.70, 0.07, 900.0)
	var wav := _wav(buf, false)
	_dress_streams[key] = wav
	return wav


## Brush the crates / the ring / the rail: one shot, no repeat inside a second.
func family_hit(kind: String) -> void:
	if not is_node_ready(): return
	var now := Time.get_ticks_msec()
	if now - int(_last.get("dress", -1000)) < 900: return
	_last["dress"] = now
	_dress_fx.stream = hit_for(kind)
	_dress_fx.play()


func cue(kind: String) -> void:
	if not is_node_ready() or not _cues.has(kind): return
	var now := Time.get_ticks_msec()
	var refractory: int = 1200 if kind in ["belt", "key_safe"] else (850 if kind == "near" else 100)
	if now - int(_last.get(kind,-1200)) < refractory: return
	if now < _lock_until and int(PRIORITY[kind]) < _rank: return
	_rank = PRIORITY[kind]
	_lock_until = now + (650 if kind == "light_bonus" else (300 if kind in ["clear","win"] else 100))
	_last[kind] = now
	if kind == "hit" or kind == "trap":
		_halt_bed()
	elif kind == "win":
		_mute_beds()
	_fx.stream = _cues[kind]
	_fx.volume_db = -4 if kind != "near" else -8
	_fx.play()


## A collision stops the bed: the room goes quiet under the board.
func _halt_bed() -> void:
	_beds_muted = true
	_still_seconds = 0.0
	_calm_db = -60.0
	_tense_db = -60.0
	_halt.volume_db = -11.0
	_halt.play()


func _mute_beds() -> void:
	_beds_muted = true
	_still_seconds = 0.0
	_calm_db = -60.0
	_tense_db = -60.0


## A new take brings the room back; the score picks up where the room is.
func resume_beds() -> void:
	if not is_node_ready(): return
	_beds_muted = false
	_still_seconds = 0.0
	_halt.stop()
	_calm_db = -22.0
	_tense_db = -60.0
	_danger_target = -60.0
	if not _calm.playing: _calm.play()
	if not _tense.playing: _tense.play()

static func _compose() -> AudioStreamWAV:
	var buf := PackedFloat32Array()
	buf.resize(roundi(32*BEAT*RATE))
	var bank: Dictionary = {}
	for chord: Array in Harmony.CHORDS:
		var count: int = int(chord[1])
		var tones: Array = chord[3]
		var root: int = int(chord[2])
		var start: float = float(chord[0]) * BEAT
		for tone: int in tones:
			_lay(buf, bank, start, tone, 3, 0.12, float(count) * BEAT + 0.3)
		for b: int in count:
			var at: float = start + float(b) * BEAT
			if b % 4 == 0: _lay(buf, bank, at, root, 0, 0.48)
			if b % 4 == 2: _lay(buf, bank, at + 0.5 * BEAT, root + 7, 0, 0.25)
			if b % 4 == 3: _lay(buf, bank, at, root + 12, 0, 0.22)
			_lay(buf, bank, at + 0.5 * BEAT, int(tones[b % tones.size()]), 1, 0.26)
			if b % 2 == 1: _lay(buf, bank, at + 0.75 * BEAT, int(tones[0]) + 12, 1, 0.12)
	for n: Array in ANSWERS: _lay(buf, bank, float(n[0]) * BEAT, int(n[1]), 2, float(n[2]))
	_normalize(buf, 0.82)
	return _wav(buf, true)


static func _normalize(buf: PackedFloat32Array, level: float) -> void:
	var peak: float = 0.001
	for sample: float in buf: peak = maxf(peak, absf(sample))
	for i: int in buf.size(): buf[i] *= level / peak


static func _compose_drive() -> AudioStreamWAV:
	var buf := PackedFloat32Array()
	buf.resize(roundi(32.0 * BEAT * RATE))
	var rng := RandomNumberGenerator.new()
	rng.seed = 10832
	for beat: int in 128:
		var start: int = roundi(float(beat) * BEAT * 0.25 * RATE)
		var gain: float = 0.32 if beat % 2 == 0 else 0.10
		for i: int in roundi(0.065 * RATE):
			var t: float = float(i) / RATE
			var click: float = rng.randf_range(-1.0, 1.0) * 0.4 + sin(TAU * 1650.0 * t) * 0.3
			buf[(start + i) % buf.size()] += click * exp(-t * 95.0) * minf(t / 0.002, 1.0) * gain
		if beat % 4 == 0: _add_pulse(buf, float(beat) * BEAT * 0.25, 73.416)
	# Upper chord tones brighten gently as the act raises this stem, in tune.
	var bank: Dictionary = {}
	for chord: Array in Harmony.CHORDS:
		var tones: Array = chord[3]
		for step: int in int(float(chord[1]) * 2.0):
			_lay(buf, bank, (float(chord[0]) + float(step) * 0.5) * BEAT, int(tones[step % tones.size()]) + 12, 1, 0.045)
	_normalize(buf, 0.72)
	return _wav(buf, true)


static func _compose_murmur() -> AudioStreamWAV:
	var buf := PackedFloat32Array()
	var n: int = roundi(6.0 * RATE)
	buf.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 620280
	var brown: float = 0.0
	var low_a: float = 0.0
	var band_a: float = 0.0
	var low_b: float = 0.0
	var band_b: float = 0.0
	var fa: float = 2.0 * sin(PI * 310.0 / RATE)
	var fb: float = 2.0 * sin(PI * 570.0 / RATE)
	# Warm noise through two damped state-variable formant bandpasses.
	for i: int in n:
		var t: float = float(i) / RATE
		brown = brown * 0.96 + rng.randf_range(-1.0, 1.0) * 0.04
		low_a += fa * band_a
		band_a += fa * (brown - low_a - 0.48 * band_a)
		low_b += fb * band_b
		band_b += fb * (brown - low_b - 0.55 * band_b)
		var syllable: float = pow(0.5 + 0.5 * sin(TAU * 4.5 * t + 0.7 * sin(TAU * t / 3.0)), 2.0)
		var phrase: float = 0.3 + 0.7 * pow(0.5 + 0.5 * sin(TAU * t / 2.0), 2.0)
		var seam: float = smoothstep(0.0, 0.15, t) * smoothstep(0.0, 0.15, 6.0 - t)
		buf[i] = (band_a + band_b * 0.65) * syllable * phrase * seam
	_normalize(buf, 0.60)
	return _wav(buf, true)

static func _sting(kind: String) -> AudioStreamWAV:
	var notes: Array = TUNES[kind]
	var buf := PackedFloat32Array()
	var voice: int = 1 if kind in ["draw","near","choose"] else 2
	buf.resize(ceili((float(notes.back()[0])+_length(voice))*RATE)+2)
	var bank := {}
	for n: Array in notes: _lay(buf,bank,n[0],n[1],voice,n[2])
	return _wav(buf,false)

static func _length(voice: int) -> float:
	return float([0.85,0.24,0.70,4.0 * BEAT + 0.3][voice])

static func _lay(buf: PackedFloat32Array, bank: Dictionary, at: float, midi: int, voice: int, amp: float, duration: float = -1.0) -> void:
	var length: float = duration if duration > 0.0 else _length(voice)
	var key: String = "%d:%d:%.4f" % [midi, voice, length]
	if not bank.has(key):
		var note := PackedFloat32Array()
		note.resize(ceili(length*RATE))
		var step := TAU*440*pow(2.0,(midi-69)/12.0)/RATE
		for i in note.size():
			var t := float(i)/RATE
			var ph := step*i
			var tone := sin(ph)
			if voice == 0: tone += 0.33*sin(2*ph) # rounded, felt-covered bass
			elif voice == 1: tone += 0.52*sin(3.01*ph)*exp(-40*t) # dry wood
			elif voice == 3: tone += 0.28 * sin(2.0 * ph) + 0.10 * sin(3.0 * ph)
			else: tone += 0.30*sin(4.02*ph)*exp(-16*t) # bright gate tine
			note[i] = tone*exp(-4*t/length)*minf(t/0.004,1)*minf((note.size()-1-i)/120.0,1)
			if voice == 3:
				note[i] = tone * minf(t / 0.22, 1.0) * minf((length - t) / 0.45, 1.0) * 0.65
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


func _reduce_motion() -> bool:
	# Resolve at runtime: these scripts are also preloaded by standalone tests.
	var session: Node = get_node_or_null("/root/GameSession")
	if session == null: return false
	var settings: Dictionary = session.get("settings")
	return bool(settings.get("reduce_motion", false))
