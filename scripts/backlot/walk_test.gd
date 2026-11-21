extends SceneTree
## End-to-end physics walk. No teleports, injected tracks or disabled hazards.
var studio
var failed := false
func _initialize() -> void:
	call_deferred("run")

func walk(p: Vector2) -> void:
	for i in 1200:
		var pos: Vector3 = studio.player.position
		var d := p - Vector2(pos.x,pos.z)
		if d.length() < 0.15:
			studio.player.input_override = Vector2.ZERO
			return
		if studio.player.frozen: break
		studio.player.input_override = d.normalized()
		await physics_frame
	failed = true
	push_error("walk blocked at %s -> %s" % [studio.player.position,p])

func live() -> void:
	for i in 480:
		await physics_frame
		if not studio.player.frozen: return
	failed = true

func run() -> void:
	studio = load("res://scenes/backlot/backlot.tscn").instantiate()
	root.add_child(studio)
	await live()
	var opening_yaw: float = studio.rig.yaw
	await walk(Vector2(12,28)) # Go through both dock doorways in one held direction.
	var sweep := absf(rad_to_deg(angle_difference(opening_yaw, studio.rig.yaw)))
	print("DOCK DOORS: crossed both, orbit sweep %.1f degrees" % sweep)
	if sweep < 50 or failed: quit(1); return
	for p in [Vector2(12,25.8), Vector2(10,25.8), Vector2(10,4), Vector2(28,4)]:
		await walk(p)
	studio._interact()
	if studio.power_cut: push_error("breaker operated from walkway"); quit(1); return
	await walk(Vector2(28,3.22))
	studio._interact()
	if not studio.power_cut: quit(1); return
	studio._retake()
	await live()
	if studio.ghost_nodes.size() != 1: quit(1); return
	# Timing audit: the most optimistic return ignores walls and acceleration.
	var recording = studio.ghost_nodes[0].track
	var window_x: float = studio.SetPlan.PORTAL_X[1]
	var eye_spot := Vector2(window_x + 1.0, studio.SetPlan.PORTAL_Z + 2.0)
	var start: Vector3 = studio.player.global_position
	var earliest := Vector2(start.x,start.z).distance_to(eye_spot) / float(studio.player.SPEED)
	var last_near := -1.0
	for tick in range(ceili(recording.duration() * 60.0) + 1):
		var t := tick / 60.0
		var pos: Vector3 = recording.sample_at(t).position
		if Vector2(pos.x,pos.z).distance_to(eye_spot) <= 4.0:
			last_near = t
	print("RETURN WINDOW AUDIT: observation spot %s, earliest arrival %.2fs, last replay within 4m %.2fs" % [eye_spot, earliest, last_near])
	await walk(eye_spot)
	var ghost = studio.ghost_nodes[0]
	var separation: float = ghost.global_position.distance_to(studio.player.global_position)
	print("RETURN WINDOW WALK: reached at %.2fs, separation %.2fm" % [ghost.playhead,separation])
	if failed or separation > 4.0 or ghost.playhead >= last_near: quit(1); return
	for p in [Vector2(17,30),Vector2(36.4,27),Vector2(36.4,6),Vector2(33,6)]:
		await walk(p)
	studio._interact()
	if studio.carrying: push_error("reel collected from walkway"); quit(1); return
	await walk(Vector2(33,5.22))
	studio._mark()
	studio._interact()
	if not studio.carrying: quit(1); return
	studio._manual_cut()
	for i in 240:
		await physics_frame
		if studio.cut_panel.is_open(): break
	var points: Array = studio.marks.points()
	studio._cut_to(points[-1])
	await live()
	if studio.carrying or studio.ghost_nodes.size() != 1: quit(1); return
	studio._interact()
	for p in [Vector2(36.4,6),Vector2(36.4,27),Vector2(33,27)]:
		await walk(p)
	studio._interact()
	if studio.screened: push_error("projector operated from walkway"); quit(1); return
	await walk(Vector2(33,27.96))
	studio._interact()
	var ok: bool = not failed and studio.screened
	print("BACKLOT_WALK_CUT_SCREEN: ",ok)
	quit(0 if ok else 1)
