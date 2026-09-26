extends SceneTree

const ArmorModel = preload("res://scripts/wego/ArmorModel.gd")
const AmmunitionData = preload("res://scripts/wego/AmmunitionData.gd")
const BallisticsModel = preload("res://scripts/wego/BallisticsModel.gd")
const VehicleConfig = preload("res://scripts/wego/VehicleConfig.gd")
const ConcurrentScheduler = preload("res://scripts/wego/ConcurrentScheduler.gd")
const FiringSolution = preload("res://scripts/wego/FiringSolution.gd")
const ContactTrack = preload("res://scripts/wego/ContactTrack.gd")
const TacticalVehicle = preload("res://scripts/wego/TacticalVehicle.gd")

var failures: int = 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		print("  ❌ FAIL: ", message)
	else:
		print("  ✅ PASS: ", message)

func _init() -> void:
	print("==================================================")
	print("  TANK SIMULATION REWORK: 14 VALIDATION SCENARIOS ")
	print("==================================================")
	
	test_01_stationary_short_range()
	test_02_kinetic_penetration_range_falloff()
	test_03_heat_range_independence()
	test_04_stationary_gunnery_solution()
	test_05_stabilized_firing_on_move()
	test_06_rough_terrain_disturbance()
	test_07_unstabilized_tank_movement_penalty()
	test_08_concurrent_crew_channels()
	test_09_loader_casualty_isolation()
	test_10_gunner_casualty_substitution()
	test_11_hull_turn_turret_counter_rotation()
	test_12_stabilizer_damage_degradation()
	test_13_sloped_armor_ricochet()
	test_14_component_damage_consequences()
	
	print("==================================================")
	print("Simulation Rework checks completed. Total Failures: ", failures)
	print("==================================================")
	quit(failures)

func test_01_stationary_short_range() -> void:
	print("\n--- Test 1: Stationary Tank, Stationary Target at Short Range (50m) ---")
	var target = ArmorModel.new(25)
	var ammo = AmmunitionData.create_apcbc()
	var origin = Vector3(0, 1.25, -50.0) # 50m in front
	var dir = Vector3(0, 0, 1)
	
	var shot = target.resolve(origin, dir, ammo.get_velocity_at_range(50.0), 1234, ammo, 50.0)
	check(shot.result == "PENETRATION", "APCBC penetrates front glacis at 50m short range")
	check(not shot.impacts.is_empty(), "Armor impact registered")
	check(shot.impacts[0].residual_penetration_mm > 0.0, "Substantial residual penetration remains after defeating armor")
	check(shot.has("debug_report"), "Developer debug shot report generated")

func test_02_kinetic_penetration_range_falloff() -> void:
	print("\n--- Test 2: Kinetic Penetration vs Range Falloff (Ammunition-Specific Curves) ---")
	var apcbc = AmmunitionData.create_apcbc()
	var apcr = AmmunitionData.create_apcr()
	
	var pen_100 = apcbc.get_penetration_at_range(100.0)
	var pen_500 = apcbc.get_penetration_at_range(500.0)
	var pen_1000 = apcbc.get_penetration_at_range(1000.0)
	var pen_1500 = apcbc.get_penetration_at_range(1500.0)
	var pen_2000 = apcbc.get_penetration_at_range(2000.0)
	
	check(pen_100 > pen_500 and pen_500 > pen_1000 and pen_1000 > pen_1500 and pen_1500 > pen_2000, 
		"APCBC penetration decreases strictly with range due to aerodynamic velocity loss")
		
	var v_0 = apcbc.muzzle_velocity
	var v_1000 = apcbc.get_velocity_at_range(1000.0)
	var v_2000 = apcbc.get_velocity_at_range(2000.0)
	check(v_0 > v_1000 and v_1000 > v_2000, "Velocity degrades continuously across 2000m flight")
	
	# APCR loses velocity faster than APCBC due to higher drag factor
	var apcr_pen_0 = apcr.get_penetration_at_range(0.0)
	var apcr_pen_2000 = apcr.get_penetration_at_range(2000.0)
	check(apcr_pen_0 > pen_100, "APCR has higher point-blank penetration than APCBC (275mm vs 215mm)")
	check((apcr_pen_0 - apcr_pen_2000) > (pen_100 - pen_2000), "Lightweight APCR suffers sharper drop-off than heavy APCBC")

func test_03_heat_range_independence() -> void:
	print("\n--- Test 3: Chemical Energy (HEAT) Range Independence ---")
	var heat = AmmunitionData.create_heat()
	check(heat.category == AmmunitionData.Category.CHEMICAL, "HEAT categorized as CHEMICAL energy")
	
	var heat_pen_100 = heat.get_penetration_at_range(100.0)
	var heat_pen_500 = heat.get_penetration_at_range(500.0)
	var heat_pen_1000 = heat.get_penetration_at_range(1000.0)
	var heat_pen_1800 = heat.get_penetration_at_range(1800.0)
	
	check(is_equal_approx(heat_pen_100, 185.0), "HEAT has nominal 185mm penetration at 100m")
	check(is_equal_approx(heat_pen_100, heat_pen_500) and is_equal_approx(heat_pen_500, heat_pen_1000) and is_equal_approx(heat_pen_1000, heat_pen_1800),
		"HEAT penetration is completely independent of range (shaped charge jet does not rely on kinetic striking velocity)")

func test_04_stationary_gunnery_solution() -> void:
	print("\n--- Test 4: Stationary Tank Firing at Stationary Target ---")
	var shooter = TacticalVehicle.new()
	shooter.speed = 0.0
	shooter.yaw_rate = 0.0
	shooter.terrain_roughness = 0.0
	shooter.position = Vector3(0, 0, 0)
	
	var track = ContactTrack.new("TEST")
	track.estimated_position = Vector3(0, 1.45, -120.0)
	track.gunner_acquired = true
	track.range_uncertainty = 4.0
	track.position_uncertainty = 2.0
	track.has_visual_los = true
	
	var rng = RandomNumberGenerator.new()
	rng.seed = 42
	var sol = FiringSolution.calculate(shooter, track, rng, 880.0)
	
	check(sol.solution_quality == "OPTIMAL", "Stationary tracked target produces OPTIMAL solution")
	check(sol.dispersion_cone_rad <= 0.0015, "Stationary platform maintains tight mechanical weapon dispersion")
	check(sol.lead_offset.length() < 0.1, "Zero target motion produces zero lead offset")

func test_05_stabilized_firing_on_move() -> void:
	print("\n--- Test 5: Stabilized Tank Moving Smoothly and Firing on the Move ---")
	var shooter = TacticalVehicle.new()
	shooter.config.gun_stabilization = "BASIC_TWO_AXIS"
	shooter.speed = 2.8 # Smooth speed (~10 km/h)
	shooter.yaw_rate = 0.0
	shooter.terrain_roughness = 0.05
	
	var track = ContactTrack.new("TEST")
	track.estimated_position = Vector3(0, 1.45, -100.0)
	track.gunner_acquired = true
	track.range_uncertainty = 6.0
	track.has_visual_los = true
	
	var rng = RandomNumberGenerator.new()
	rng.seed = 42
	var sol = FiringSolution.calculate(shooter, track, rng, 880.0)
	
	check(sol.solution_quality in ["OPTIMAL", "ACQUIRED"], "Stabilized tank retains accurate firing solution during smooth movement")
	check(sol.dispersion_cone_rad <= 0.0025, "Dispersion cone remains tight under stabilized smooth movement")

func test_06_rough_terrain_disturbance() -> void:
	print("\n--- Test 6: Same Tank Moving Quickly Over Rough Terrain ---")
	var shooter = TacticalVehicle.new()
	shooter.config.gun_stabilization = "BASIC_TWO_AXIS"
	shooter.speed = 6.8 # High speed
	shooter.yaw_rate = 0.35 # Turning rapidly
	shooter.terrain_roughness = 0.40 # Heavy bumps
	
	var track = ContactTrack.new("TEST")
	track.estimated_position = Vector3(0, 1.45, -100.0)
	track.gunner_acquired = true
	track.range_uncertainty = 6.0
	track.has_visual_los = true
	
	var rng = RandomNumberGenerator.new()
	rng.seed = 42
	var sol = FiringSolution.calculate(shooter, track, rng, 880.0)
	
	check(sol.dispersion_cone_rad > 0.006, "High speed + rough terrain + hull turn severely degrades dispersion cone")

func test_07_unstabilized_tank_movement_penalty() -> void:
	print("\n--- Test 7: Unstabilized Tank Attempting Movement Gunnery ---")
	var shooter = TacticalVehicle.new()
	shooter.config.gun_stabilization = "NONE" # WWII unstabilized platform
	shooter.speed = 2.8
	shooter.yaw_rate = 0.1
	shooter.terrain_roughness = 0.1
	
	var track = ContactTrack.new("TEST")
	track.estimated_position = Vector3(0, 1.45, -100.0)
	track.gunner_acquired = true
	track.range_uncertainty = 6.0
	track.has_visual_los = true
	
	var rng = RandomNumberGenerator.new()
	rng.seed = 42
	var sol = FiringSolution.calculate(shooter, track, rng, 880.0)
	
	check(sol.solution_quality != "OPTIMAL", "Unstabilized tank cannot achieve OPTIMAL solution while moving")
	check(sol.dispersion_cone_rad > 0.015, "Unstabilized moving platform receives massive aim disturbance")
	check(not shooter.ready_to_shoot(), "Unstabilized tank is prohibited by doctrine/aim from firing while moving")

func test_08_concurrent_crew_channels() -> void:
	print("\n--- Test 8: Concurrent Crew Channels (Driver, Gunner, Loader, Commander) ---")
	var tank = TacticalVehicle.new()
	var sched = ConcurrentScheduler.new()
	
	# Append 4 actions using 4 distinct crew members
	sched.append_action("move", Vector3(10, 0, 0), 4.0)       # DRIVER + HULL_POWERTRAIN
	sched.append_action("aim", Vector3(0, 1.4, -75.0), 2.0)   # GUNNER + TURRET_DRIVE
	sched.append_action("reload", Vector3.ZERO, 6.5)          # LOADER + MAIN_GUN
	sched.append_action("scan", Vector3(0, 1.4, 50.0), 2.0)   # COMMANDER + OPTICS_FCS
	
	var timeline = sched.schedule_timeline(tank)
	check(timeline.size() == 4, "All 4 actions scheduled")
	check(timeline[0].crew == "DRIVER" and timeline[0].start_time == 0.0, "Driver starts move at t=0.0")
	check(timeline[1].crew == "GUNNER" and timeline[1].start_time == 0.0, "Gunner starts aim concurrently at t=0.0")
	check(timeline[2].crew == "LOADER" and timeline[2].start_time == 0.0, "Loader starts reload concurrently at t=0.0")
	check(timeline[3].crew == "COMMANDER" and timeline[3].start_time == 0.0, "Commander starts scan concurrently at t=0.0")
	
	var ascii = sched.render_ascii_timeline(tank)
	check(ascii.contains("DRIVER") and ascii.contains("GUNNER") and ascii.contains("LOADER") and ascii.contains("COMMANDER"),
		"Timeline visualization renders all 4 parallel crew channels")

func test_09_loader_casualty_isolation() -> void:
	print("\n--- Test 9: Loader Casualty Isolated (No Impact on Driver Movement) ---")
	var tank = TacticalVehicle.new()
	var sched = ConcurrentScheduler.new()
	
	# Incapacitate loader
	for c in tank.model.crew:
		if c.name == "Loader":
			c.state = "Incapacitated"
			
	check(tank.model.can_move(), "Driver can drive: mobility is 100% operational despite loader casualty")
	
	sched.append_action("move", Vector3(10, 0, 0), 3.0)
	sched.append_action("reload", Vector3.ZERO)
	var timeline = sched.schedule_timeline(tank)
	
	check(timeline[0].crew == "DRIVER" and timeline[0].duration > 0.0, "Driver movement operates normally")
	check(timeline[1].duration > 15.0, "Reload time increases substantially (3.5x penalty) when turret crew must substitute")

func test_10_gunner_casualty_substitution() -> void:
	print("\n--- Test 10: Gunner Casualty Substitution via Commander Override ---")
	var tank = TacticalVehicle.new()
	var sched = ConcurrentScheduler.new()
	
	# Incapacitate gunner
	for c in tank.model.crew:
		if c.name == "Gunner":
			c.state = "Dead"
			
	sched.append_action("aim", Vector3(50, 1.4, 0))
	var timeline = sched.schedule_timeline(tank)
	
	check(timeline[0].reason.is_empty(), "Commander weapon override allows aiming despite gunner loss")
	check(timeline[0].duration > 2.0, "Commander operating gunner controls incurs substitution penalty")

func test_11_hull_turn_turret_counter_rotation() -> void:
	print("\n--- Test 11: Turret Stabilization / Counter-Rotation During Rapid Hull Turn ---")
	var tank = TacticalVehicle.new()
	tank.position = Vector3(0, 0, 0)
	tank.rotation.y = 0.0
	tank.model.turret_yaw = 0.0
	var target_world_bearing: float = 0.0 # Straight ahead (-Z) in world space
	
	# Commit orders to turn hull by 30 degrees while aiming straight ahead
	tank.commit({"pivot": 30.0, "aim_point": Vector3(0, 1.4, -100.0), "engine": true})
	
	# Step through turn
	for i in range(12):
		tank.step(0.1)
		
	var world_gun_heading = tank.rotation.y + tank.model.turret_yaw
	check(tank.rotation.y > deg_to_rad(10.0), "Hull has physically pivoted during turn")
	check(absf(angle_difference(world_gun_heading, target_world_bearing)) < 0.05,
		"Turret counter-rotates against hull turn to maintain target bearing in world space")

func test_12_stabilizer_damage_degradation() -> void:
	print("\n--- Test 12: Stabilizer Damage Degradation ---")
	var shooter = TacticalVehicle.new()
	shooter.config.gun_stabilization = "BASIC_TWO_AXIS"
	shooter.speed = 3.0
	shooter.stabilizer_damaged = true # Damage the gyroscopic stabilizer
	
	var track = ContactTrack.new("TEST")
	track.estimated_position = Vector3(0, 1.45, -100.0)
	track.gunner_acquired = true
	track.has_visual_los = true
	
	var rng = RandomNumberGenerator.new()
	rng.seed = 42
	var sol = FiringSolution.calculate(shooter, track, rng, 880.0)
	
	check(sol.solution_quality != "OPTIMAL", "Stabilizer damage downgrades system to unstabilized behavior")
	check(sol.dispersion_cone_rad > 0.010, "Damaged stabilizer produces physical dispersion penalty during movement")

func test_13_sloped_armor_ricochet() -> void:
	print("\n--- Test 13: Strongly Sloped Armor Ricochet Behavior ---")
	var target = ArmorModel.new(25)
	var ammo = AmmunitionData.create_apcbc()
	
	# Grazing strike against plate at 76 degrees incidence
	var tangent = Vector3(0.97, 0, 0.24).normalized()
	var origin = Vector3(0, 1.25, -2.9) - tangent * 20.0
	
	var shot = target.resolve(origin, tangent, 880.0, 42, ammo, 50.0)
	check(shot.result == "RICOCHET", "Impact at 76° incidence triggers ricochet")
	check(shot.paths.size() >= 2, "Ricochet deflects projectile away without internal spall")
	check(shot.effects.is_empty(), "Ricochet causes zero internal damage")

func test_14_component_damage_consequences() -> void:
	print("\n--- Test 14: Non-HP Physical Component Damage & Consequences ---")
	# Shot A: Penetrate engine compartment from the rear
	var tank_a = ArmorModel.new(25)
	var ammo = AmmunitionData.create_apcbc()
	var shot_a = tank_a.resolve(Vector3(0, 1.1, 8.0), Vector3(0, 0, -1), 880.0, 100, ammo, 20.0)
	check(shot_a.result == "PENETRATION", "Rear shot penetrates rear hull")
	check(not tank_a.functional("Engine"), "Engine disabled by rear penetration")
	check(not tank_a.can_move(), "Loss of engine results in mobility kill without generic vehicle HP")
	
	# Shot B: Hit ammunition rack
	var tank_b = ArmorModel.new(25)
	var shot_b = tank_b.resolve(Vector3(0, 0.6, -8.0), Vector3(0, 0, 1), 880.0, 200, ammo, 20.0)
	check(shot_b.result == "PENETRATION", "Shot penetrates into lower hull")
	check(tank_b.catastrophic, "Penetration intersecting ammo rack triggers ammunition detonation & catastrophic loss")
