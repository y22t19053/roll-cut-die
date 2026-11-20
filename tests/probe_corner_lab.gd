extends SceneTree
## Real physics and camera, same inputs and geometry for each camera mode.
const Lab = preload("res://tools/corner_lab.tscn")

func _initialize() -> void:
	call_deferred("_run")
	create_timer(55.0).timeout.connect(func(): quit(3))

func _run() -> void:
	var lab = Lab.instantiate()
	root.add_child(lab)
	var failures := 0
	print("corner | mode | blocked m | yaw swept deg | exits at contact / seen / released | retreat m")
	for station in 4:
		for mode in 3:
			lab.reset_trial(station, mode)
			await physics_frame
			Input.action_press("move_forward")
			await _ticks(55)
			var blocked_at: Vector3 = lab.player.global_position
			var yaw: float = lab.rig.yaw
			var sweep := 0.0
			var initial: int = lab.exit_visibility()
			var seen := initial
			for i in 60:
				await physics_frame
				var next: float = lab.rig.yaw
				sweep += absf(rad_to_deg(wrapf(next - yaw, -PI, PI)))
				yaw = next
				seen |= lab.exit_visibility()
			var blocked := blocked_at.distance_to(lab.player.global_position)
			Input.action_release("move_forward")
			await _ticks(12)
			var released: int = lab.exit_visibility()
			var before: Vector3 = lab.player.global_position
			Input.action_press("move_back")
			await _ticks(50)
			Input.action_release("move_back")
			var retreat := before.distance_to(lab.player.global_position)
			print("%d | %s | %.3f | %.1f | %d/%d/%d | %.2f" % [station + 1, lab.rig.snapshot().mode, blocked, sweep, initial, seen, released, retreat])
			if blocked > 0.01 or retreat < 2.3 or retreat > 2.6 or (mode == 2 and absf(sweep - 30.0) > 0.1):
				failures += 1
	lab.queue_free()
	await process_frame
	print("CORNER LAB: %d/12 mechanical checks passed" % (12 - failures))
	quit(0 if failures == 0 else 1)

func _ticks(count: int) -> void:
	for i in count:
		await physics_frame
