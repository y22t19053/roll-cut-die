extends Node2D
## Isolated plan-view bench; no GameSession, inventory, collision or archive writes.
const Recorder = preload("res://scripts/ghost/ghost_recorder.gd")
const Track = preload("res://scripts/ghost/ghost_track.gd")
class StandIn extends Node3D:
	var facing := 0.0
	var frozen := false

var actor := StandIn.new()
var rec := Recorder.new()
var anchor := Vector3.ZERO
var anchor_t := 0.0
var echo := PackedVector2Array()
var take := 1
var show_echo := true

func _ready() -> void:
	add_child(actor)
	add_child(rec)
	rec.setup(actor, null, take)
	rec.start()
	rec.set_physics_process(false) # Physics below advances the production sampler after moving.
	rec.mark(Track.FLAG_ALIVE)

func _physics_process(dt: float) -> void:
	var dir := Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	advance(dir, dt)

func advance(dir: Vector2, dt: float) -> void:
	var step := dir.normalized() * dt * 3.2
	actor.position.x = clampf(actor.position.x + step.x, -6, 6)
	actor.position.z = clampf(actor.position.z + step.y, -3, 3)
	rec._physics_process(dt)
	queue_redraw()

func set_mark() -> void:
	anchor = actor.position
	anchor_t = rec.elapsed()
	rec.mark(Track.FLAG_ALIVE)

func cut() -> void:
	rec.mark(Track.FLAG_ALIVE)
	var previous = rec.stop()
	echo.clear() # One abandoned suffix, not a growing set of helpers.
	var start_tick := Track.quant_time(anchor_t)
	for i in previous.size():
		if previous.times[i] >= start_tick:
			var p: Vector3 = previous.raw_at(i).position
			var pt := Vector2(p.x, p.z)
			if echo.is_empty() or echo[-1] != pt:
				echo.append(pt)
	actor.position = anchor
	take += 1
	rec.resume_from(anchor_t, take)
	queue_redraw()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_M: set_mark()
		KEY_C: cut()
		KEY_H: show_echo = not show_echo
	queue_redraw()

func _draw() -> void:
	var size_px := get_viewport_rect().size
	var center := size_px * Vector2(.5,.55)
	var k := minf(size_px.x / 15.0, size_px.y / 10.0)
	draw_rect(Rect2(center - Vector2(6,3)*k, Vector2(12,6)*k), Color.DIM_GRAY, false, 2)
	# Locations to discuss, not triggers or a compulsory route.
	for spot in [Vector2(-3,-1.6), Vector2(2.5,1.4), Vector2(3.8,-1.5)]:
		var pos: Vector2 = center + spot*k
		draw_rect(Rect2(pos-Vector2(7,7),Vector2(14,14)), Color.SILVER, false, 2)
	if show_echo and echo.size() > 1:
		var pts := PackedVector2Array()
		for pt in echo: pts.append(center + pt*k)
		draw_polyline(pts, Color.SKY_BLUE, 3, true)
	draw_arc(center + Vector2(anchor.x, anchor.z)*k, 12, 0, TAU, 32, Color.GOLD, 2)
	draw_circle(center + Vector2(actor.position.x, actor.position.z)*k, 7, Color.WHITE)
	draw_string(ThemeDB.fallback_font, Vector2(32,48), "OUTTAKE / plan view     WASD walk     M mark     C cut     H compare on/off", HORIZONTAL_ALIGNMENT_LEFT,-1,24)
	draw_string(ThemeDB.fallback_font, Vector2(32,82), "Take %02d     White: you     Ring: mark     Overlay: %s" % [take, 'shown' if show_echo else 'hidden'], HORIZONTAL_ALIGNMENT_LEFT,-1,22)
