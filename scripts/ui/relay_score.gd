extends RefCounted
## RelayScore — the title's original score, composed here and rendered to PCM
## at runtime (no audio asset). Eight bars in D minor at 80 BPM, 24 s, seamless
## loop: a mallet melody whose opening phrase is handed up a third in bar 3
## (the relay), over a soft pad and bass, with an optional eighth-note pulse.
##
## Two stems of identical length so the player can drop the pulse (Reduce
## motion) without re-rendering:
##   "bed"   — pad, bass, melody
##   "pulse" — arpeggiated chord tones
##
## render() is pure computation on local buffers, safe to run on a Thread.
## Set `cancelled` from the main thread to make it return early (empty).

const RATE := 22050
const BEAT := 0.75  # seconds, 80 BPM
const BEATS := 32   # 8 bars of 4/4

enum Voice { PAD, BASS, MALLET, PLUCK }

## [start beat, length in beats, bass note, pad notes] — MIDI numbers.
const CHORDS := [
	[0.0, 4.0, 38, [53, 57, 60, 64]],   # Dm9
	[4.0, 4.0, 34, [53, 57, 58, 62]],   # Bbmaj7
	[8.0, 4.0, 41, [53, 55, 57, 60]],   # Fadd9
	[12.0, 4.0, 40, [52, 55, 60, 62]],  # Cadd9/E
	[16.0, 4.0, 38, [53, 57, 60, 64]],  # Dm9
	[20.0, 4.0, 43, [53, 57, 58, 62]],  # Gm9
	[24.0, 4.0, 34, [50, 53, 57, 62]],  # Bbmaj7
	[28.0, 2.0, 33, [52, 57, 62]],      # Asus4
	[30.0, 2.0, 33, [52, 57, 61]],      # A  -> back to Dm
]

## [beat, MIDI note, accent 0..1]
const MELODY := [
	[0.0, 69, 0.8], [1.0, 74, 0.9], [2.0, 76, 0.8], [2.5, 77, 0.9], [3.0, 76, 0.7],
	[4.0, 74, 1.0], [6.0, 69, 0.6], [7.0, 70, 0.7],
	[8.0, 72, 0.8], [9.0, 77, 0.9], [10.0, 79, 0.8], [10.5, 81, 1.0], [11.0, 79, 0.7],
	[12.0, 76, 1.0], [14.0, 74, 0.6], [15.0, 72, 0.6],
	[16.0, 69, 0.8], [17.0, 74, 0.9], [18.0, 76, 0.8], [18.5, 77, 0.9], [19.0, 81, 1.0],
	[20.0, 79, 0.9], [21.5, 77, 0.7], [22.0, 74, 0.8], [23.0, 70, 0.6],
	[24.0, 69, 0.7], [25.0, 74, 0.8], [26.0, 77, 0.9], [27.0, 76, 0.8],
	[28.0, 74, 1.0], [30.0, 73, 0.8],
]

var cancelled := false


## Returns {"bed": PackedByteArray, "pulse": PackedByteArray} of 16-bit mono
## PCM at RATE, or {} when cancelled.
func render() -> Dictionary:
	var n := int(BEATS * BEAT * RATE)
	var bed := PackedFloat32Array()
	bed.resize(n)
	var pulse := PackedFloat32Array()
	pulse.resize(n)
	for chord: Array in CHORDS:
		var at: float = chord[0] * BEAT
		var dur: float = chord[1] * BEAT
		_note(bed, at, int(chord[2]), dur, 0.55, Voice.BASS)
		var tones: Array = chord[3]
		for tone: int in tones:
			_note(bed, at, tone, dur, 0.2, Voice.PAD)
		# Eighth notes rocking up and back through the chord.
		var steps := int(chord[1] * 2.0)
		for i in steps:
			var idx := i % (tones.size() * 2 - 2)
			if idx >= tones.size():
				idx = tones.size() * 2 - 2 - idx
			var amp := 0.5 if i % 2 == 0 else 0.36
			_note(pulse, at + i * BEAT * 0.5, int(tones[idx]) + 12, 0.0, amp, Voice.PLUCK)
		if cancelled:
			return {}
	for m: Array in MELODY:
		_note(bed, float(m[0]) * BEAT, int(m[1]), 0.0, 0.5 * float(m[2]), Voice.MALLET)
		if cancelled:
			return {}
	# One shared gain so the stems keep their written balance.
	var peak := 0.001
	for i in n:
		peak = maxf(peak, absf(bed[i]) + absf(pulse[i]))
	var gain := 0.85 / peak
	return {"bed": _pcm(bed, gain), "pulse": _pcm(pulse, gain)}


static func to_stream(pcm: PackedByteArray) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = pcm
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = pcm.size() / 2
	return wav


## Adds one note; tails wrap past the end so the loop is seamless.
func _note(buf: PackedFloat32Array, at: float, midi: int, dur: float, amp: float, voice: Voice) -> void:
	var n := buf.size()
	var freq := 440.0 * pow(2.0, (midi - 69) / 12.0)
	var step := TAU * freq / RATE
	var length := 0.0
	match voice:
		Voice.PAD:
			length = dur + 1.0
		Voice.BASS:
			length = dur + 0.4
		Voice.MALLET:
			length = 1.9
		Voice.PLUCK:
			length = 0.55
	var count := int(length * RATE)
	var start := int(at * RATE)
	var ph := 0.0
	for i in count:
		var t := float(i) / RATE
		var env := 0.0
		var s := 0.0
		match voice:
			Voice.PAD:
				env = minf(t / 0.6, 1.0)
				if t > dur:
					var r := 1.0 - (t - dur)
					env *= r * r
				s = sin(ph) + 0.22 * sin(ph * 2.0)
			Voice.BASS:
				env = minf(t / 0.08, 1.0)
				if t > dur:
					env *= 1.0 - (t - dur) / 0.4
				s = sin(ph) + 0.45 * sin(ph * 2.0) + 0.15 * sin(ph * 3.0)
			Voice.MALLET:
				# Felt mallet: soft attack, bright partial that dies first.
				env = minf(t / 0.006, 1.0) * exp(-t * 2.6) * (1.0 - t / length)
				s = sin(ph) + 0.3 * exp(-t * 9.0) * sin(ph * 4.0)
			Voice.PLUCK:
				env = minf(t / 0.008, 1.0) * exp(-t * 7.0) * (1.0 - t / length)
				s = sin(ph) + 0.18 * sin(ph * 2.0)
		buf[(start + i) % n] += s * env * amp
		ph += step


static func _pcm(buf: PackedFloat32Array, gain: float) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(buf.size() * 2)
	for i in buf.size():
		out.encode_s16(i * 2, int(clampf(buf[i] * gain, -1.0, 1.0) * 32767.0))
	return out
