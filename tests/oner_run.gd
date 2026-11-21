extends SceneTree
## Input-only integration with the real CharacterBody, camera and collider island.
const Run = preload("res://scripts/studiolot/oner_run.gd")
const Player = preload("res://scripts/player/player.gd")
const Rig = preload("res://scripts/camera/camera_rig.gd")
var run_stage
var player
var close_count := 0
var failures := 0
var banks := 0
var done := 0
var held := {}
func _initialize() -> void: call_deferred("go")
func need(ok: bool, why: String) -> bool:
	if not ok:
		push_error("ONER: %s leg %d pos %s failures %d" % [why,run_stage.leg,player.position,failures]); quit(1)
	return ok
func key(k: int,d: bool) -> void:
	if held.has(k)==d: return
	if d: held[k]=true
	else: held.erase(k)
	var e := InputEventKey.new()
	e.pressed=d; e.keycode=k; e.physical_keycode=k
	Input.parse_input_event(e); Input.flush_buffered_events()
func release() -> void:
	for k in held.keys(): key(k,false)
func lateral(z: float) -> void:
	for i in 240:
		var d: float=z-player.position.z
		if absf(d)<0.022: break
		key(KEY_S,d>0);key(KEY_W,d<0)
		await physics_frame
	release()
	for i in 12: await physics_frame
func cross(expect_failure := false) -> bool:
	var stage: int=run_stage.leg
	var count:=failures
	key(KEY_D if stage%2==1 else KEY_A,true)
	for i in 600:
		await physics_frame
		if failures!=count or run_stage.leg!=stage or not run_stage.active: break
	release()
	return failures==count+1 if expect_failure else failures==count and (run_stage.leg!=stage or not run_stage.active)
func go() -> void:
	preload("res://scripts/core/input_setup.gd").ensure_actions()
	var root3:=Node3D.new();root.add_child(root3)
	run_stage=Run.new();root3.add_child(run_stage)
	player=Player.new();root3.add_child(player)
	var rig=Rig.new();root3.add_child(rig);rig.setup(player)
	run_stage.leg_failed.connect(func(_n):failures+=1)
	run_stage.leg_banked.connect(func(_n):banks+=1)
	run_stage.near_miss.connect(func(_n):close_count+=1)
	run_stage.completed.connect(func():done+=1)
	run_stage.start(player,rig)
	# Try the centreline first: the physical island must stop the capsule.
	key(KEY_D,true)
	for i in 150: await physics_frame
	release()
	if not need(player.position.x < -2.2 and banks==0,"central collision shortcut"):return
	# Get back to the west apron before running the first full-length test lane.
	key(KEY_A,true)
	while player.position.x>-6.3: await physics_frame
	release()
	for n in range(1,9):
		var lane := [1.10,-1.10,1.99,-1.99,2.89,-2.89,1.99,-1.99][n-1] as float
		await lateral(lane)
		if n>=7:
			# Delay the new leg in its turning box: don't tail its older performance.
			for j in 60: await physics_frame
		if not need(await cross(),"could not bank pass %d" % n):return
		if not need(run_stage.tracks.size()==n and run_stage.tracks.back().size()>25,"missing real samples"):return
		if n==1:
			var tr=run_stage.tracks[0]
			# The first performer initially hits the centre island; wait for it to
			# return and set out along our lane, then deliberately walk into it.
			for j in 250: await physics_frame
			if not need(await cross(true),"overlapping footprints did not kill"):return
			if not need(run_stage.leg==2 and run_stage.tracks==[tr] and close_count==0,"failed pass contaminated history/near-miss"):return
	if not need(done==1 and banks==8,"no completion"):return
	# Controlled opposing passes separated by 0.9 m: one entry, one exit,
	# exactly one receipt. Restart only after preserving the eight-pass verdict.
	run_stage.start(player,rig)
	await lateral(1.25)
	if not need(await cross(),"near-miss calibration first pass"):return
	var before:=close_count
	await lateral(2.15)
	if not need(await cross(),"parallel opposing pass collided"):return
	if not need(close_count==before+1,"expected exactly one safe departure"):return
	print("ONER_EIGHT_PHYSICAL: true; banks=",banks," failures=",failures," near departures=",close_count)
	quit(0)
