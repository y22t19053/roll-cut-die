extends Node3D
## Dev preview for the H lighting gantry (Sprint 5 item 4 candidate).
##
## Tests are excluded from the export presets, so this scene ships nowhere: it
## exists so a human can look at the two-deck set the geometry test only measures.
## Run it with: godot --path roll-cut-die tests/gantry_preview.tscn

const Gantry = preload("res://scripts/relay/h_gantry.gd")


func _ready() -> void:
	var parts := Gantry.build(self)

	var sun := DirectionalLight3D.new()
	sun.transform = Transform3D(Basis.looking_at(Vector3(-0.4, -1.0, -0.6), Vector3.UP),
		Vector3(0.0, 12.0, 6.0))
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	add_child(sun)

	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("14171c")
	env.environment.ambient_light_color = Color("5a6675")
	env.environment.ambient_light_energy = 0.7
	add_child(env)

	var cam := Camera3D.new()
	cam.transform = Transform3D(Basis.looking_at(
		(parts["stations"] as PackedVector3Array)[1] - Vector3(9.0, 5.4, 9.0), Vector3.UP),
		Vector3(9.0, 5.4, 9.0))
	cam.fov = 52.0
	add_child(cam)
	cam.make_current()
