extends SceneTree
## Headless regression: exact cue boundaries and rewinding to a take timestamp.
func _initialize() -> void:
	call_deferred("check")

func check() -> void:
	var stage := preload("res://scripts/studiolot/green_stage.gd").new()
	root.add_child(stage)
	var performer := stage.get_node("StandIn") as Node3D
	var ok := stage.find_children("*", "CollisionObject3D", true, false).is_empty()
	for pair: Array in [[0.0,false],[3.49,false],[3.5,true],[4.99,true],[5.0,false],[13.5,true]]:
		stage.set_take_time(pair[0])
		ok = ok and stage.on_mark() == pair[1]
	stage.set_take_time(2.125)
	var pose := performer.transform
	stage.set_take_time(7.8)
	stage.set_take_time(2.125)
	ok = ok and performer.transform.is_equal_approx(pose)
	var cove := stage.get_node("InfinityCove") as MeshInstance3D
	var normals: PackedVector3Array = cove.mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
	ok = ok and normals[0].y > .9 and normals[-1].z > .9
	print("Stage geometry, sync window, rewind and passage: ", "PASS" if ok else "FAIL")
	# Release instances before their resource RIDs in the 4.3 dummy renderer.
	for part: MeshInstance3D in stage.find_children("*", "MeshInstance3D", true, false):
		part.mesh = null
	stage.free()
	quit(0 if ok else 1)
