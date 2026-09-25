extends SubViewportContainer
const Vehicle = preload("res://scripts/wego/TacticalVehicle.gd")
const DURATION = 6.5
var world: Node3D
var camera: Camera3D
var paths: Array = []
var volumes: Array = []
var timer = 0.0
var record: Dictionary = {}
var playing = false
var driven = false
var reached_volumes: Array[String] = []
var impact_marker: MeshInstance3D

func _ready() -> void:
	stretch = true
	custom_minimum_size = Vector2(maxf(custom_minimum_size.x, 260), maxf(custom_minimum_size.y, 180))
	var viewport = SubViewport.new()
	viewport.size = Vector2i(480, 300)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	world = Node3D.new()
	viewport.add_child(world)
	camera = Camera3D.new()
	camera.fov = 26
	viewport.add_child(camera)
	camera.position = Vector3(8, 6, -9)
	camera.look_at(Vector3(0, 1.5, 0))
	var light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, -30, 0)
	viewport.add_child(light)
	var env_node = WorldEnvironment.new()
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("111d28")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.7
	env_node.environment = env
	viewport.add_child(env_node)
	gui_input.connect(_inspect)

func show_record(data: Dictionary, externally_driven = false) -> void:
	record = data.duplicate(true)
	for child in world.get_children():
		child.visible = false
		child.queue_free()
	paths.clear()
	volumes.clear()
	reached_volumes.clear()
	timer = 0
	driven = externally_driven
	playing = not driven
	for volume in record.volumes:
		var tint = Color(0.3, 0.7, 0.9, 0.09) if volume.armor else Color(0.35, 0.65, 0.6, 0.3)
		if volume.crew: tint = Color(0.9, 0.75, 0.4, 0.5)
		var mesh = Vehicle.box(world, volume.size, volume.pose, tint)
		volumes.append({"mesh": mesh, "data": volume, "color": tint})
	for path in record.paths:
		var tint = Color("ffac56") if path.fragment else Color("f4f5c7")
		var mesh = Vehicle.box(world, Vector3(0.025, 0.025, 0.01), Transform3D.IDENTITY, tint)
		var tip = Vehicle.box(world, Vector3.ONE * (0.055 if path.fragment else 0.16), Transform3D.IDENTITY, tint)
		paths.append({"mesh": mesh, "tip": tip, "data": path, "progress": 0.0})
	impact_marker = null
	if not record.impacts.is_empty():
		var impact: Vector3 = record.impacts[0].position
		camera.position = impact + record.impacts[0].normal * 9 + Vector3(4, 5, 1)
		camera.look_at(Vector3(0, 1.5, 0))
		impact_marker = Vehicle.box(world, Vector3.ONE * 0.23, Transform3D(Basis.IDENTITY, impact), Color("fff2a6"))
	seek(0)

func stage_text() -> String:
	if record.is_empty(): return "No impact recorded"
	if timer < 1.8: return "1 / INCOMING SHELL"
	if timer < 2.5: return "2 / ARMOR IMPACT • " + record.result
	if timer < 4.8: return "3 / PROJECTILE & SPALL" if record.result == "PENETRATION" else "3 / " + record.result
	return "4 / RESULT • " + record.result

func _path_progress(path: Dictionary) -> float:
	if path.fragment: return clampf((timer - 2.5) / 2.3, 0, 1)
	if record.impacts.is_empty(): return clampf(timer / 4.8, 0, 1)
	var impact: Vector3 = record.impacts[0].position
	var length: float = path.from.distance_to(path.to)
	if path.from.distance_to(impact) < 0.02: return clampf((timer - 2.5) / 2.3, 0, 1)
	var entry = clampf(path.from.distance_to(impact) / maxf(length, 0.001), 0, 1)
	if timer < 1.8: return entry * clampf((timer - 0.25) / 1.55, 0, 1)
	if timer < 2.5: return entry
	return lerpf(entry, 1, clampf((timer - 2.5) / 2.3, 0, 1))

func seek(seconds: float) -> void:
	timer = clampf(seconds, 0, DURATION)
	reached_volumes.clear()
	for entry in paths:
		var p = entry.data
		var progress = _path_progress(p)
		entry.progress = progress
		var tip: Vector3 = p.from.lerp(p.to, progress)
		var mesh: MeshInstance3D = entry.mesh
		mesh.visible = progress > 0
		entry.tip.visible = progress > 0
		entry.tip.position = tip
		mesh.position = (p.from + tip) * 0.5
		mesh.mesh.size.z = maxf(0.001, p.from.distance_to(tip))
		if tip.distance_to(p.from) > 0.001: mesh.look_at(tip, Vector3.UP if absf((tip - p.from).normalized().y) < 0.99 else Vector3.RIGHT)
	if timer >= 2.5:
		for strike in record.get("strikes", []):
			for entry in paths:
				var p = entry.data
				if p.fragment != strike.fragment: continue
				var line: Vector3 = p.to - p.from
				var distance = maxf(line.length_squared(), 0.00001)
				var fraction: float = (strike.position - p.from).dot(line) / distance
				if fraction < 0 or fraction > entry.progress + 0.001: continue
				if (p.from + line * fraction).distance_to(strike.position) > 0.02: continue
				if not reached_volumes.has(strike.volume): reached_volumes.append(strike.volume)
				break
	for entry in volumes:
		var tint: Color = entry.color
		if reached_volumes.has(entry.data.name): tint = Color(1, 0.25, 0.12, 0.9)
		elif timer >= 1.8 and not record.impacts.is_empty() and entry.data.name == record.impacts[0].plate: tint = Color(1, 0.75, 0.3, 0.3)
		entry.mesh.material_override.albedo_color = tint
	if impact_marker: impact_marker.visible = timer >= 1.8 and timer < 2.6

func _process(delta: float) -> void:
	if playing and not driven:
		seek(timer + delta)
		if timer >= DURATION: playing = false

func _inspect(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and not record.is_empty() and not driven:
		if event.button_index == MOUSE_BUTTON_LEFT:
			seek(0)
			playing = true
	if event is InputEventMouseMotion and event.button_mask == MOUSE_BUTTON_MASK_RIGHT:
		camera.position = Basis(Vector3.UP, event.relative.x * 0.01) * camera.position
		camera.look_at(Vector3(0, 1.5, 0))
