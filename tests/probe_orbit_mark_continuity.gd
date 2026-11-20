extends SceneTree
## Diagnostic: compare one fixed-physics continuation against the current CUT restore recipe.
const Rig = preload("res://scripts/camera/camera_rig.gd")
func _initialize() -> void:
	var rig = Rig.new()
	rig.set_roll_mode(2)
	var original = rig.active()
	var dt := 1.0 / 60.0
	for i in 30:
		original.drive(0.0, Vector3.LEFT, dt)
	var other = Rig.new()
	other.set_roll_mode(2)
	other.restore_mark_motion({"cam_motion":rig.mark_motion(), "cam_yaw":original.yaw, "cam_roll":original.roll})
	var resumed = other.active()
	var marked_speed: float = original.w
	# First tick with no held key: the uninterrupted camera should coast.
	original.drive(0.0, Vector3.ZERO, dt)
	resumed.drive(0.0, Vector3.ZERO, dt)
	var delta := absf(rad_to_deg(angle_difference(original.yaw, resumed.yaw)))
	print("ORBIT restore comparison: marked %.1f deg/s; next tick %.1f / %.1f deg/s; yaw error %.3f deg" % [rad_to_deg(marked_speed),rad_to_deg(original.w),rad_to_deg(resumed.w),delta])
	rig.free()
	other.free()
	quit(0 if delta < 0.0001 else 1)
