extends Node3D
## An in-floor monitor looks down into a scale copy of the actual tower. Its cast
## reads the same tracks and clock as the live cast that takes over on landing.
var clock := 0.0
var period := 1.0
var cast := []
var landing := Vector3.ZERO
var view := SubViewport.new()
var room := Node3D.new()
var monitor := MeshInstance3D.new()
var landing_ring := MeshInstance3D.new()

func box(parent: Node3D, at: Vector3, size: Vector3, ink: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	node.mesh = b
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = ink
	node.material_override = mat
	node.position = at
	parent.add_child(node)
	return node

func build(plan: Dictionary) -> void:
	view.own_world_3d = true
	view.size = Vector2i(480,480)
	view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(view)
	view.add_child(room)
	box(room,Vector3(8,-0.15,28),Vector3(16,0.25,18),Color("23374a"))
	for prop in plan.props:
		var r: Array = prop.rect
		if r[0] > 17 or r[3] < 20 or not prop.get("solid",true): continue
		var h: float = prop.height
		box(room,Vector3((r[0]+r[2])/2,h/2,(r[1]+r[3])/2),Vector3(r[2]-r[0],h,r[3]-r[1]),Color(prop.color[0],prop.color[1],prop.color[2]))
	var ring := TorusMesh.new()
	ring.inner_radius = 0.62
	ring.outer_radius = 0.82
	landing_ring.mesh = ring
	var chalk := StandardMaterial3D.new()
	chalk.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	chalk.albedo_color = Color("ffd88e")
	landing_ring.material_override = chalk
	room.add_child(landing_ring)
	var cam := Camera3D.new()
	room.add_child(cam)
	cam.position = Vector3(8,24,27)
	cam.rotation.x = -PI/2
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 20
	cam.current = true
	var plane := PlaneMesh.new()
	plane.size = Vector2(2.4,2.4)
	monitor.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = view.get_texture()
	monitor.material_override = mat
	add_child(monitor)
	close()

func begin(history: Array) -> void:
	for item in cast: item.body.queue_free()
	cast.clear()
	var latest = history.back().track
	landing = latest.raw_at(0).position
	landing_ring.position = landing + Vector3.UP * 0.07
	period = latest.duration()
	for i in latest.size():
		var p: Vector3 = latest.raw_at(i).position
		if p.z < 20.4 or p.x > 16.55:
			period = latest.dequant_time(latest.times[i]); break
	period = maxf(0.1,period)
	for reel in history:
		var body := box(room,Vector3.ZERO,Vector3(0.54,1.6,0.7),Color.from_hsv(fmod(0.55+0.13*reel.take,1.0),0.5,1.0))
		box(body,Vector3(0,0.5,-0.42),Vector3(0.28,0.15,0.45),Color.WHITE)
		cast.append({"track":reel.track,"body":body})
	clock = 0
	visible = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	advance(0)

func advance(dt: float) -> void:
	clock = fmod(clock + dt, period)
	for item in cast:
		var s: Dictionary = item.track.sample_at(clock)
		item.body.position = s.position + Vector3.UP * 0.8
		item.body.rotation.y = s.facing
		item.body.visible = clock <= item.track.duration()

func close() -> void:
	visible = false
	view.render_target_update_mode = SubViewport.UPDATE_DISABLED
