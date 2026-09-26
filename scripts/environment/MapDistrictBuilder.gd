extends Node3D
class_name MapDistrictBuilder
## Builds the distinct industrial districts, factory complexes, tank farms, cooling towers,
## and iconic landmark smokestacks across the entire 3,600m x 3,600m battlefield.

var map: IndustrialMapBuilder

func build(p_map: IndustrialMapBuilder) -> void:
	map = p_map
	_build_western_marshalling_and_fuel_depot()
	_build_eastern_chemical_and_foundry_district()
	_build_northern_coking_and_cooling_complex()
	_build_southern_ordnance_and_proving_grounds()
	_build_outlying_substations_and_water_towers()

# -----------------------------------------------------------------------------
# 1. WESTERN MARSHALLING YARD & BULK FUEL STORAGE (X in [-1200, -450])
# -----------------------------------------------------------------------------
func _build_western_marshalling_and_fuel_depot() -> void:
	# Heavy Locomotive Repair Workshop & Maintenance Shed (X = -720, Z = -80)
	# Safely north of Z = 110 highway
	map._create_warehouse_shell(Vector3(-720.0, 0.0, -80.0), Vector3(85.0, 15.0, 48.0))

	# Western Freight Transit Depot (X = -720, Z = 300)
	# Safely south of Z = 110 highway
	map._create_warehouse_shell(Vector3(-720.0, 0.0, 300.0), Vector3(90.0, 13.0, 46.0))

	# Secondary Locomotive Shop (X = -1050, Z = 110 - 80)
	map._create_warehouse_shell(Vector3(-1050.0, 0.0, 0.0), Vector3(75.0, 14.0, 44.0))

	# Western Petroleum & Heavy Fuel Tank Farms:
	# North Fuel Farm at X = -850, Z = -220
	_create_fuel_tank_farm(Vector3(-850.0, 0.0, -220.0), 4)
	# South Fuel Farm at X = -850, Z = 280
	_create_fuel_tank_farm(Vector3(-850.0, 0.0, 280.0), 4)
	# Far West Heavy Oil Reserve at X = -1250, Z = -150
	_create_fuel_tank_farm(Vector3(-1250.0, 0.0, -150.0), 3)

	# Western Coal & Ore Dispensing Gantry (X = -620, Z = -200)
	_create_coal_dispensing_tower(Vector3(-620.0, 0.0, -200.0))

	# Rail Freight Siding Warehouses
	map._create_warehouse_shell(Vector3(-1200.0, 0.0, 450.0 - 50.0), Vector3(70.0, 11.0, 36.0))

# -----------------------------------------------------------------------------
# 2. EASTERN CHEMICAL, SMELTING & SLAG COMPLEX (X in [450, 1200])
# -----------------------------------------------------------------------------
func _build_eastern_chemical_and_foundry_district() -> void:
	# Eastern Secondary Smelting & Rolling Mill (X = 720, Z = -80)
	map._create_warehouse_shell(Vector3(720.0, 0.0, -80.0), Vector3(95.0, 16.0, 52.0))

	# Eastern Chemical Holding Facility (X = 720, Z = 300)
	map._create_warehouse_shell(Vector3(720.0, 0.0, 300.0), Vector3(80.0, 13.0, 44.0))

	# Secondary Rolling Hall (X = 1050, Z = 0)
	map._create_warehouse_shell(Vector3(1050.0, 0.0, 0.0), Vector3(80.0, 14.0, 45.0))

	# Chemical Holding Tank Clusters:
	# North Chemical Farm at X = 850, Z = -220
	_create_fuel_tank_farm(Vector3(850.0, 0.0, -220.0), 4)
	# South Chemical Farm at X = 850, Z = 280
	_create_fuel_tank_farm(Vector3(850.0, 0.0, 280.0), 4)

	# High Chemical Distillation Columns (Steel cylindrical fractionating columns)
	_create_distillation_columns(Vector3(980.0, 0.0, -150.0))
	_create_distillation_columns(Vector3(980.0, 0.0, 200.0))

	# Massive Industrial Slag Heaps & Dark Refuse Berms (elevated tactical cover)
	_create_slag_mound(Vector3(620.0, 0.0, -280.0), Vector3(110.0, 6.5, 35.0))
	_create_slag_mound(Vector3(620.0, 0.0, 380.0), Vector3(110.0, 6.5, 35.0))
	_create_slag_mound(Vector3(1150.0, 0.0, -260.0), Vector3(130.0, 8.0, 42.0))

# -----------------------------------------------------------------------------
# 3. NORTHERN COKING, METALLURGY & COOLING COMPLEX (Z in [-1500, -350])
# -----------------------------------------------------------------------------
func _build_northern_coking_and_cooling_complex() -> void:
	# 4 Massive Landmark Brick Smokestacks / Chimneys (Visible across the full 3.6km map!)
	_create_brick_smokestack(Vector3(-450.0, 0.0, -950.0), 46.0, 3.8)
	_create_brick_smokestack(Vector3(0.0, 0.0, -1150.0), 52.0, 4.2)
	_create_brick_smokestack(Vector3(450.0, 0.0, -950.0), 46.0, 3.8)
	_create_brick_smokestack(Vector3(-850.0, 0.0, -680.0), 40.0, 3.4)
	_create_brick_smokestack(Vector3(850.0, 0.0, -680.0), 40.0, 3.4)

	# 2 Heavy Industrial Hyperbolic Cooling Towers (Height = 42m, Radius = 19m)
	_create_cooling_tower(Vector3(-650.0, 0.0, -1250.0), 19.0, 42.0)
	_create_cooling_tower(Vector3(650.0, 0.0, -1250.0), 19.0, 42.0)

	# Coking Battery Ovens (Linear heavy brick structures with quench towers)
	_create_coking_battery(Vector3(-250.0, 0.0, -900.0), 140.0, 12.0)
	_create_coking_battery(Vector3(250.0, 0.0, -900.0), 140.0, 12.0)

	# Heavy Machine Tooling & Foundry Workshops
	map._create_warehouse_shell(Vector3(-350.0, 0.0, -600.0), Vector3(100.0, 15.0, 55.0))
	map._create_warehouse_shell(Vector3(350.0, 0.0, -600.0), Vector3(100.0, 15.0, 55.0))
	map._create_warehouse_shell(Vector3(0.0, 0.0, -750.0), Vector3(110.0, 16.0, 60.0))

	# Raw bulk material storage silos along the northern railway spur
	for i in range(5):
		map._create_silo(Vector3(-180.0 + i * 22.0, 0.0, -480.0), 7.0, 22.0)

# -----------------------------------------------------------------------------
# 4. SOUTHERN ORDNANCE STORAGE & PROVING GROUNDS (Z in [350, 1500])
# -----------------------------------------------------------------------------
func _build_southern_ordnance_and_proving_grounds() -> void:
	# Hardened Munitions Storage Bunkers (Heavy earth-covered concrete revetments)
	_create_munitions_bunker(Vector3(-380.0, 0.0, 850.0))
	_create_munitions_bunker(Vector3(-120.0, 0.0, 850.0))
	_create_munitions_bunker(Vector3(120.0, 0.0, 850.0))
	_create_munitions_bunker(Vector3(380.0, 0.0, 850.0))

	# Deep Southern Munitions Depots (Z = 1250)
	_create_munitions_bunker(Vector3(-250.0, 0.0, 1250.0))
	_create_munitions_bunker(Vector3(250.0, 0.0, 1250.0))

	# Tank Proving Grounds & Ballistic Test Backstops
	_create_ballistic_test_range(Vector3(0.0, 0.0, 620.0))

	# Vehicle Assembly & Motor Pool Bays
	map._create_warehouse_shell(Vector3(-550.0, 0.0, 680.0), Vector3(90.0, 13.0, 48.0))
	map._create_warehouse_shell(Vector3(550.0, 0.0, 680.0), Vector3(90.0, 13.0, 48.0))
	map._create_warehouse_shell(Vector3(0.0, 0.0, 1050.0), Vector3(120.0, 14.0, 52.0))

# -----------------------------------------------------------------------------
# 5. OUTLYING TRANSFORMER SUBSTATIONS & WATER TOWERS
# -----------------------------------------------------------------------------
func _build_outlying_substations_and_water_towers() -> void:
	# 4 Corner High-Voltage Electrical Transformer Substations
	_create_transformer_substation(Vector3(-1350.0, 0.0, -1150.0))
	_create_transformer_substation(Vector3(1350.0, 0.0, -1150.0))
	_create_transformer_substation(Vector3(-1350.0, 0.0, 1150.0))
	_create_transformer_substation(Vector3(1350.0, 0.0, 1150.0))

	# Elevated Industrial Water Towers (Height = 26m)
	_create_water_tower(Vector3(-1100.0, 0.0, -500.0))
	_create_water_tower(Vector3(1100.0, 0.0, -500.0))
	_create_water_tower(Vector3(-1100.0, 0.0, 700.0))
	_create_water_tower(Vector3(1100.0, 0.0, 700.0))

# -----------------------------------------------------------------------------
# ARCHITECTURAL PROTOTYPES & BUILDER METHODS
# -----------------------------------------------------------------------------
func _create_fuel_tank_farm(center: Vector3, tank_count: int) -> void:
	var tank_radius = 8.5
	var tank_height = 11.0
	var spacing = 24.0

	for i in range(tank_count):
		var ox = (i % 2) * spacing - (spacing * 0.5)
		var oz = (i / 2) * spacing - (spacing * 0.5)
		var t_pos = center + Vector3(ox, 0.0, oz)
		map._create_silo(t_pos, tank_radius, tank_height)

	# Earthen safety retention bund wall around the farm
	var bund_w = spacing * 2.0 + 12.0
	var bund_d = spacing * (float(tank_count) / 2.0) + 12.0
	var bund_h = 2.2
	map._create_wall(center + Vector3(0.0, bund_h * 0.5, -bund_d * 0.5), Vector3(bund_w, bund_h, 2.5), map.mat_berm)
	map._create_wall(center + Vector3(0.0, bund_h * 0.5, bund_d * 0.5), Vector3(bund_w, bund_h, 2.5), map.mat_berm)
	map._create_wall(center + Vector3(-bund_w * 0.5, bund_h * 0.5, 0.0), Vector3(2.5, bund_h, bund_d), map.mat_berm)
	map._create_wall(center + Vector3(bund_w * 0.5, bund_h * 0.5, 0.0), Vector3(2.5, bund_h, bund_d), map.mat_berm)

func _create_brick_smokestack(pos: Vector3, height: float, radius: float) -> void:
	var stack = StaticBody3D.new()
	stack.position = pos
	add_child(stack)

	var col = CollisionShape3D.new()
	var cyl = CylinderShape3D.new()
	cyl.radius = radius * 1.1
	cyl.height = height
	col.shape = cyl
	col.position = Vector3(0.0, height * 0.5, 0.0)
	stack.add_child(col)

	var mi = MeshInstance3D.new()
	var cm = CylinderMesh.new()
	cm.top_radius = radius * 0.75
	cm.bottom_radius = radius * 1.15
	cm.height = height
	cm.material = map.mat_brick
	mi.mesh = cm
	mi.position = Vector3(0.0, height * 0.5, 0.0)
	stack.add_child(mi)

	# Top iron rim collar
	var rim = MeshInstance3D.new()
	var rm = CylinderMesh.new()
	rm.top_radius = radius * 0.95
	rm.bottom_radius = radius * 0.95
	rm.height = 1.2
	rm.material = map.mat_rust
	rim.mesh = rm
	rim.position = Vector3(0.0, height + 0.6, 0.0)
	stack.add_child(rim)

	# Smoke plume from summit
	map._create_smoke_plume(pos + Vector3(0.0, height + 1.0, 0.0))

func _create_cooling_tower(pos: Vector3, radius: float, height: float) -> void:
	var tower = StaticBody3D.new()
	tower.position = pos
	add_child(tower)

	var col = CollisionShape3D.new()
	var cyl = CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = height
	col.shape = cyl
	col.position = Vector3(0.0, height * 0.5, 0.0)
	tower.add_child(col)

	# Hyperbolic visual approximation with stacked cylindrical segments
	var lower_h = height * 0.6
	var upper_h = height * 0.4

	var mi_lower = MeshInstance3D.new()
	var cm_l = CylinderMesh.new()
	cm_l.top_radius = radius * 0.72
	cm_l.bottom_radius = radius
	cm_l.height = lower_h
	cm_l.material = map.mat_concrete
	mi_lower.mesh = cm_l
	mi_lower.position = Vector3(0.0, lower_h * 0.5, 0.0)
	tower.add_child(mi_lower)

	var mi_upper = MeshInstance3D.new()
	var cm_u = CylinderMesh.new()
	cm_u.top_radius = radius * 0.82
	cm_u.bottom_radius = radius * 0.72
	cm_u.height = upper_h
	cm_u.material = map.mat_concrete
	mi_upper.mesh = cm_u
	mi_upper.position = Vector3(0.0, lower_h + upper_h * 0.5, 0.0)
	tower.add_child(mi_upper)

	# Steam / condensation plume
	map._create_smoke_plume(pos + Vector3(0.0, height + 1.0, 0.0))

func _create_coking_battery(pos: Vector3, length: float, height: float) -> void:
	# Heavy linear refractory battery
	map._create_wall(pos + Vector3(0.0, height * 0.5, 0.0), Vector3(length, height, 16.0), map.mat_brick)

	# Quench tower at end
	map._create_wall(pos + Vector3(length * 0.5 + 8.0, 14.0, 0.0), Vector3(16.0, 28.0, 18.0), map.mat_rust)

	# Charging rail along roof
	var rail = MeshInstance3D.new()
	var rm = BoxMesh.new()
	rm.size = Vector3(length, 0.8, 1.2)
	rm.material = map.mat_steel
	rail.mesh = rm
	rail.position = pos + Vector3(0.0, height + 0.4, 0.0)
	add_child(rail)

func _create_distillation_columns(pos: Vector3) -> void:
	for i in range(3):
		var col_pos = pos + Vector3(float(i) * 9.0, 0.0, 0.0)
		var h = 26.0 - float(i) * 3.0
		var r = 1.8
		map._create_silo(col_pos, r, h)

		# Elevated interconnecting pipe
		if i < 2:
			var pipe = MeshInstance3D.new()
			var pm = CylinderMesh.new()
			pm.top_radius = 0.35
			pm.bottom_radius = 0.35
			pm.height = 9.0
			pm.material = map.mat_pipe
			pipe.mesh = pm
			pipe.position = col_pos + Vector3(4.5, h * 0.75, 0.0)
			pipe.rotation.z = PI * 0.5
			add_child(pipe)

func _create_slag_mound(pos: Vector3, size: Vector3) -> void:
	# Heavy sloped slag mound providing elevated hull-down cover
	map._create_berm(pos, size, 0.05)

func _create_coal_dispensing_tower(pos: Vector3) -> void:
	var h = 18.0
	map._create_wall(pos + Vector3(0.0, h * 0.5, 0.0), Vector3(18.0, h, 14.0), map.mat_rust)

func _create_munitions_bunker(pos: Vector3) -> void:
	# Low-profile earth-covered concrete bunker (Height = 4.2m)
	var bunker_w = 26.0
	var bunker_d = 20.0
	var bunker_h = 4.2

	# Concrete shell
	map._create_wall(pos + Vector3(0.0, bunker_h * 0.5, 0.0), Vector3(bunker_w, bunker_h, bunker_d), map.mat_concrete)

	# Earthen blast embankment covering sides
	map._create_berm(pos + Vector3(0.0, 0.0, -bunker_d * 0.5 - 4.0), Vector3(bunker_w + 8.0, bunker_h * 0.9, 8.0), 0.0)
	map._create_berm(pos + Vector3(-bunker_w * 0.5 - 4.0, 0.0, 0.0), Vector3(8.0, bunker_h * 0.9, bunker_d + 8.0), 0.0)
	map._create_berm(pos + Vector3(bunker_w * 0.5 + 4.0, 0.0, 0.0), Vector3(8.0, bunker_h * 0.9, bunker_d + 8.0), 0.0)

func _create_ballistic_test_range(pos: Vector3) -> void:
	# Heavy reinforced concrete backstop target wall (35m wide, 8m high, 4m thick)
	map._create_wall(pos + Vector3(0.0, 4.0, 0.0), Vector3(35.0, 8.0, 4.0), map.mat_concrete)
	# Lateral earth revetments
	map._create_berm(pos + Vector3(-20.0, 0.0, -25.0), Vector3(6.0, 4.0, 50.0), 0.0)
	map._create_berm(pos + Vector3(20.0, 0.0, -25.0), Vector3(6.0, 4.0, 50.0), 0.0)

func _create_transformer_substation(pos: Vector3) -> void:
	# Transformer yard with concrete blast walls and transformer units
	var yard_size = 32.0
	# Concrete blast dividing wall
	map._create_wall(pos + Vector3(0.0, 2.5, 0.0), Vector3(yard_size, 5.0, 1.8), map.mat_concrete)

	# 3 Heavy Electrical Transformers
	for i in range(3):
		var tx_pos = pos + Vector3(float(i) * 8.0 - 8.0, 0.0, -6.0)
		map._create_wall(tx_pos + Vector3(0.0, 2.2, 0.0), Vector3(4.5, 4.4, 3.8), map.mat_steel)

		# Bushing insulator horns
		for bx in [-1.2, 0.0, 1.2]:
			var bush = MeshInstance3D.new()
			var bm = CylinderMesh.new()
			bm.top_radius = 0.14
			bm.bottom_radius = 0.22
			bm.height = 2.2
			bm.material = map.mat_concrete
			bush.mesh = bm
			bush.position = tx_pos + Vector3(bx, 5.5, 0.0)
			add_child(bush)

func _create_water_tower(pos: Vector3) -> void:
	var tower = Node3D.new()
	tower.position = pos
	add_child(tower)

	var height = 24.0
	var leg_span = 7.5

	# 4 Steel trestle legs
	for ox in [-1.0, 1.0]:
		for oz in [-1.0, 1.0]:
			var leg = MeshInstance3D.new()
			var lm = CylinderMesh.new()
			lm.top_radius = 0.22
			lm.bottom_radius = 0.28
			lm.height = height
			lm.material = map.mat_steel
			leg.mesh = lm
			leg.position = Vector3(ox * leg_span * 0.5, height * 0.5, oz * leg_span * 0.5)
			tower.add_child(leg)

	# Large spherical / cylindrical water tank reservoir
	var tank = StaticBody3D.new()
	tank.position = Vector3(0.0, height + 4.5, 0.0)
	tower.add_child(tank)

	var col = CollisionShape3D.new()
	var cyl = CylinderShape3D.new()
	cyl.radius = 5.5
	cyl.height = 7.0
	col.shape = cyl
	tank.add_child(col)

	var mi = MeshInstance3D.new()
	var cm = CylinderMesh.new()
	cm.top_radius = 5.5
	cm.bottom_radius = 5.5
	cm.height = 7.0
	cm.material = map.mat_rust
	mi.mesh = cm
	tank.add_child(mi)

	# Central supply riser pipe
	var riser = MeshInstance3D.new()
	var rm = CylinderMesh.new()
	rm.top_radius = 0.55
	rm.bottom_radius = 0.55
	rm.height = height
	rm.material = map.mat_pipe
	riser.mesh = rm
	riser.position = Vector3(0.0, height * 0.5, 0.0)
	tower.add_child(riser)

	# Base collision
	map._create_wall(pos + Vector3(0.0, 2.5, 0.0), Vector3(leg_span, 5.0, leg_span), map.mat_steel)
