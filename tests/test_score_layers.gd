extends RefCounted

const Score = preload("res://scripts/relay/relay_sound.gd")
const SILENT := -60.0
const BACKING := ["calm", "tense", "danger", "music", "drive", "answers", "sprint", "dress", "murmur"]


static func run(h, _tree = null) -> void:
	h.begin("score_layers")
	var idle := Score._mix_targets(0, 0.0, false)
	h.eq("act zero starts in idle", idle.state, Score.State.IDLE)
	h.near("calm bed sets idle level", idle.calm, -21.0)
	h.near("room texture stays below calm", idle.dress, -35.0)
	for part: String in ["tense", "danger", "music", "drive", "answers", "sprint", "murmur", "halt"]:
		h.near("idle leaves %s out" % part, idle[part], SILENT)
	h.eq("negative inputs clamp to idle", Score._mix_targets(-1, -0.5, false), idle)
	h.eq("low proximity leaves idle alone", Score._mix_targets(0, 0.30, false), idle)

	var act_one := Score._mix_targets(1, 0.0, false)
	var act_two := Score._mix_targets(2, 0.0, false)
	var act_three := Score._mix_targets(3, 0.0, false)
	for mix: Dictionary in [act_one, act_two, act_three]:
		h.eq("quiet act is progress", mix.state, Score.State.PROGRESS)
		h.near("each act retains its harmonic bed", mix.music, -17.5)
		h.near("calm sits under the harmonic bed", mix.calm, -26.0)
		h.near("progress has no sprint rhythm", mix.sprint, SILENT)
	h.near("act one leaves drums out", act_one.drive, SILENT)
	h.near("act one leaves the answer phrase out", act_one.answers, SILENT)
	h.near("act two brings in the drum stem", act_two.drive, -22.0)
	h.near("act two leaves room for the next act", act_two.answers, SILENT)
	h.near("act three keeps the drum level", act_three.drive, act_two.drive)
	h.near("act three brings in mallet answers", act_three.answers, -19.0)
	h.eq("out of range act clamps to three", Score._mix_targets(8, 0.0, false), act_three)

	var approach := Score._mix_targets(3, 0.50, false)
	var danger := Score._mix_targets(3, 0.70, false)
	var peak := Score._mix_targets(3, 1.0, false)
	h.eq("approach retains the progress state", approach.state, Score.State.PROGRESS)
	h.eq("even act zero can enter danger", Score._mix_targets(0, 0.60, false).state, Score.State.DANGER)
	h.eq("high proximity enters danger", danger.state, Score.State.DANGER)
	h.ok("tense overtakes calm at danger threshold", Score._mix_targets(3, 0.60, false).tense > Score._mix_targets(3, 0.60, false).calm)
	h.near("tense seats in the foreground", danger.tense, -17.0)
	h.near("calm recedes beneath tense", danger.calm, -41.0)
	h.ok("heartbeat enters before peak danger", approach.danger > SILENT)
	h.ok("heartbeat gets stronger near danger", danger.danger > approach.danger and peak.danger > danger.danger)
	h.ok("heartbeat speeds up as danger rises", danger.danger_pitch > approach.danger_pitch and approach.danger_pitch > idle.danger_pitch)
	h.near("peak heartbeat speed is capped", peak.danger_pitch, 1.50)
	h.eq("proximity above one clamps to peak", Score._mix_targets(3, 3.0, false), peak)
	for part: String in ["music", "drive", "answers"]:
		h.ok("danger drops %s behind the tense bed" % part, danger[part] < act_three[part] and danger[part] < danger.tense)

	for act: int in 4:
		var sprint := Score._mix_targets(act, 1.0, true)
		var restored := Score._mix_targets(act, 1.0, false)
		h.eq("sprint has precedence over danger", sprint.state, Score.State.SPRINT)
		h.near("sprint uses its own drum pattern", sprint.sprint, -16.0)
		h.ok("sprint stays ahead of heartbeat and tense", sprint.sprint > sprint.danger and sprint.sprint > sprint.tense)
		h.eq("sprint exit restores live danger state", restored.state, Score.State.DANGER)
		h.near("sprint exit drops the sprint layer immediately", restored.sprint, SILENT)
		h.near("sprint exit restores tense bed", restored.tense, -17.0)
	h.eq("safe sprint exit restores initial bed", Score._mix_targets(0, 0.0, false), idle)
	var soft_sprint := Score._mix_targets(3, 1.0, true, false, Score.Ending.NONE, 0.0, true)
	h.near("reduce motion lowers sprint rhythm", soft_sprint.sprint, -28.0)
	h.near("reduce motion lowers the regular drums", soft_sprint.drive, -40.0)
	h.near("reduce motion leaves the danger bed audible", soft_sprint.tense, -22.0)

	var playing := Score._mix_targets(3, 1.0, true, false, Score.Ending.NONE, 2.0)
	var slate := Score._mix_targets(3, 1.0, true, true, Score.Ending.NONE, 2.0)
	var accent := Score._mix_targets(3, 1.0, true, false, Score.Ending.NONE, 2.0, false, 3.0)
	h.eq("slate takes precedence over sprint and danger", slate.state, Score.State.WRAP)
	for part: String in BACKING:
		h.near("slate makes room on %s" % part, slate[part], maxf(SILENT, playing[part] - 12.0))
		h.near("cue makes room on %s" % part, accent[part], maxf(SILENT, playing[part] - 3.0))
	h.near("slate does not trigger a coda", slate.halt, SILENT)
	var still := Score._mix_targets(0, 0.0, false, false, Score.Ending.NONE, 2.0)
	h.near("stillness preserves the room murmur", still.murmur, -34.0)
	h.near("sprinting pulls the room murmur out", playing.murmur, SILENT)
	h.near("slate clears the room murmur", Score._mix_targets(0, 0.0, false, true, Score.Ending.NONE, 2.0).murmur, SILENT)

	for ending: int in [Score.Ending.COLLISION, Score.Ending.WIN]:
		var wrap := Score._mix_targets(3, 1.0, true, true, ending, 2.0)
		h.eq("ending suspends the active score", wrap.state, Score.State.WRAP)
		for part: String in BACKING:
			h.near("ending clears %s for its foreground cue" % part, wrap[part], SILENT)
		h.near("win tail leads, collision tail stays under hit", wrap.halt, -13.0 if ending == Score.Ending.WIN else -25.0)
	h.ok("collision cues outrank sprint and pickup",
		Score.PRIORITY.trap > Score.PRIORITY.sprint and Score.PRIORITY.hit > Score.PRIORITY.pickup)
