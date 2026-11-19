extends SceneTree
## Regression probe: no save I/O, rendering, input injection or host clock.
const Recorder = preload("res://scripts/ghost/ghost_recorder.gd")
class Subject extends Node3D:
	var facing := 0.0
	var frozen := false

func _initialize() -> void:
	call_deferred("measure")

func measure() -> void:
	var p := Subject.new()
	root.add_child(p)
	var r = Recorder.new()
	r.setup(p, null, 1)
	r.start()
	for i in 600:
		# 4s still, 2s walk east at 1 m/s, 4s still.
		p.position.x = clampf((i + 1.0) / 60.0 - 4.0, 0.0, 2.0)
		r._physics_process(1.0 / 60.0)
	var tr = r.stop()
	var x3: float = tr.sample_at(3.0).position.x
	var x5: float = tr.sample_at(5.0).position.x
	var finished8: bool = tr.sample_at(8.0).finished
	var ok: bool = absf(tr.duration() - 10.0) <= 0.11 and absf(x3) < 0.02 and absf(x5 - 1) <= 0.11 and not finished8
	print("REPLAY CLOCK %s | physics=10s duration=%.2f x@3=%.2f x@5=%.2f finished@8=%s" % ["PASS" if ok else "FAIL", tr.duration(), x3, x5, finished8])
	r.free()
	p.free()
	quit(0 if ok else 1)
