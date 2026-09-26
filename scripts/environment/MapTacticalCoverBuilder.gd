extends Node3D
class_name MapTacticalCoverBuilder
## Builds battlefield tactical cover across the entire 3,600m x 3,600m map:
## Hull-down earth berms, tank scrapes, anti-tank dragon's teeth belts,
## destroyed armored vehicle wrecks, cargo shipping container stacks, and blast craters.

var map: IndustrialMapBuilder

func build(p_map: IndustrialMapBuilder) -> void:
	map = p_map
	_build_trans_battlefield_berms_and_scrapes()
	_build_defensive_dragons_teeth_belts()
	_build_burned_out_tank_wrecks()
	_build_shipping_container_depots()
	_build_artillery_craters_and_fires()

# -----------------------------------------------------------------------------
# 1. TACTICAL EARTH BERMS & HULL-DOWN TANK SCRAPES (3,600m SPAN)
# -----------------------------------------------------------------------------
func _build_trans_battlefield_berms_and_scrapes() -> void:
	# Distributed deliberately along the northern flank (Z in [135, 175])
	# and southern flank (Z in [45, 85]) of the main engagement corridor (Z = 110)
	# Providing tactical hull-down cover at key ranges: 400m, 800m, 1200m, 1500m!
	var tactical_flank_berms = [
		# Far West approach (X = -1350 to -1050)
		[Vector3(-1350.0, 0.0, 155.0), Vector3(45.0, 2.2, 12.0), 0.05],
		[Vector3(-1350.0, 0.0, 65.0), Vector3(45.0, 2.2, 12.0), -0.05],
		[Vector3(-1050.0, 0.0, 160.0), Vector3(50.0, 2.4, 14.0), 0.08],
		[Vector3(-1050.0, 0.0, 60.0), Vector3(50.0, 2.4, 14.0), -0.08],

		# Player Spawn Flanks (X around -750m)
		[Vector3(-750.0, 0.0, 165.0), Vector3(60.0, 2.2, 14.0), 0.02],
		[Vector3(-750.0, 0.0, 55.0), Vector3(60.0, 2.2, 14.0), -0.02],
		[Vector3(-550.0, 0.0, 155.0), Vector3(55.0, 2.5, 12.0), 0.1],
		[Vector3(-550.0, 0.0, 65.0), Vector3(55.0, 2.5, 12.0), -0.1],

		# Midfield Gateway Flanks (X = -350 and +350)
		[Vector3(-350.0, 0.0, 160.0), Vector3(65.0, 2.4, 14.0), 0.0],
		[Vector3(-350.0, 0.0, 60.0), Vector3(65.0, 2.4, 14.0), 0.0],
		[Vector3(350.0, 0.0, 160.0), Vector3(65.0, 2.4, 14.0), 0.0],
		[Vector3(350.0, 0.0, 60.0), Vector3(65.0, 2.4, 14.0), 0.0],

		# Enemy Spawn Flanks (X around +750m)
		[Vector3(550.0, 0.0, 155.0), Vector3(55.0, 2.5, 12.0), -0.1],
		[Vector3(550.0, 0.0, 65.0), Vector3(55.0, 2.5, 12.0), 0.1],
		[Vector3(750.0, 0.0, 165.0), Vector3(60.0, 2.2, 14.0), -0.02],
		[Vector3(750.0, 0.0, 55.0), Vector3(60.0, 2.2, 14.0), 0.02],

		# Far East approach (X = 1050 to 1350)
		[Vector3(1050.0, 0.0, 160.0), Vector3(50.0, 2.4, 14.0), -0.08],
		[Vector3(1050.0, 0.0, 60.0), Vector3(50.0, 2.4, 14.0), 0.08],
		[Vector3(1350.0, 0.0, 155.0), Vector3(45.0, 2.2, 12.0), -0.05],
		[Vector3(1350.0, 0.0, 65.0), Vector3(45.0, 2.2, 12.0), 0.05],

		# Northern Flank Tactical Berms (along Z = -450 and Z = -850)
		[Vector3(-1100.0, 0.0, -450.0), Vector3(70.0, 2.6, 16.0), 0.0],
		[Vector3(-600.0, 0.0, -450.0), Vector3(70.0, 2.6, 16.0), 0.0],
		[Vector3(600.0, 0.0, -450.0), Vector3(70.0, 2.6, 16.0), 0.0],
		[Vector3(1100.0, 0.0, -450.0), Vector3(70.0, 2.6, 16.0), 0.0],

		# Southern Flank Tactical Berms (along Z = 600 and Z = 1100)
		[Vector3(-1100.0, 0.0, 600.0), Vector3(70.0, 2.6, 16.0), 0.0],
		[Vector3(-600.0, 0.0, 600.0), Vector3(70.0, 2.6, 16.0), 0.0],
		[Vector3(600.0, 0.0, 600.0), Vector3(70.0, 2.6, 16.0), 0.0],
		[Vector3(1100.0, 0.0, 600.0), Vector3(70.0, 2.6, 16.0), 0.0]
	]

	for b_data in tactical_flank_berms:
		map._create_berm(b_data[0], b_data[1], b_data[2])

# -----------------------------------------------------------------------------
# 2. DEFENSIVE DRAGON'S TEETH ANTI-TANK BELTS
# -----------------------------------------------------------------------------
func _build_defensive_dragons_teeth_belts() -> void:
	# West Sector Defense Belts (channeling armor from northern/southern approaches)
	_create_dragons_teeth_line(Vector3(-1150.0, 0.0, -400.0), Vector3(-1150.0, 0.0, -100.0))
	_create_dragons_teeth_line(Vector3(-1150.0, 0.0, 180.0), Vector3(-1150.0, 0.0, 480.0))

	# East Sector Defense Belts
	_create_dragons_teeth_line(Vector3(1150.0, 0.0, -400.0), Vector3(1150.0, 0.0, -100.0))
	_create_dragons_teeth_line(Vector3(1150.0, 0.0, 180.0), Vector3(1150.0, 0.0, 480.0))

	# Midfield Defenses North and South of Central Complex
	_create_dragons_teeth_line(Vector3(-320.0, 0.0, -320.0), Vector3(-150.0, 0.0, -320.0))
	_create_dragons_teeth_line(Vector3(150.0, 0.0, -320.0), Vector3(320.0, 0.0, -320.0))
	_create_dragons_teeth_line(Vector3(-320.0, 0.0, 320.0), Vector3(-150.0, 0.0, 320.0))
	_create_dragons_teeth_line(Vector3(150.0, 0.0, 320.0), Vector3(320.0, 0.0, 320.0))

func _create_dragons_teeth_line(start_pt: Vector3, end_pt: Vector3) -> void:
	var dist = start_pt.distance_to(end_pt)
	var count = int(dist / 5.0)
	for i in range(count):
		var t = float(i) / maxf(1.0, float(count - 1))
		var pos = start_pt.lerp(end_pt, t)
		map._create_dragons_tooth(pos)
		# Staggered double row
		var normal = (end_pt - start_pt).cross(Vector3.UP).normalized()
		map._create_dragons_tooth(pos + normal * 2.2)

# -----------------------------------------------------------------------------
# 3. DESTROYED ARMORED VEHICLE WRECKS & CHASSIS HULKS
# -----------------------------------------------------------------------------
func _build_burned_out_tank_wrecks() -> void:
	# Burned-out armor hulks positioned at prior engagement points
	var wreck_locations = [
		[Vector3(-920.0, 0.0, 125.0), 0.35],
		[Vector3(-620.0, 0.0, 95.0), -0.4],
		[Vector3(-280.0, 0.0, 130.0), 0.8],
		[Vector3(280.0, 0.0, 90.0), -0.7],
		[Vector3(620.0, 0.0, 125.0), 0.2],
		[Vector3(920.0, 0.0, 95.0), -0.5],
		[Vector3(-450.0, 0.0, -180.0), 1.2],
		[Vector3(450.0, 0.0, -180.0), -1.1],
		[Vector3(-500.0, 0.0, 420.0), 0.6],
		[Vector3(500.0, 0.0, 420.0), -0.6]
	]

	for w_data in wreck_locations:
		_create_tank_wreck(w_data[0], w_data[1])

func _create_tank_wreck(pos: Vector3, rot_y: float) -> void:
	var wreck = StaticBody3D.new()
	wreck.position = pos
	wreck.rotation.y = rot_y
	add_child(wreck)

	# Hull box (burned rust steel)
	var hull_col = CollisionShape3D.new()
	var hbox = BoxShape3D.new()
	hbox.size = Vector3(3.6, 2.2, 7.2)
	hull_col.shape = hbox
	hull_col.position = Vector3(0.0, 1.1, 0.0)
	wreck.add_child(hull_col)

	var hull_mi = MeshInstance3D.new()
	var hm = BoxMesh.new()
	hm.size = Vector3(3.6, 2.2, 7.2)
	hm.material = map.mat_rust
	hull_mi.mesh = hm
	hull_mi.position = Vector3(0.0, 1.1, 0.0)
	wreck.add_child(hull_mi)

	# Detached / displaced turret (skewed on hull or on ground)
	var turret_mi = MeshInstance3D.new()
	var tm = BoxMesh.new()
	tm.size = Vector3(2.8, 1.6, 3.8)
	tm.material = map.mat_rust
	turret_mi.mesh = tm
	turret_mi.position = Vector3(0.4, 2.4, -0.6)
	turret_mi.rotation.y = 0.55
	turret_mi.rotation.z = 0.15
	wreck.add_child(turret_mi)

	# Gun barrel
	var barrel = MeshInstance3D.new()
	var bm = CylinderMesh.new()
	bm.top_radius = 0.15
	bm.bottom_radius = 0.18
	bm.height = 4.8
	bm.material = map.mat_rust
	barrel.mesh = bm
	barrel.position = Vector3(0.5, 2.3, 2.2)
	barrel.rotation.x = PI * 0.45
	wreck.add_child(barrel)

	# Smoldering smoke plume rising from shattered turret ring
	map._create_smoke_plume(pos + Vector3(0.0, 2.2, 0.0))

# -----------------------------------------------------------------------------
# 4. CARGO SHIPPING CONTAINER DEPOTS & STACKS
# -----------------------------------------------------------------------------
func _build_shipping_container_depots() -> void:
	# Container staging parks in the industrial quadrants
	var depot_centers = [
		Vector3(-820.0, 0.0, -110.0),
		Vector3(-820.0, 0.0, 330.0),
		Vector3(820.0, 0.0, -110.0),
		Vector3(820.0, 0.0, 330.0),
		Vector3(-450.0, 0.0, -550.0),
		Vector3(450.0, 0.0, -550.0),
		Vector3(-450.0, 0.0, 750.0),
		Vector3(450.0, 0.0, 750.0)
	]

	for d_pos in depot_centers:
		_create_container_stack(d_pos)

func _create_container_stack(pos: Vector3) -> void:
	# Stack of 2-3 standard 20ft and 40ft containers providing solid cover
	var c_len = 12.2 # 40ft container
	var c_w = 2.44
	var c_h = 2.6

	# Base layer (2 parallel containers)
	map._create_wall(pos + Vector3(-1.4, c_h * 0.5, 0.0), Vector3(c_w, c_h, c_len), map.mat_rust)
	map._create_wall(pos + Vector3(1.4, c_h * 0.5, 0.0), Vector3(c_w, c_h, c_len), map.mat_steel)

	# Top layer (1 container straddling the two)
	map._create_wall(pos + Vector3(0.0, c_h * 1.5, 0.0), Vector3(c_w, c_h, c_len), map.mat_concrete)

	# Adjacent wooden pallets with oil drums
	map._create_drum_pallet(pos + Vector3(3.8, 0.0, -3.0))
	map._create_drum_pallet(pos + Vector3(-3.8, 0.0, 3.0))

# -----------------------------------------------------------------------------
# 5. ARTILLERY CRATERS, IMPACT SCARS & WARTIME FIRES
# -----------------------------------------------------------------------------
func _build_artillery_craters_and_fires() -> void:
	var crater_sites = [
		Vector3(-1200.0, 0.0, 80.0),
		Vector3(-980.0, 0.0, 140.0),
		Vector3(-710.0, 0.0, 75.0),
		Vector3(-420.0, 0.0, 130.0),
		Vector3(420.0, 0.0, 85.0),
		Vector3(710.0, 0.0, 145.0),
		Vector3(980.0, 0.0, 80.0),
		Vector3(1200.0, 0.0, 135.0),
		Vector3(-300.0, 0.0, -700.0),
		Vector3(300.0, 0.0, -700.0),
		Vector3(-300.0, 0.0, 800.0),
		Vector3(300.0, 0.0, 800.0)
	]

	for c_pos in crater_sites:
		_create_blast_crater(c_pos)

	# Additional smoldering fires across the map
	var outlying_fires = [
		Vector3(-850.0, 0.0, 200.0),
		Vector3(-650.0, 0.0, -120.0),
		Vector3(650.0, 0.0, 200.0),
		Vector3(850.0, 0.0, -120.0),
		Vector3(0.0, 0.0, -900.0),
		Vector3(0.0, 0.0, 900.0)
	]

	for f_pos in outlying_fires:
		map._create_burning_barrel(f_pos)
		map._create_smoke_plume(f_pos + Vector3(0.0, 0.8, 0.0))

func _create_blast_crater(pos: Vector3) -> void:
	# Visual circular depression crater ring with raised dirt lips
	var crater = MeshInstance3D.new()
	var cm = TorusMesh.new()
	cm.inner_radius = 3.2
	cm.outer_radius = 5.5
	cm.rings = 16
	cm.ring_segments = 12
	cm.material = map.mat_berm
	crater.mesh = cm
	crater.position = pos + Vector3(0.0, 0.35, 0.0)
	add_child(crater)

	# Scorched inner floor
	var floor_mi = MeshInstance3D.new()
	var fm = CylinderMesh.new()
	fm.top_radius = 3.6
	fm.bottom_radius = 3.6
	fm.height = 0.1
	fm.material = map.mat_road
	floor_mi.mesh = fm
	floor_mi.position = pos + Vector3(0.0, 0.04, 0.0)
	add_child(floor_mi)
