extends SceneTree
## Prevent an observer instruction from leaking into the unprompted decision.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var conditions := ["junction_lab", "junction_uncoached"]
	var reference: Dictionary = {}
	for condition in conditions:
		var lab = load("res://tools/%s.tscn" % condition).instantiate()
		root.add_child(lab)
		var prompts := 0
		for label in lab.find_children("*", "Label3D", true, false):
			if label.text == "M   /   WATCH":
				prompts += 1
		if condition == "junction_lab":
			reference = lab.map_data.duplicate(true)
		if prompts != (1 if condition == "junction_lab" else 0) or lab.map_data != reference:
			print("FAIL ",condition," prompts=",prompts," map_equal=",lab.map_data == reference)
			quit(1)
			return
		print("PASS ",condition," prompts=",prompts," map_equal=true")
		lab.queue_free()
		await process_frame
	quit(0)
