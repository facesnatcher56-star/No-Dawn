extends Node3D
class_name MapInfrastructureBuilder
## Builds trans-battlefield roads, rail networks, electrical power grid, and perimeter infrastructure
## across the entire 3,600m x 3,600m map.

var map: IndustrialMapBuilder

func build(p_map: IndustrialMapBuilder) -> void:
	map = p_map
	_build_highways()
	_build_trans_battlefield_railways()
	_build_high_voltage_power_grid()
	_build_perimeter_gatehouses()

# -----------------------------------------------------------------------------
# 1. HIGHWAY & ROAD NETWORK (3,600m SPAN)
# -----------------------------------------------------------------------------
func _build_highways() -> void:
	# Primary East-West Highway along Z = 110.0 (Spans full map from X = -1750 to +1750)
	# NOTE: The central travel & firing lane Z in [105, 115] is kept strictly clear of colliders!
	_create_road(Vector3(0.0, 0.02, 110.0), Vector3(3500.0, 0.04, 12.0), true)
	_create_road_curbs(Vector3(0.0, 0.08, 103.8), Vector3(3500.0, 0.16, 0.35))
	_create_road_curbs(Vector3(0.0, 0.08, 116.2), Vector3(3500.0, 0.16, 0.35))

	# Roadside streetlights and telegraph poles along the full 3.5km East-West highway
	# Placed outside the maneuver corridor (Z = 117.5 north, Z = 102.5 south)
	for x in range(-1650, 1700, 75):
		# Skip central core road section already populated in base builder
		if x >= -200 and x <= 150:
			continue
		map._create_lamp_post(Vector3(float(x), 0.0, 117.5))
		map._create_utility_pole(Vector3(float(x), 0.0, 102.5))
		if absi(x) % 150 == 0:
			map._create_jersey_barrier(Vector3(float(x) + 12.0, 0.0, 117.2))
			map._create_jersey_barrier(Vector3(float(x) - 18.0, 0.0, 102.8))

	# Northern Secondary Arterial Highway along Z = -650.0 (Spans X = -1600 to +1600)
	_create_road(Vector3(0.0, 0.02, -650.0), Vector3(3200.0, 0.04, 11.0), true)
	_create_road_curbs(Vector3(0.0, 0.08, -655.8), Vector3(3200.0, 0.16, 0.35))
	_create_road_curbs(Vector3(0.0, 0.08, -644.2), Vector3(3200.0, 0.16, 0.35))

	# Southern Heavy Transport Highway along Z = 750.0 (Spans X = -1600 to +1600)
	_create_road(Vector3(0.0, 0.02, 750.0), Vector3(3200.0, 0.04, 11.0), true)
	_create_road_curbs(Vector3(0.0, 0.08, 744.2), Vector3(3200.0, 0.16, 0.35))
	_create_road_curbs(Vector3(0.0, 0.08, 755.8), Vector3(3200.0, 0.16, 0.35))

	# North-South Connecting Highways:
	# 1. Western Cross-Highway at X = -950.0 (connecting Z = -1600 to +1600)
	_create_road(Vector3(-950.0, 0.02, 0.0), Vector3(11.0, 0.04, 3200.0), false)
	# 2. Eastern Cross-Highway at X = 950.0 (connecting Z = -1600 to +1600)
	_create_road(Vector3(950.0, 0.02, 0.0), Vector3(11.0, 0.04, 3200.0), false)
	# 3. Outer Western Access Road at X = -1450.0
	_create_road(Vector3(-1450.0, 0.02, 0.0), Vector3(9.0, 0.04, 2800.0), false)
	# 4. Outer Eastern Access Road at X = 1450.0
	_create_road(Vector3(1450.0, 0.02, 0.0), Vector3(9.0, 0.04, 2800.0), false)

func _create_road(pos: Vector3, size: Vector3, is_east_west: bool) -> void:
	var road = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = size
	bm.material = map.mat_road
	road.mesh = bm
	road.position = pos
	add_child(road)

	# Center dashed marking stripes
	if is_east_west:
		var half_len = size.x * 0.5
		var start_x = pos.x - half_len + 10.0
		var end_x = pos.x + half_len - 10.0
		for sx in range(int(start_x), int(end_x), 18):
			var stripe = MeshInstance3D.new()
			var sm = BoxMesh.new()
			sm.size = Vector3(6.0, 0.06, 0.4)
			sm.material = map.mat_stripe
			stripe.mesh = sm
			stripe.position = Vector3(float(sx), pos.y + 0.01, pos.z)
			add_child(stripe)
	else:
		var half_len = size.z * 0.5
		var start_z = pos.z - half_len + 10.0
		var end_z = pos.z + half_len - 10.0
		for sz in range(int(start_z), int(end_z), 18):
			var stripe = MeshInstance3D.new()
			var sm = BoxMesh.new()
			sm.size = Vector3(0.4, 0.06, 6.0)
			sm.material = map.mat_stripe
			stripe.mesh = sm
			stripe.position = Vector3(pos.x, pos.y + 0.01, float(sz))
			add_child(stripe)

func _create_road_curbs(pos: Vector3, size: Vector3) -> void:
	var curb = MeshInstance3D.new()
	var cm = BoxMesh.new()
	cm.size = size
	cm.material = map.mat_concrete
	curb.mesh = cm
	curb.position = pos
	add_child(curb)

# -----------------------------------------------------------------------------
# 2. TRANS-BATTLEFIELD RAILWAY TRUNKS & FREIGHT SIDINGS
# -----------------------------------------------------------------------------
func _build_trans_battlefield_railways() -> void:
	# Main Railway Trunk Lines (East-West across 3,200m):
	# Line 1: North Industrial Rail Trunk at Z = -200.0
	_create_rail_line(Vector3(0.0, 0.08, -200.0), 3200.0)
	# Line 2: South Freight Rail Trunk at Z = 450.0
	_create_rail_line(Vector3(0.0, 0.08, 450.0), 3200.0)
	# Line 3: Outer Southern Heavy Haul Trunk at Z = 950.0
	_create_rail_line(Vector3(0.0, 0.08, 950.0), 3000.0)

	# Freight Trains distributed across the expansive railway network
	# Northern Rail Line trains:
	map._create_train_car(Vector3(-1350.0, 0.0, -200.0), true)
	map._create_train_car(Vector3(-1325.0, 0.0, -200.0), true)
	map._create_train_car(Vector3(-1300.0, 0.0, -200.0), false)
	map._create_train_car(Vector3(-850.0, 0.0, -200.0), true)
	map._create_train_car(Vector3(-825.0, 0.0, -200.0), false)
	map._create_train_car(Vector3(650.0, 0.0, -200.0), true)
	map._create_train_car(Vector3(675.0, 0.0, -200.0), true)
	map._create_train_car(Vector3(1250.0, 0.0, -200.0), false)
	map._create_train_car(Vector3(1275.0, 0.0, -200.0), true)

	# South Freight Line trains:
	map._create_train_car(Vector3(-1150.0, 0.0, 450.0), true)
	map._create_train_car(Vector3(-1125.0, 0.0, 450.0), false)
	map._create_train_car(Vector3(-600.0, 0.0, 450.0), true)
	map._create_train_car(Vector3(-575.0, 0.0, 450.0), true)
	map._create_train_car(Vector3(500.0, 0.0, 450.0), false)
	map._create_train_car(Vector3(525.0, 0.0, 450.0), true)
	map._create_train_car(Vector3(1050.0, 0.0, 450.0), true)
	map._create_train_car(Vector3(1075.0, 0.0, 450.0), false)

	# Outer Southern Line trains:
	map._create_train_car(Vector3(-750.0, 0.0, 950.0), true)
	map._create_train_car(Vector3(-725.0, 0.0, 950.0), true)
	map._create_train_car(Vector3(750.0, 0.0, 950.0), true)
	map._create_train_car(Vector3(775.0, 0.0, 950.0), false)

func _create_rail_line(pos: Vector3, length: float) -> void:
	# Concrete / crushed stone ballast
	var ballast = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = Vector3(length, 0.15, 6.0)
	bm.material = map.mat_concrete
	ballast.mesh = bm
	ballast.position = pos
	add_child(ballast)

	# Dual steel rails
	for side in [-1.2, 1.2]:
		var rail = MeshInstance3D.new()
		var rm = BoxMesh.new()
		rm.size = Vector3(length, 0.25, 0.16)
		rm.material = map.mat_steel
		rail.mesh = rm
		rail.position = pos + Vector3(0.0, 0.14, side)
		add_child(rail)

# -----------------------------------------------------------------------------
# 3. HIGH-VOLTAGE ELECTRICAL POWER GRID (STEEL TRANSMISSION PYLONS)
# -----------------------------------------------------------------------------
func _build_high_voltage_power_grid() -> void:
	# Power Transmission Corridor North: Z = -450.0 across X = -1600 to +1600
	for px in range(-1500, 1600, 250):
		_create_transmission_pylon(Vector3(float(px), 0.0, -450.0))

	# Power Transmission Corridor South: Z = 600.0 across X = -1600 to +1600
	for px in range(-1500, 1600, 250):
		_create_transmission_pylon(Vector3(float(px), 0.0, 600.0))

func _create_transmission_pylon(pos: Vector3) -> void:
	# High-voltage lattice pylon (height = 28m)
	var pylon = Node3D.new()
	pylon.position = pos
	add_child(pylon)

	var height = 28.0
	var base_w = 4.5
	var top_w = 1.8

	# 4 structural corner legs (tapering upwards)
	for ox in [-1.0, 1.0]:
		for oz in [-1.0, 1.0]:
			var leg = MeshInstance3D.new()
			var lm = BoxMesh.new()
			lm.size = Vector3(0.35, height, 0.35)
			lm.material = map.mat_steel
			leg.mesh = lm
			leg.position = Vector3(ox * (base_w + top_w) * 0.25, height * 0.5, oz * (base_w + top_w) * 0.25)
			leg.rotation.z = -ox * 0.045
			leg.rotation.x = oz * 0.045
			pylon.add_child(leg)

	# Crossarms holding insulators
	for h_tier in [18.0, 23.0, 27.0]:
		var span = 14.0 if h_tier < 24.0 else 10.0
		var arm = MeshInstance3D.new()
		var am = BoxMesh.new()
		am.size = Vector3(span, 0.45, 0.45)
		am.material = map.mat_steel
		arm.mesh = am
		arm.position = Vector3(0.0, h_tier, 0.0)
		pylon.add_child(arm)

		# Ceramic insulator strings
		for side in [-1.0, 1.0]:
			var ins = MeshInstance3D.new()
			var im = CylinderMesh.new()
			im.top_radius = 0.12
			im.bottom_radius = 0.12
			im.height = 1.6
			im.material = map.mat_concrete
			ins.mesh = im
			ins.position = Vector3(side * (span * 0.45), h_tier - 0.9, 0.0)
			pylon.add_child(ins)

	# Static collision body for pylon base so tanks collide with tower legs
	map._create_wall(pos + Vector3(0.0, 3.0, 0.0), Vector3(base_w, 6.0, base_w), map.mat_steel)

# -----------------------------------------------------------------------------
# 4. PERIMETER GATEHOUSES & CHECKPOINTS
# -----------------------------------------------------------------------------
func _build_perimeter_gatehouses() -> void:
	# Major outer entrance gatehouses through the perimeter walls at 1800m
	# West Main Gate (X = -1780, Z = 110)
	_create_gatehouse_checkpoint(Vector3(-1760.0, 0.0, 110.0), true)
	# East Main Gate (X = 1780, Z = 110)
	_create_gatehouse_checkpoint(Vector3(1760.0, 0.0, 110.0), true)
	# North Highway Gate (X = -60, Z = -1760)
	_create_gatehouse_checkpoint(Vector3(-60.0, 0.0, -1760.0), false)
	# South Highway Gate (X = -60, Z = 1760)
	_create_gatehouse_checkpoint(Vector3(-60.0, 0.0, 1760.0), false)

func _create_gatehouse_checkpoint(pos: Vector3, is_east_west: bool) -> void:
	# Heavy concrete security bunker / gatehouse flanked on either side of the road
	var offset1: Vector3
	var offset2: Vector3
	var b_size: Vector3
	if is_east_west:
		offset1 = Vector3(0.0, 0.0, -16.0)
		offset2 = Vector3(0.0, 0.0, 16.0)
		b_size = Vector3(14.0, 6.5, 10.0)
	else:
		offset1 = Vector3(-16.0, 0.0, 0.0)
		offset2 = Vector3(16.0, 0.0, 0.0)
		b_size = Vector3(10.0, 6.5, 14.0)

	map._create_wall(pos + offset1 + Vector3(0.0, 3.25, 0.0), b_size, map.mat_concrete)
	map._create_wall(pos + offset2 + Vector3(0.0, 3.25, 0.0), b_size, map.mat_concrete)

	# Overhead steel gantry bar
	var bar_span = 38.0
	var bar = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = Vector3(2.5, 1.2, bar_span) if is_east_west else Vector3(bar_span, 1.2, 2.5)
	bm.material = map.mat_steel
	bar.mesh = bm
	bar.position = pos + Vector3(0.0, 7.5, 0.0)
	add_child(bar)
