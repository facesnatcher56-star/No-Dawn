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

var mat_road: StandardMaterial3D
var mat_berm: StandardMaterial3D
var mat_stripe: StandardMaterial3D
var mat_wood: StandardMaterial3D
var mat_tarp: StandardMaterial3D

var blast_furnace_scene = preload("res://scenes/BlastFurnace.tscn")
var steam_hammer_scene = preload("res://scenes/SteamHammer.tscn")

const InfrastructureBuilderClass = preload("res://scripts/environment/MapInfrastructureBuilder.gd")
const DistrictBuilderClass = preload("res://scripts/environment/MapDistrictBuilder.gd")
const TacticalCoverBuilderClass = preload("res://scripts/environment/MapTacticalCoverBuilder.gd")

func _ready() -> void:
	_init_materials()
	_build_ground()
	_build_tactical_terrain_and_ridges()
	_build_railway_system()
	_build_warehouses()
	_build_silo_complexes()
	_build_pipe_gantries()
	_build_gantry_crane()
	_build_blast_furnace_complex()
	_build_steam_hammer()
	_build_scattered_cover_and_fires()
	_build_industrial_lights()

	# Populate full 3,600m x 3,600m battlefield across all sectors & quadrants
	var infra_builder = InfrastructureBuilderClass.new()
	add_child(infra_builder)
	infra_builder.build(self)

	var district_builder = DistrictBuilderClass.new()
	add_child(district_builder)
	district_builder.build(self)

	var tactical_builder = TacticalCoverBuilderClass.new()
	add_child(tactical_builder)
	tactical_builder.build(self)

func _init_materials() -> void:
	mat_ground = StandardMaterial3D.new()
	mat_ground.albedo_color = Color(0.25, 0.24, 0.22)
	mat_ground.roughness = 0.95

	mat_road = StandardMaterial3D.new()
	mat_road.albedo_color = Color(0.18, 0.19, 0.21)
	mat_road.roughness = 0.85

	mat_berm = StandardMaterial3D.new()
	mat_berm.albedo_color = Color(0.28, 0.26, 0.22)
	mat_berm.roughness = 0.98

	mat_stripe = StandardMaterial3D.new()
	mat_stripe.albedo_color = Color(0.78, 0.76, 0.68)
	mat_stripe.roughness = 0.9

	mat_wood = StandardMaterial3D.new()
	mat_wood.albedo_color = Color(0.28, 0.22, 0.16)
	mat_wood.roughness = 0.92

	mat_tarp = StandardMaterial3D.new()
	mat_tarp.albedo_color = Color(0.18, 0.24, 0.20)
	mat_tarp.roughness = 0.85

	mat_brick = StandardMaterial3D.new()
	mat_brick.albedo_color = Color(0.42, 0.24, 0.18)
	mat_brick.roughness = 0.88

	mat_concrete = StandardMaterial3D.new()
	mat_concrete.albedo_color = Color(0.36, 0.38, 0.39)
	mat_concrete.roughness = 0.82

	mat_steel = StandardMaterial3D.new()
	mat_steel.albedo_color = Color(0.22, 0.24, 0.26)
	mat_steel.metallic = 0.75
	mat_steel.roughness = 0.38

	mat_rust = StandardMaterial3D.new()
	mat_rust.albedo_color = Color(0.46, 0.26, 0.16)
	mat_rust.metallic = 0.35
	mat_rust.roughness = 0.78

	mat_pipe = StandardMaterial3D.new()
	mat_pipe.albedo_color = Color(0.32, 0.34, 0.36)
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

	# Main terrain ground 3600x3600 (Supports 800m - 2500m long-range tactical engagements)
	var col = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(3600.0, 2.0, 3600.0)
	col.shape = box
	col.position = Vector3(0, -1.0, 0)
	sb.add_child(col)

	var mesh_inst = MeshInstance3D.new()
	var bmesh = BoxMesh.new()
	bmesh.size = Vector3(3600.0, 2.0, 3600.0)
	bmesh.material = mat_ground
	mesh_inst.mesh = bmesh
	mesh_inst.position = Vector3(0, -1.0, 0)
	sb.add_child(mesh_inst)

	# Outer battlefield perimeter boundaries at 1800m
	_create_wall(Vector3(0, 6, -1800), Vector3(3600, 12, 6), mat_concrete)
	_create_wall(Vector3(0, 6, 1800), Vector3(3600, 12, 6), mat_concrete)
	_create_wall(Vector3(-1800, 6, 0), Vector3(6, 12, 3600), mat_concrete)
	_create_wall(Vector3(1800, 6, 0), Vector3(6, 12, 3600), mat_concrete)

	# Inner industrial facility walls with open eastern/western railway & road gates
	_create_wall(Vector3(0, 4, -260), Vector3(540, 8, 4), mat_concrete)
	_create_wall(Vector3(0, 4, 260), Vector3(540, 8, 4), mat_concrete)
	_create_wall(Vector3(-260, 4, -145), Vector3(4, 8, 230), mat_concrete)
	_create_wall(Vector3(-260, 4, 205), Vector3(4, 8, 110), mat_concrete)
	_create_wall(Vector3(260, 4, -145), Vector3(4, 8, 230), mat_concrete)
	_create_wall(Vector3(260, 4, 205), Vector3(4, 8, 110), mat_concrete)

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

	# Architectural plinth base (visual-only concrete base)
	var plinth_back = MeshInstance3D.new()
	var pm_b = BoxMesh.new()
	pm_b.size = Vector3(size.x + 0.6, 0.9, 2.4)
	pm_b.material = mat_concrete
	plinth_back.mesh = pm_b
	plinth_back.position = pos + Vector3(0, 0.45, -half_d)
	add_child(plinth_back)

	# Steel coping along top rim of back wall
	var coping_back = MeshInstance3D.new()
	var cm_b = BoxMesh.new()
	cm_b.size = Vector3(size.x + 0.4, 0.35, 2.4)
	cm_b.material = mat_steel
	coping_back.mesh = cm_b
	coping_back.position = pos + Vector3(0, h + 0.17, -half_d)
	add_child(coping_back)

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

func _build_tactical_terrain_and_ridges() -> void:
	# 1. Paved North-South Roadway with asphalt pad and center marking stripes
	var road = MeshInstance3D.new()
	var road_mesh = BoxMesh.new()
	road_mesh.size = Vector3(14.0, 0.04, 520.0)
	road_mesh.material = mat_road
	road.mesh = road_mesh
	road.position = Vector3(-60.0, 0.02, 0.0)
	add_child(road)

	for sz in range(-240, 240, 16):
		var stripe = MeshInstance3D.new()
		var sm = BoxMesh.new()
		sm.size = Vector3(0.4, 0.06, 6.0)
		sm.material = mat_stripe
		stripe.mesh = sm
		stripe.position = Vector3(-60.0, 0.03, float(sz))
		add_child(stripe)

	# 1b. East-West Industrial Transit Avenue along Z = 110.0 (tactical maneuver corridor)
	var avenue = MeshInstance3D.new()
	var avenue_mesh = BoxMesh.new()
	avenue_mesh.size = Vector3(300.0, 0.04, 12.0)
	avenue_mesh.material = mat_road
	avenue.mesh = avenue_mesh
	avenue.position = Vector3(-85.0, 0.02, 110.0)
	add_child(avenue)

	for ax in range(-220, 50, 16):
		var astripe = MeshInstance3D.new()
		var asm = BoxMesh.new()
		asm.size = Vector3(6.0, 0.06, 0.4)
		asm.material = mat_stripe
		astripe.mesh = asm
		astripe.position = Vector3(float(ax), 0.03, 110.0)
		add_child(astripe)

	# 1c. Elevated concrete road curbs (visual-only, no colliders)
	for x_side in [-67.2, -52.8]:
		var curb_ns = MeshInstance3D.new()
		var cm_ns = BoxMesh.new()
		cm_ns.size = Vector3(0.35, 0.16, 520.0)
		cm_ns.material = mat_concrete
		curb_ns.mesh = cm_ns
		curb_ns.position = Vector3(x_side, 0.08, 0.0)
		add_child(curb_ns)

	for z_side in [103.8, 116.2]:
		var curb_ew = MeshInstance3D.new()
		var cm_ew = BoxMesh.new()
		cm_ew.size = Vector3(300.0, 0.16, 0.35)
		cm_ew.material = mat_concrete
		curb_ew.mesh = cm_ew
		curb_ew.position = Vector3(-85.0, 0.08, z_side)
		add_child(curb_ew)

	# 1d. Roadside infrastructure props (safely outside maneuver swept corridor Z=106..114)
	# Street lamps along Z = 117.5 (north of curb)
	for lx in [-170, -135, -100, -30, 20]:
		_create_lamp_post(Vector3(float(lx), 0.0, 117.5))

	# Utility power poles along Z = 102.5 (south of curb)
	for px in [-180, -145, -110, -40, 10]:
		_create_utility_pole(Vector3(float(px), 0.0, 102.5))

	# Visual concrete barricades / jersey barriers along curbs
	_create_jersey_barrier(Vector3(-160.0, 0.0, 117.2))
	_create_jersey_barrier(Vector3(-120.0, 0.0, 117.2))
	_create_jersey_barrier(Vector3(-140.0, 0.0, 102.8))
	_create_jersey_barrier(Vector3(-80.0, 0.0, 102.8))
	_create_jersey_barrier(Vector3(30.0, 0.0, 117.2))

	# Oil drum pallet clusters near sidings
	_create_drum_pallet(Vector3(-175.0, 0.0, 118.5))
	_create_drum_pallet(Vector3(-125.0, 0.0, 101.5))
	_create_drum_pallet(Vector3(-65.0, 0.0, 119.0))

	# 2. Hull-Down Tactical Ridges & Earth Berms
	# Central ridge crossing between warehouses
	_create_berm(Vector3(-75.0, 0.0, 35.0), Vector3(90.0, 1.8, 14.0), 0.15)
	# Player flank hull-down firing position
	_create_berm(Vector3(-148.0, 0.0, 75.0), Vector3(32.0, 1.7, 10.0), 0.0)
	# Enemy flank hull-down berm
	_create_berm(Vector3(-85.0, 0.0, 145.0), Vector3(36.0, 1.7, 10.0), -0.1)

	# 3. Defensive Dragon's Teeth (Pyramidal anti-tank obstacles)
	var dt_positions = [
		Vector3(-130, 0, 40), Vector3(-125, 0, 42), Vector3(-120, 0, 44),
		Vector3(-115, 0, 46), Vector3(-110, 0, 48),
		Vector3(10, 0, -40), Vector3(16, 0, -38), Vector3(22, 0, -36),
		Vector3(28, 0, -34), Vector3(34, 0, -32)
	]
	for dpos in dt_positions:
		_create_dragons_tooth(dpos)

	# 4. Drainage Ditch Culvert
	var culvert = MeshInstance3D.new()
	var cm = BoxMesh.new()
	cm.size = Vector3(4.0, 0.8, 480.0)
	cm.material = mat_concrete
	culvert.mesh = cm
	culvert.position = Vector3(-45.0, -0.3, 0.0)
	add_child(culvert)

	# 5. Smoldering Smoke Plumes in the industrial yard
	_create_smoke_plume(Vector3(-140, 0.8, -80))
	_create_smoke_plume(Vector3(45, 0.8, 20))
	_create_smoke_plume(Vector3(-80, 0.8, 70))

func _create_berm(pos: Vector3, size: Vector3, rot_y: float = 0.0) -> void:
	var sb = StaticBody3D.new()
	sb.position = pos
	sb.rotation.y = rot_y
	add_child(sb)

	var col = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = size
	col.shape = box
	col.position = Vector3(0, size.y * 0.5, 0)
	sb.add_child(col)

	var mi = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = size
	bm.material = mat_berm
	mi.mesh = bm
	mi.position = Vector3(0, size.y * 0.5, 0)
	sb.add_child(mi)

	# Sloped earth approach shoulders
	for side in [-1.0, 1.0]:
		var shoulder = MeshInstance3D.new()
		var psm = PrismMesh.new()
		psm.size = Vector3(size.x, size.y * 0.9, size.z * 0.6)
		psm.material = mat_berm
		shoulder.mesh = psm
		shoulder.position = Vector3(0, size.y * 0.45, side * (size.z * 0.6))
		shoulder.rotation.x = PI * 0.5 if side > 0 else -PI * 0.5
		sb.add_child(shoulder)

func _create_dragons_tooth(pos: Vector3) -> void:
	var tooth = MeshInstance3D.new()
	var pm = PrismMesh.new()
	pm.size = Vector3(1.6, 1.5, 1.6)
	pm.material = mat_concrete
	tooth.mesh = pm
	tooth.position = pos + Vector3(0, 0.75, 0)
	tooth.rotation.y = randf_range(0, PI)
	add_child(tooth)

func _create_smoke_plume(pos: Vector3) -> void:
	var particles = GPUParticles3D.new()
	particles.position = pos
	particles.amount = 32
	particles.lifetime = 4.0
	particles.speed_scale = 0.8
	particles.explosiveness = 0.05
	particles.randomness = 0.5

	var mat = ParticleProcessMaterial.new()
	mat.direction = Vector3(0.2, 1.0, 0.1).normalized()
	mat.spread = 18.0
	mat.initial_velocity_min = 2.0
	mat.initial_velocity_max = 4.5
	mat.gravity = Vector3(0, 0.5, 0)
	mat.scale_min = 1.2
	mat.scale_max = 3.8
	mat.color = Color(0.25, 0.27, 0.28, 0.35)
	particles.process_material = mat

	var pmesh = SphereMesh.new()
	pmesh.radius = 0.7
	pmesh.height = 1.4
	var pmat = StandardMaterial3D.new()
	pmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pmat.albedo_color = Color(0.22, 0.24, 0.25, 0.35)
	pmat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	pmesh.material = pmat
	particles.draw_pass_1 = pmesh

	add_child(particles)

func _create_utility_pole(pos: Vector3) -> void:
	var pole = MeshInstance3D.new()
	var pm = CylinderMesh.new()
	pm.top_radius = 0.16
	pm.bottom_radius = 0.22
	pm.height = 9.0
	pm.material = mat_wood
	pole.mesh = pm
	pole.position = pos + Vector3(0, 4.5, 0)
	add_child(pole)

	# Crossarm
	var arm = MeshInstance3D.new()
	var am = BoxMesh.new()
	am.size = Vector3(2.4, 0.16, 0.16)
	am.material = mat_wood
	arm.mesh = am
	arm.position = pos + Vector3(0, 8.2, 0)
	add_child(arm)

	# Ceramic insulators
	for ix in [-0.9, 0.0, 0.9]:
		var ins = MeshInstance3D.new()
		var im = CylinderMesh.new()
		im.top_radius = 0.06
		im.bottom_radius = 0.06
		im.height = 0.22
		im.material = mat_concrete
		ins.mesh = im
		ins.position = pos + Vector3(ix, 8.4, 0)
		add_child(ins)

func _create_jersey_barrier(pos: Vector3, rot_y: float = 0.0) -> void:
	var barrier = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = Vector3(3.0, 0.85, 0.6)
	bm.material = mat_concrete
	barrier.mesh = bm
	barrier.position = pos + Vector3(0, 0.42, 0)
	barrier.rotation.y = rot_y
	add_child(barrier)

func _create_drum_pallet(pos: Vector3) -> void:
	var pallet = MeshInstance3D.new()
	var pm = BoxMesh.new()
	pm.size = Vector3(1.6, 0.14, 1.6)
	pm.material = mat_wood
	pallet.mesh = pm
	pallet.position = pos + Vector3(0, 0.07, 0)
	add_child(pallet)

	for ox in [-0.38, 0.38]:
		for oz in [-0.38, 0.38]:
			var drum = MeshInstance3D.new()
			var dm = CylinderMesh.new()
			dm.top_radius = 0.3
			dm.bottom_radius = 0.3
			dm.height = 0.95
			dm.material = mat_rust if (ox > 0) else mat_steel
			drum.mesh = dm
			drum.position = pos + Vector3(ox, 0.61, oz)
			add_child(drum)
