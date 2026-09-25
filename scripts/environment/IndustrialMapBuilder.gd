extends Node3D
class_name IndustrialMapBuilder

# Materials cache
var mat_ground: StandardMaterial3D
var mat_brick: StandardMaterial3D
var mat_concrete: StandardMaterial3D
var mat_steel: StandardMaterial3D
var mat_rust: StandardMaterial3D
var mat_pipe: StandardMaterial3D
var mat_fire: StandardMaterial3D

var blast_furnace_scene = preload("res://scenes/BlastFurnace.tscn")
var steam_hammer_scene = preload("res://scenes/SteamHammer.tscn")

func _ready() -> void:
	_init_materials()
	_build_ground()
	_build_railway_system()
	_build_warehouses()
	_build_silo_complexes()
	_build_pipe_gantries()
	_build_gantry_crane()
	_build_blast_furnace_complex()
	_build_steam_hammer()
	_build_scattered_cover_and_fires()
	_build_industrial_lights()

func _init_materials() -> void:
	mat_ground = StandardMaterial3D.new()
	mat_ground.albedo_color = Color(0.12, 0.11, 0.10)
	mat_ground.roughness = 0.95

	mat_brick = StandardMaterial3D.new()
	mat_brick.albedo_color = Color(0.32, 0.16, 0.12)
	mat_brick.roughness = 0.9

	mat_concrete = StandardMaterial3D.new()
	mat_concrete.albedo_color = Color(0.22, 0.23, 0.24)
	mat_concrete.roughness = 0.85

	mat_steel = StandardMaterial3D.new()
	mat_steel.albedo_color = Color(0.18, 0.19, 0.21)
	mat_steel.metallic = 0.75
	mat_steel.roughness = 0.4

	mat_rust = StandardMaterial3D.new()
	mat_rust.albedo_color = Color(0.38, 0.20, 0.12)
	mat_rust.metallic = 0.4
	mat_rust.roughness = 0.8

	mat_pipe = StandardMaterial3D.new()
	mat_pipe.albedo_color = Color(0.25, 0.27, 0.28)
	mat_pipe.metallic = 0.6
	mat_pipe.roughness = 0.45

	mat_fire = StandardMaterial3D.new()
	mat_fire.albedo_color = Color(1.0, 0.5, 0.1)
	mat_fire.emission_enabled = true
	mat_fire.emission = Color(1.0, 0.45, 0.1)
	mat_fire.emission_energy_multiplier = 4.0

func _build_ground() -> void:
	var sb = StaticBody3D.new()
	add_child(sb)

	# Main terrain ground 500x500
	var col = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(540.0, 2.0, 540.0)
	col.shape = box
	col.position = Vector3(0, -1.0, 0)
	sb.add_child(col)

	var mesh_inst = MeshInstance3D.new()
	var bmesh = BoxMesh.new()
	bmesh.size = Vector3(540.0, 2.0, 540.0)
	bmesh.material = mat_ground
	mesh_inst.mesh = bmesh
	mesh_inst.position = Vector3(0, -1.0, 0)
	sb.add_child(mesh_inst)

	# Perimeter boundary walls
	_create_wall(Vector3(0, 4, -260), Vector3(540, 8, 4), mat_concrete)
	_create_wall(Vector3(0, 4, 260), Vector3(540, 8, 4), mat_concrete)
	_create_wall(Vector3(-260, 4, 0), Vector3(4, 8, 540), mat_concrete)
	_create_wall(Vector3(260, 4, 0), Vector3(4, 8, 540), mat_concrete)

func _create_wall(pos: Vector3, size: Vector3, mat: Material) -> StaticBody3D:
	var sb = StaticBody3D.new()
	add_child(sb)
	sb.position = pos

	var col = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = size
	col.shape = box
	sb.add_child(col)

	var mi = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = size
	bm.material = mat
	mi.mesh = bm
	sb.add_child(mi)
	return sb

func _build_railway_system() -> void:
	var rail_lines_z = [-65.0, 5.0, 80.0]
	for rz in rail_lines_z:
		var ballast = MeshInstance3D.new()
		var bm = BoxMesh.new()
		bm.size = Vector3(480.0, 0.15, 6.0)
		bm.material = mat_concrete
		ballast.mesh = bm
		ballast.position = Vector3(0, 0.08, rz)
		add_child(ballast)

		for side in [-1.2, 1.2]:
			var rail = MeshInstance3D.new()
			var r_mesh = BoxMesh.new()
			r_mesh.size = Vector3(480.0, 0.25, 0.16)
			r_mesh.material = mat_steel
			rail.mesh = r_mesh
			rail.position = Vector3(0, 0.22, rz + side)
			add_child(rail)

	_create_train_car(Vector3(-120, 0, -65), true)
	_create_train_car(Vector3(-95, 0, -65), false)
	_create_train_car(Vector3(80, 0, -65), true)

	_create_train_car(Vector3(-40, 0, 5), true)
	_create_train_car(Vector3(140, 0, 5), true)
	_create_train_car(Vector3(165, 0, 5), false)

	_create_train_car(Vector3(20, 0, 80), true)
	_create_train_car(Vector3(-150, 0, 80), false)

func _create_train_car(pos: Vector3, is_boxcar: bool) -> void:
	var sb = StaticBody3D.new()
	add_child(sb)
	sb.position = pos

	var length = 20.0
	var width = 3.6
	var height = 4.2 if is_boxcar else 1.6

	var col = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(length, height, width)
	col.shape = box
	col.position = Vector3(0, height * 0.5 + 0.5, 0)
	sb.add_child(col)

	var mi = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = Vector3(length, height, width)
	bm.material = mat_rust if is_boxcar else mat_steel
	mi.mesh = bm
	mi.position = Vector3(0, height * 0.5 + 0.5, 0)
	sb.add_child(mi)

func _build_warehouses() -> void:
	_create_warehouse_shell(Vector3(-40, 0, -145), Vector3(90, 14, 48))
	_create_warehouse_shell(Vector3(75, 0, -120), Vector3(75, 12, 45))
	_create_warehouse_shell(Vector3(-95, 0, 160), Vector3(80, 11, 46))
	_create_warehouse_shell(Vector3(150, 0, 150), Vector3(70, 12, 45))

func _create_warehouse_shell(pos: Vector3, size: Vector3) -> void:
	var half_w = size.x * 0.5
	var half_d = size.z * 0.5
	var h = size.y

	_create_wall(pos + Vector3(0, h * 0.5, -half_d), Vector3(size.x, h, 2.0), mat_brick)
	_create_wall(pos + Vector3(-half_w * 0.55, h * 0.5, half_d), Vector3(size.x * 0.4, h, 2.0), mat_brick)
	_create_wall(pos + Vector3(half_w * 0.55, h * 0.5, half_d), Vector3(size.x * 0.4, h, 2.0), mat_brick)

	_create_wall(pos + Vector3(-half_w, h * 0.5, 0), Vector3(2.0, h, size.z), mat_brick)
	_create_wall(pos + Vector3(half_w, h * 0.5, -half_d * 0.5), Vector3(2.0, h, size.z * 0.4), mat_brick)
	_create_wall(pos + Vector3(half_w, h * 0.5, half_d * 0.5), Vector3(2.0, h, size.z * 0.4), mat_brick)

	var trusses = 5
	for i in range(trusses):
		var tx = lerpf(-half_w + 6.0, half_w - 6.0, float(i) / (trusses - 1))
		var truss_beam = MeshInstance3D.new()
		var bm = BoxMesh.new()
		bm.size = Vector3(1.2, 1.2, size.z - 2.0)
		bm.material = mat_steel
		truss_beam.mesh = bm
		truss_beam.position = pos + Vector3(tx, h - 0.6, 0)
		add_child(truss_beam)

func _build_silo_complexes() -> void:
	var cluster1_pos = Vector3(-160, 0, -20)
	for i in range(4):
		var offset = Vector3((i % 2) * 16.0 - 8.0, 0, (i / 2) * 16.0 - 8.0)
		_create_silo(cluster1_pos + offset, 6.0, 18.0)

	var cluster2_pos = Vector3(180, 0, -20)
	for i in range(3):
		_create_silo(cluster2_pos + Vector3(i * 15.0 - 15.0, 0, 0), 5.5, 16.0)

func _create_silo(pos: Vector3, radius: float, height: float) -> void:
	var sb = StaticBody3D.new()
	add_child(sb)
	sb.position = pos

	var col = CollisionShape3D.new()
	var cyl = CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = height
	col.shape = cyl
	col.position = Vector3(0, height * 0.5, 0)
	sb.add_child(col)

	var mi = MeshInstance3D.new()
	var cm = CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	cm.material = mat_rust
	mi.mesh = cm
	mi.position = Vector3(0, height * 0.5, 0)
	sb.add_child(mi)

func _build_pipe_gantries() -> void:
	var gantry_points = [
		[Vector3(-40, 0, -115), Vector3(-40, 0, -70)],
		[Vector3(75, 0, -95), Vector3(75, 0, -30)],
		[Vector3(-95, 0, 85), Vector3(-95, 0, 135)],
		[Vector3(0, 0, -60), Vector3(0, 0, 60)]
	]

	for pair in gantry_points:
		var p1 = pair[0]
		var p2 = pair[1]
		var mid = (p1 + p2) * 0.5
		var length = p1.distance_to(p2)
		var h = 7.5

		var bridge = MeshInstance3D.new()
		var bm = BoxMesh.new()
		bm.size = Vector3(3.0, 0.8, length)
		bm.material = mat_steel
		bridge.mesh = bm
		add_child(bridge)
		bridge.position = Vector3(mid.x, h, mid.z)
		bridge.look_at_from_position(Vector3(mid.x, h, mid.z), Vector3(p2.x, h, p2.z), Vector3.UP)

		var pipe = MeshInstance3D.new()
		var cm = CylinderMesh.new()
		cm.top_radius = 0.45
		cm.bottom_radius = 0.45
		cm.height = length
		cm.material = mat_pipe
		pipe.mesh = cm
		add_child(pipe)
		pipe.position = Vector3(mid.x, h + 0.9, mid.z)
		pipe.rotation = bridge.rotation
		pipe.rotate_x(PI * 0.5)

		_create_wall(Vector3(p1.x, h * 0.5, p1.z), Vector3(1.2, h, 1.2), mat_steel)
		_create_wall(Vector3(p2.x, h * 0.5, p2.z), Vector3(1.2, h, 1.2), mat_steel)

func _build_gantry_crane() -> void:
	var crane_pos = Vector3(-10, 0, 8)
	var span = 46.0
	var height = 22.0

	_create_wall(crane_pos + Vector3(-12, height * 0.5, -span * 0.5), Vector3(3.0, height, 3.0), mat_steel)
	_create_wall(crane_pos + Vector3(12, height * 0.5, -span * 0.5), Vector3(3.0, height, 3.0), mat_steel)
	_create_wall(crane_pos + Vector3(-12, height * 0.5, span * 0.5), Vector3(3.0, height, 3.0), mat_steel)
	_create_wall(crane_pos + Vector3(12, height * 0.5, span * 0.5), Vector3(3.0, height, 3.0), mat_steel)

	var top_beam = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = Vector3(26.0, 3.5, span + 6.0)
	bm.material = mat_rust
	top_beam.mesh = bm
	top_beam.position = crane_pos + Vector3(0, height + 1.5, 0)
	add_child(top_beam)

	var hook = MeshInstance3D.new()
	var hm = BoxMesh.new()
	hm.size = Vector3(4.0, 3.0, 4.0)
	hm.material = mat_steel
	hook.mesh = hm
	hook.position = crane_pos + Vector3(2.0, 11.0, 0)
	add_child(hook)

func _build_blast_furnace_complex() -> void:
	var furnace = blast_furnace_scene.instantiate()
	furnace.position = Vector3(130, 0, -180)
	add_child(furnace)

func _build_steam_hammer() -> void:
	var hammer = steam_hammer_scene.instantiate()
	hammer.position = Vector3(75, 0, -120)
	add_child(hammer)

func _build_scattered_cover_and_fires() -> void:
	var cover_locations = [
		Vector3(-70, 1.5, -20), Vector3(-35, 1.5, -20),
		Vector3(30, 1.5, 40), Vector3(70, 1.5, 40),
		Vector3(-110, 1.5, 50), Vector3(-60, 1.5, 90),
		Vector3(110, 1.5, -60), Vector3(150, 1.5, 30),
		Vector3(-20, 1.5, 120), Vector3(40, 1.5, 140)
	]

	for cpos in cover_locations:
		var size = Vector3(randf_range(8.0, 16.0), 2.8, randf_range(2.0, 3.5))
		var mat = mat_concrete if randf() > 0.5 else mat_rust
		var wall = _create_wall(cpos, size, mat)
		wall.rotation.y = randf_range(0.0, PI)

	var fire_spots = [
		Vector3(-140, 0, -80),
		Vector3(-30, 0, -90),
		Vector3(45, 0, 20),
		Vector3(-80, 0, 70),
		Vector3(110, 0, 90)
	]

	for fpos in fire_spots:
		_create_burning_barrel(fpos)

func _create_burning_barrel(pos: Vector3) -> void:
	var drum = MeshInstance3D.new()
	var cm = CylinderMesh.new()
	cm.top_radius = 0.5
	cm.bottom_radius = 0.5
	cm.height = 1.2
	cm.material = mat_rust
	drum.mesh = cm
	drum.position = pos + Vector3(0, 0.6, 0)
	add_child(drum)

	var light = OmniLight3D.new()
	light.light_color = Color(1.0, 0.48, 0.12)
	light.light_energy = 2.4
	light.omni_range = 16.0
	light.position = pos + Vector3(0, 1.4, 0)
	add_child(light)

func _build_industrial_lights() -> void:
	var light_posts = [
		Vector3(-140, 0, 95),
		Vector3(-90, 0, 75),
		Vector3(-40, 0, 15),
		Vector3(15, 0, -20),
		Vector3(60, 0, 50),
		Vector3(-110, 0, -35),
		Vector3(30, 0, -85),
		Vector3(110, 0, -50)
	]

	for lp in light_posts:
		_create_lamp_post(lp)

func _create_lamp_post(pos: Vector3) -> void:
	var post = MeshInstance3D.new()
	var pm = CylinderMesh.new()
	pm.top_radius = 0.15
	pm.bottom_radius = 0.2
	pm.height = 8.0
	pm.material = mat_steel
	post.mesh = pm
	post.position = pos + Vector3(0, 4.0, 0)
	add_child(post)

	# Lamp arm
	var arm = MeshInstance3D.new()
	var am = BoxMesh.new()
	am.size = Vector3(1.6, 0.2, 0.2)
	am.material = mat_steel
	arm.mesh = am
	arm.position = pos + Vector3(0.7, 7.8, 0)
	add_child(arm)

	# Light fixture
	var light = SpotLight3D.new()
	light.position = pos + Vector3(1.4, 7.6, 0)
	light.rotation.x = -PI * 0.5
	light.light_color = Color(1.0, 0.88, 0.7)
	light.light_energy = 3.5
	light.spot_range = 35.0
	light.spot_angle = 50.0
	light.shadow_enabled = false
	add_child(light)
