extends SceneTree
## Synthetic QA only. Physical input routed through the actual trial scene; no human data.
const Stream = preload("res://tools/trial_recorder.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, msg: String) -> void:
	print("synthetic_QA ", "PASS " if ok else "FAIL ", msg)
	if not ok:
		failures += 1

func key(code: int, down: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.pressed = down
	Input.parse_input_event(e)
	Input.flush_buffered_events()

func tap(code: int) -> void:
	key(code,true)
	key(code,false)

func ticks(n: int) -> void:
	for _i in n:
		await physics_frame

func run() -> void:
	if DisplayServer.get_name() != "headless" or not OS.get_cmdline_user_args().is_empty():
		quit(2)
		return
	create_timer(35.0).timeout.connect(func(): quit(3))
	var save := "user://rcd/save.json"
	var before := FileAccess.get_sha256(save) if FileAccess.file_exists(save) else "absent"
	var cfg := "RCD-Research/isolated/0123456789abcdef0123456789abcdef"
	var actual := "C:/AppData/Roaming/" + cfg
	check(Stream.isolated_operator_dir(true,cfg,actual) and Stream.isolated_operator_dir(true,cfg,actual.replace("/","\\")), "accept prepared folder with either path separator")
	check(not Stream.isolated_operator_dir(false,cfg,actual) and not Stream.isolated_operator_dir(true,cfg,actual+"0") and not Stream.isolated_operator_dir(true,cfg+"/..",actual+"/.."), "reject disabled, mismatched or malformed isolation")
	var rejected := Stream.new()
	check(not rejected.begin([], "A", {},true) and rejected.directory.is_empty(), "no consent is inert")
	check(not Stream.valid_session("../1234") and not Stream.valid_session("someone@example.com"), "rejects path/name")
	# Advance only the synthetic recorder's time origin; no five-minute sleep.
	var cap := Stream.new()
	if not cap.begin([Stream.CONSENT], "A", {}, true):
		quit(1)
		return
	cap._start_us -= Stream.LIMIT_US
	cap.append("sample", {"wall_contact":true})
	var capped := FileAccess.get_file_as_string(cap.directory.path_join("trial.jsonl")).strip_edges().split("\n")
	check(not cap.active() and capped.size() == 2 and JSON.parse_string(capped[-1]).reason == "time_limit", "deadline seals outcome without collecting the expired sample")
	var previous := ""
	for cond in ["a", "b"]:
		var main = load("res://tools/corner_evidence_%s.tscn" % cond).instantiate()
		root.add_child(main)
		check(main.trial == null,"normal scene has no recorder")
		main._install_trial(true)
		var trial = main.trial
		var st = trial.stream
		tap(KEY_F8)
		check(st.directory.is_empty(), "unfocused start ignored")
		trial._qa_focused = true
		tap(KEY_F8)
		check(main.player.frozen and st.directory.is_empty(), "focused start during opening slate creates no file")
		while main.player.frozen:
			await physics_frame
		trial._qa_focused = true
		tap(KEY_F8)
		check(st.active() and st.directory.begins_with("user://west_trials_qa/"), "focused start opens QA partial only")
		if not st.active():
			quit(1)
			return
		var dest: String = st.directory.path_join("trial.jsonl")
		check(not FileAccess.file_exists(dest) and st.session != previous and Stream.valid_session(st.session), "unique anonymous session, no premature publication")
		previous = st.session
		tap(KEY_Q)
		key(KEY_D,true)
		await ticks(16)
		key(KEY_D,false)
		await ticks(14)
		if cond == "b":
			key(KEY_W,true)
			await ticks(225)
			key(KEY_W,false)
			await ticks(14)
			key(KEY_D,true)
			await ticks(27)
			key(KEY_D,false)
			await ticks(14)
			key(KEY_W,true)
			await ticks(40)
			key(KEY_W,false)
			await ticks(14)
			tap(KEY_E)
			tap(KEY_E)
		else:
			trial._qa_focused = false
			tap(KEY_E)
			await ticks(2)
		check(FileAccess.file_exists(dest) and not st.active(), "terminal event closes stream")
		if not FileAccess.file_exists(dest):
			quit(1)
			return
		var lines := FileAccess.get_file_as_string(dest).strip_edges().split("\n")
		var header: Dictionary = JSON.parse_string(lines[0])
		var end: Dictionary = JSON.parse_string(lines[-1])
		check(header.source == "synthetic_QA" and header.condition == cond.to_upper() and header.session == st.session, "labeled header and condition")
		var keys: Array = []
		var contact := false
		var last_t := -1
		var monotone := true
		for line in lines:
			var row: Dictionary = JSON.parse_string(line)
			monotone = monotone and row.t_us >= last_t
			last_t = int(row.t_us)
			if row.type == "key":
				keys.append(str(row.key) + ("+" if row.pressed else "-"))
			if row.type == "sample" and row.wall_contact:
				contact = true
		var expected := ["D+", "D-"] if cond == "a" else ["D+","D-","W+","W-","D+","D-","W+","W-","E+","E-","E+"]
		check(monotone and keys == expected, "only focused allowlisted transitions, monotonic time: " + str(keys))
		check(end.reason == ("focus_lost" if cond == "a" else "collected") and end.script_page_taken == (cond == "b") and contact == (cond == "b"), "reason=" + str(end.reason) + " west_contact=" + str(contact))
		var digest := FileAccess.get_sha256(dest)
		tap(KEY_F8)
		check(not st.finish("operator_stop",false) and FileAccess.get_sha256(dest) == digest, "second finish cannot overwrite")
		print("synthetic_QA artifact ", dest, " rows=", lines.size(), " sha256=",digest)
		main.queue_free()
		await process_frame
		await physics_frame
	var after := FileAccess.get_sha256(save) if FileAccess.file_exists(save) else "absent"
	check(before == after, "production save existence/hash unchanged")
	quit(1 if failures else 0)
