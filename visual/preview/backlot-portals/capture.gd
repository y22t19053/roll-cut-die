extends Node
## Windowed A/B: identical real scene, shared camera and frozen simulation.
func _ready() -> void:
	var stage := preload("res://scenes/backlot/backlot.tscn").instantiate()
	add_child(stage)
	stage.process_mode = Node.PROCESS_MODE_DISABLED
	for c in stage.find_children("*","Control",true,false):
		c.hide()
	var cam := Camera3D.new()
	add_child(cam)
	cam.position = Vector3(3.0,5.6,18.2)
	cam.look_at(Vector3(8.2,1.25,28.9))
	cam.fov = 38
	cam.current = true
	if not stage.has_node("DockDoorFlats"):
		preload("res://data/backlot/portal_dressing.gd").install(stage)
	var flats := stage.get_node("DockDoorFlats") as Node3D
	for tag in ["before","after"]:
		flats.visible = tag == "after"
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var path := "res://visual/preview/backlot-portals/%s.png" % tag
		var err := get_viewport().get_texture().get_image().save_png(path)
		assert(err == OK)
