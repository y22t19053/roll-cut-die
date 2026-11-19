extends SceneTree
## Smoke test: can the project boot its own main scene at all?
##
## Run: godot --headless --path . --script tests/smoke.gd
## This is deliberately the dumbest possible test: it proves the engine can
## parse the project, load the scene, run one physics tick, and print. Every
## other test builds on that being true.

var _frames := 0
var _scene: Node = null


func _init() -> void:
	print("SMOKE start")
	call_deferred("_main")


func _main() -> void:
	var packed := load("res://scenes/main/main.tscn")
	if packed == null:
		print("SMOKE FAIL cannot load res://scenes/main/main.tscn")
		quit(1)
		return
	print("SMOKE scene loaded")
	_scene = (packed as PackedScene).instantiate()
	if _scene == null:
		print("SMOKE FAIL cannot instantiate")
		quit(1)
		return
	root.add_child(_scene)
	print("SMOKE scene added: ", _scene.name, " children=", _scene.get_child_count())
	await process_frame
	await process_frame
	print("SMOKE after 2 frames, children=", _scene.get_child_count())
	var player := _scene.get_node_or_null("Player")
	print("SMOKE player=", player)
	print("SMOKE RESULT ok")
	quit(0)
