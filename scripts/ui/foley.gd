extends Node
## Foley — the small sounds the HUD makes when it says something.
##
## Like the slate's CLACK, every cue is synthesised at start-up: the repo
## carries no audio asset and nothing is written to disk. Each cue is a few
## hundredths of a second, mono, and deliberately quieter than the CLACK so the
## slate stays the loudest thing on the set.
##
## Players are left on the default (Master) bus, so the master volume and mute
## settings govern them with no extra wiring.
##
##   inspect  two light glassy blips, rising   — a lens finding focus
##   pickup   a soft thump under a short glide  — something pocketed
##   mark     two dry taps with a bright ping   — tape laid on the floor
##   deny     two blunt low knocks              — the set says no
##   death    a falling sub thud                — under the DIE slate, not over it
##   message  one small tick                    — any other banner line

const RATE := 44100
const VOICES := 3
## Two requests for the same cue closer than this are one event.
const RETRIGGER_MS := 70

const INSPECT := "inspect"
const PICKUP := "pickup"
const MARK := "mark"
const DENY := "deny"
const DEATH := "death"
const MESSAGE := "message"
const SPLICE := "splice"
const KINDS := [INSPECT, PICKUP, MARK, DENY, DEATH, MESSAGE, SPLICE]

const _LENGTH := {
	INSPECT: 0.13, PICKUP: 0.19, MARK: 0.24, DENY: 0.20, DEATH: 0.55, MESSAGE: 0.06, SPLICE: 0.22,
}
const _VOLUME_DB := {
	INSPECT: -13.0, PICKUP: -9.0, MARK: -8.0, DENY: -11.0, DEATH: -6.0, MESSAGE: -16.0, SPLICE: -10.0,
}

## False silences every cue without touching the bus.
var enabled := true

var _streams := {}
var _voices: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _last_ms := {}


func _ready() -> void:
	# Headless runs have no audio device; skip the synthesis and the players.
	if DisplayServer.get_name() == "headless":
		return
	for kind: String in KINDS:
		_streams[kind] = make_stream(kind)
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.name = "Voice%d" % i
		add_child(p)
		_voices.append(p)


## Play one cue. Returns true when a voice actually started.
func play(kind: String) -> bool:
	if not enabled or _voices.is_empty() or not _streams.has(kind):
		return false
	var now := Time.get_ticks_msec()
	if _last_ms.has(kind) and now - int(_last_ms[kind]) < RETRIGGER_MS:
		return false
	_last_ms[kind] = now
	var p := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	p.stream = _streams[kind]
	p.volume_db = float(_VOLUME_DB[kind])
	p.play()
	return true


static func length_of(kind: String) -> float:
	return float(_LENGTH.get(kind, 0.0))


## Build one cue as a 16-bit mono stream. Deterministic: same kind, same bytes.
static func make_stream(kind: String) -> AudioStreamWAV:
	var n := int(RATE * length_of(kind))
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 0xF01E7 + KINDS.find(kind)
	var total := length_of(kind)
	for i in n:
		var t := float(i) / float(RATE)
		var noise := rng.randf_range(-1.0, 1.0)
		var s := 0.0
		match kind:
			INSPECT:
				s = _blip(t, 0.0, 1320.0, 60.0) * 0.5 + _blip(t, 0.055, 1760.0, 55.0) * 0.5
			PICKUP:
				# Cloth thump, then a glide up a fifth as the hand closes.
				var thump := sin(TAU * 170.0 * t) * exp(-t * 48.0) * 0.7
				var cloth := noise * exp(-t * 240.0) * 0.22
				# 660 Hz rising to 990 Hz over `gd`, then held; `gp` integrates it.
				var gt := maxf(t - 0.03, 0.0)
				var gd := 0.10
				var up := minf(gt, gd)
				var gp := TAU * (660.0 * gt + 330.0 * up * up / (2.0 * gd) + 330.0 * maxf(gt - gd, 0.0))
				var glide := (sin(gp) + sin(gp * 2.0) * 0.25) * exp(-gt * 22.0) * 0.42
				s = thump + cloth + glide
			MARK:
				s = _tap(t, 0.0, noise, 0.8) + _tap(t, 0.085, noise, 1.0)
				var pt := t - 0.085
				if pt >= 0.0:
					s += (sin(TAU * 1568.0 * pt) * 0.30 + sin(TAU * 2349.0 * pt) * 0.12) * exp(-pt * 26.0)
			DENY:
				s = _knock(t, 0.0) + _knock(t, 0.095) * 0.85
			DEATH:
				# 110 Hz falling to 45 Hz; phase is the integral of that curve.
				var ph := TAU * (45.0 * t + 65.0 * (1.0 - exp(-9.0 * t)) / 9.0)
				var sub := (sin(ph) + sin(ph * 2.0) * 0.18) * exp(-t * 7.5) * 0.9
				var dust := noise * exp(-t * 90.0) * 0.16
				s = sub + dust
			SPLICE:
				# Film tears, the splicer closes, then the sprockets catch again.
				s = noise * exp(-t * 92.0) * 0.58 + _tap(t, 0.052, noise, 0.95)
				for j in 4:
					s += _tap(t, 0.104 + 0.023 * j, noise, 0.30 - j * 0.045)
			MESSAGE:
				s = sin(TAU * 988.0 * t) * exp(-t * 85.0) * 0.6
		# 2 ms in, 6 ms out: no click at either end of the buffer.
		var edge := minf(minf(t / 0.002, (total - t) / 0.006), 1.0)
		s *= maxf(edge, 0.0) * 0.8
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32000.0))
	var st := AudioStreamWAV.new()
	st.format = AudioStreamWAV.FORMAT_16_BITS
	st.mix_rate = RATE
	st.stereo = false
	st.data = data
	return st


## A glassy sine blip starting at `at`, with a faint octave above it.
static func _blip(t: float, at: float, hz: float, decay: float) -> float:
	var u := t - at
	if u < 0.0:
		return 0.0
	return (sin(TAU * hz * u) + sin(TAU * hz * 2.0 * u) * 0.2) * exp(-u * decay) * minf(u / 0.003, 1.0)


## A dry tap: a grain of noise over a short woody partial.
static func _tap(t: float, at: float, noise: float, gain: float) -> float:
	var u := t - at
	if u < 0.0:
		return 0.0
	return (noise * exp(-u * 420.0) * 0.45 + sin(TAU * 520.0 * u) * exp(-u * 70.0) * 0.5) * gain


## A blunt low knock, slightly squared so it reads on small speakers.
static func _knock(t: float, at: float) -> float:
	var u := t - at
	if u < 0.0:
		return 0.0
	var w := sin(TAU * 140.0 * u)
	return clampf(w * 1.8, -1.0, 1.0) * exp(-u * 55.0) * 0.5 * minf(u / 0.002, 1.0)
