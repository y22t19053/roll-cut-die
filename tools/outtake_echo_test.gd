extends SceneTree
const Lab = preload("res://tools/outtake_echo.tscn")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var lab = Lab.instantiate()
	root.add_child(lab)
	lab.set_physics_process(false)
	for i in 60: lab.advance(Vector2.RIGHT,1.0/60)
	lab.set_mark()
	for i in 30: lab.advance(Vector2.DOWN,1.0/60)
	var end: Vector2 = Vector2(lab.actor.position.x, lab.actor.position.z)
	lab.cut()
	var ok: bool = lab.echo.size() >= 2 and lab.actor.position == lab.anchor
	ok = ok and lab.echo[-1].distance_to(end) < .001 and lab.echo[0].distance_to(Vector2(lab.anchor.x,lab.anchor.z)) < .001
	for i in 30: lab.advance(Vector2.LEFT,1.0/60)
	lab.cut()
	for p in lab.echo: ok = ok and absf(p.y) < .001
	ok = ok and not lab.echo.has(end) and lab.echo.size() >= 2 and lab.find_children("*","CollisionObject3D",true,false).is_empty()
	lab.cut() # No movement does not keep an older path.
	ok = ok and lab.echo.size() <= 1
	print("OUTTAKE_SUFFIX_REPLACE_NONCOLLIDING_EMPTY: ",ok)
	quit(0 if ok else 1)
