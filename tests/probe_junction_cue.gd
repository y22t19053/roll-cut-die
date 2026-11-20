extends SceneTree
## Prevent an observer instruction from leaking into the unprompted decision.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var conditions := ["junction_lab", "junction_uncoached"]
	var reference: Dictionary = {}
	var reference_signs: Array = []
	for condition in conditions:
		var lab = load("res://tools/%s.tscn" % condition).instantiate()
		root.add_child(lab)
		var prompts := 0
		var signs: Array = []
		for label in lab.find_children("*", "Label3D", true, false):
			if label.text == "M   /   WATCH":
				prompts += 1
			else:
				signs.append([label.text, label.global_position, label.is_visible_in_tree()])
		if condition == "junction_lab":
			reference = lab.map_data.duplicate(true)
			reference_signs = signs
		if signs.is_empty() or signs != reference_signs:
			print("FAIL unrelated sign content, position or visibility changed: ", condition)
			quit(1)
			return
		if prompts != (1 if condition == "junction_lab" else 0) or lab.map_data != reference:
			print("FAIL ",condition," prompts=",prompts," map_equal=",lab.map_data == reference)
			quit(1)
			return
		print("PASS ",condition," prompts=",prompts," map_equal=true")
		lab.queue_free()
		await process_frame
	quit(0)
