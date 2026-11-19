extends RefCounted
## SlateAudio — the CLACK, synthesised so the repo carries no binary asset it
## cannot regenerate.
##
## Shape of the sound: a very short noise transient (the boards touching), two
## resonant partials around 315 Hz and 1.18 kHz (the echo inside the wood), and
## a fast exponential tail so repeated deaths never turn into a drone.

const RATE := 44100


static func clack_stream(duration: float = 0.075) -> AudioStreamWAV:
	var n := int(RATE * duration)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x51A7E
	for i in n:
		var t := float(i) / float(RATE)
		var wood := exp(-t * 52.0)
		var click := exp(-t * 380.0)
		var body := sin(TAU * 315.0 * t) * 0.55 + sin(TAU * 1180.0 * t) * 0.28
		var noise := rng.randf_range(-1.0, 1.0)
		var s := (body * wood + noise * click * 0.75) * 0.72
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32000.0))
	var st := AudioStreamWAV.new()
	st.format = AudioStreamWAV.FORMAT_16_BITS
	st.mix_rate = RATE
	st.stereo = false
	st.data = data
	return st
