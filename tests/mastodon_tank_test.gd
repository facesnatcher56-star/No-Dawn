extends SceneTree

const PLAYER_SCENE = preload("res://scenes/tank/A47_Mastodon_Player.tscn")
const INSPECTION_SCENE = preload("res://scenes/tank/TankInspection.tscn")
const A47_Mastodon_Vehicle = preload("res://scripts/tank/A47_Mastodon_Vehicle.gd")
const MastodonMetadata = preload("res://scripts/tank/MastodonMetadata.gd")
const MastodonVisualController = preload("res://scripts/tank/MastodonVisualController.gd")
const MastodonAnimationController = preload("res://scripts/tank/MastodonAnimationController.gd")
const TankInspection = preload("res://scripts/tank/TankInspection.gd")

var failures: int = 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: %s" % message)
		print("  ❌ FAIL: %s" % message)
	else:
		print("  ✅ PASS: %s" % message)

func _init() -> void:
	print("==================================================")
	print("   A-47 MASTODON TANK SIMULATION TEST SUITE")
	print("==================================================")
	
	test_player_instantiation_and_structure()
	test_metadata_specifications()
	test_crew_and_compartments()
	test_powertrain_and_internal_components()
	test_armament_and_recoil_system()
	test_kinematics_and_articulation()
	test_visual_controller_modes()
	test_inspection_scene()
	
	print("==================================================")
	print("Mastodon Tank tests completed. Total Failures: %d" % failures)
	print("==================================================")
	quit(failures)

func test_player_instantiation_and_structure() -> void:
	print("\n--- 1. Vehicle Scene Instantiation & Hierarchy ---")
	var tank = PLAYER_SCENE.instantiate()
	check(tank != null, "A47_Mastodon_Player instantiates cleanly")
	check(tank is A47_Mastodon_Vehicle, "Root node script is A47_Mastodon_Vehicle")
	
	# Verify presence of core subsystems
	check(tank.metadata != null, "Metadata subsystem initialized")
	check(tank.visual != null, "Visual controller subsystem initialized")
	check(tank.anim != null, "Animation controller subsystem initialized")
	
	# Verify major pivot nodes
	check(tank.anim.turret_pivot != null, "TurretPivot exists in hierarchy")
	check(tank.anim.gun_elev_pivot != null, "GunElevationPivot exists in hierarchy")
	check(tank.anim.gun_assembly != null, "GunAssembly exists in hierarchy")
	check(tank.anim.cmd_hatch_pivot != null, "CommanderHatchPivot exists in hierarchy")
	check(tank.anim.loader_hatch_pivot != null, "LoaderHatchPivot exists in hierarchy")
	check(tank.anim.driver_hatch_pivot != null, "DriverHatchPivot exists in hierarchy")
	check(tank.anim.commander_crew != null, "Commander crew node exists for posture control")
	
	# Dimensions check
	var aabb = tank.get_approximate_dimensions()
	print("  Tank Bounding Box: Length (Z)=%.2fm, Width (X)=%.2fm, Height (Y)=%.2fm" % [aabb.size.z, aabb.size.x, aabb.size.y])
	# Total length with gun barrel is ~9.3m, hull is ~7.0m, width is ~3.6m, height is ~2.85m (3.87m with whip antenna)
	check(aabb.size.z >= 7.0 and aabb.size.z <= 11.0, "Total length is realistic (~9m with gun, >7m hull)")
	check(aabb.size.x >= 3.0 and aabb.size.x <= 4.0, "Vehicle width is realistic (~3.4m)")
	check(aabb.size.y >= 2.0 and aabb.size.y <= 4.5, "Vehicle height is realistic (~2.85m chassis, ~3.87m with whip antenna)")
	
	tank.free()

func test_metadata_specifications() -> void:
	print("\n--- 2. Metadata & Engineering Specifications ---")
	var meta = MastodonMetadata.new()
	check(meta.metadata.size() > 0, "Metadata loaded from mastodon_metadata.json")
	
	var vehicle = meta.get_vehicle_info()
	var dims = meta.metadata.get("dimensions", {})
	check(dims.get("hull_length") == 7.0, "Hull length specification is 7.0m")
	check(dims.get("hull_width") == 3.4, "Hull width specification is 3.4m")
	check(dims.get("total_length_with_gun") == 9.05, "Total length with gun is 9.05m")
	
	# Armor plates check
	var armor_names = meta.get_all_armor_names()
	check(armor_names.size() >= 10, "Armor plates count is comprehensive (%d sections found)" % armor_names.size())
	
	var upper_glacis = meta.get_armor_plate("ARM_UpperGlacis")
	check(upper_glacis.get("thickness_mm") == 90, "Upper Glacis thickness is 90mm")
	check(upper_glacis.get("slope_deg") == 55, "Upper Glacis slope is 55 degrees")
	
	var turret_front = meta.get_armor_plate("ARM_TurretFront")
	check(turret_front.get("thickness_mm") == 110, "Turret Front thickness is 110mm")
	
	var mantlet = meta.get_armor_plate("ARM_GunMantlet")
	check(mantlet.get("thickness_mm") == 120, "Mantlet thickness is 120mm")

func test_crew_and_compartments() -> void:
	print("\n--- 3. Crew & Compartments ---")
	var tank = PLAYER_SCENE.instantiate()
	var crew_names = tank.metadata.get_all_crew_names()
	check(crew_names.size() == 5, "Exact 5-person crew specification met (Found %d)" % crew_names.size())
	
	var expected_crew = ["CREW_Driver", "CREW_RadioOperator", "CREW_Gunner", "CREW_Loader", "CREW_Commander"]
	for crew_id in expected_crew:
		var info = tank.metadata.get_crew_member(crew_id)
		check(not info.is_empty(), "Crew member %s exists in metadata" % crew_id)
		var node = tank.find_child(crew_id, true, false)
		check(node != null, "Physical crew 3D node %s present in tank scene" % crew_id)
	
	# Verify firewall separating compartments
	var fw = tank.find_child("CMP_Firewall", true, false)
	check(fw != null, "Firewall present separating engine from fighting compartment")
	
	tank.free()

func test_powertrain_and_internal_components() -> void:
	print("\n--- 4. Powertrain & Internal Components ---")
	var tank = PLAYER_SCENE.instantiate()
	
	var expected_components = [
		"CMP_Engine",
		"CMP_Transmission",
		"CMP_LeftFinalDrive",
		"CMP_RightFinalDrive",
		"CMP_Driveshaft",
		"CMP_LeftFuelTank",
		"CMP_RightFuelTank",
		"CMP_Radio",
		"CMP_TurretRing",
		"CMP_TurretBasketFloor"
	]
	
	for cmp_id in expected_components:
		var node = tank.find_child(cmp_id, true, false)
		check(node != null, "Internal component node %s exists" % cmp_id)
		var info = tank.metadata.get_component(cmp_id)
		check(not info.is_empty(), "Component %s metadata exists with durability HP" % cmp_id)
	
	# Test ammo racks
	var ammo_names = tank.metadata.get_all_ammo_names()
	check(ammo_names.size() >= 3, "Multiple distinct ammo racks present (%d racks)" % ammo_names.size())
	var total_rounds = 0
	for rack_id in ammo_names:
		var node = tank.find_child(rack_id, true, false)
		check(node != null, "Ammunition rack 3D node %s exists" % rack_id)
		var rack_info = tank.metadata.get_ammo_rack(rack_id)
		total_rounds += rack_info.get("capacity", 0)
	
	check(total_rounds >= 60, "Total ammunition capacity is combat-realistic (%d rounds)" % total_rounds)
	
	tank.free()

func test_armament_and_recoil_system() -> void:
	print("\n--- 5. Armament & Recoil System ---")
	var tank = PLAYER_SCENE.instantiate()
	
	var breech = tank.find_child("CMP_MainGunBreech", true, false)
	var recoil_cylinders = tank.find_child("CMP_MainGunRecoilLeft", true, false)
	var barrel = tank.find_child("VIS_BarrelMainTube", true, false)
	var muzzle = tank.find_child("MKR_MainGun_Muzzle", true, false)
	
	check(breech != null, "Gun breech node CMP_MainGunBreech exists inside turret")
	check(recoil_cylinders != null, "Hydraulic recoil cylinders exist")
	check(barrel != null, "92mm main gun barrel node VIS_BarrelMainTube exists")
	check(muzzle != null, "Muzzle tip simulation marker MKR_MainGun_Muzzle exists")
	
	# Test recoil cycle
	var initial_z = tank.anim.gun_assembly.position.z
	tank.fire_recoil()
	check(tank.anim.is_recoiling, "Firing cannon triggers active recoil state")
	
	# Advance time through recoil stroke (at delta 0.035, progress is ~0.21, near peak 0.35m)
	tank.anim.update(0.035)
	var max_recoil_z = tank.anim.gun_assembly.position.z
	var displacement = max_recoil_z - initial_z
	print("  Measured gun recoil displacement: %.3fm (Target: ~0.350m)" % displacement)
	check(displacement > 0.25 and displacement <= 0.36, "Recoil kick produces ~350mm physical displacement")
	
	# Advance time through recuperator recovery (total cycle time is 1.0 / 6.0 = ~0.17s)
	tank.anim.update(0.2)
	check(not tank.anim.is_recoiling, "Recoil cycle completes and recuperates")
	check(absf(tank.anim.gun_assembly.position.z - initial_z) < 0.01, "Gun assembly returns to battery position")
	
	tank.free()

func test_kinematics_and_articulation() -> void:
	print("\n--- 6. Kinematics, Pivots & Articulation ---")
	var tank = PLAYER_SCENE.instantiate()
	
	# Turret traverse
	tank.rotate_turret(deg_to_rad(60.0))
	check(is_equal_approx(tank.anim.turret_pivot.rotation.y, deg_to_rad(60.0)), "Turret traverses around Y-axis to 60°")
	tank.rotate_turret(deg_to_rad(-120.0))
	check(is_equal_approx(tank.anim.turret_pivot.rotation.y, deg_to_rad(-120.0)), "Turret traverses around Y-axis to -120°")
	
	# Gun elevation limits
	tank.elevate_gun(deg_to_rad(15.0))
	check(is_equal_approx(tank.anim.gun_elev_pivot.rotation.x, deg_to_rad(15.0)), "Gun elevates to +15°")
	
	# Test clamping bounds (-8° to +20°)
	tank.elevate_gun(deg_to_rad(45.0))
	check(is_equal_approx(tank.anim.gun_elev_pivot.rotation.x, deg_to_rad(20.0)), "Gun elevation clamped to maximum +20°")
	
	tank.elevate_gun(deg_to_rad(-25.0))
	check(is_equal_approx(tank.anim.gun_elev_pivot.rotation.x, deg_to_rad(-8.0)), "Gun depression clamped to minimum -8°")
	
	# Commander hatch & posture
	check(not tank.anim.cmd_hatch_open, "Commander hatch starts closed")
	tank.anim.toggle_commander_hatch()
	check(tank.anim.cmd_hatch_open, "Commander hatch opens")
	check(tank.anim.cmd_hatch_pivot.rotation.x != 0.0, "Commander hatch pivot articulates on local hinge")
	
	var initial_cmd_y = tank.anim.commander_crew.position.y
	tank.anim.toggle_commander_posture()
	check(tank.anim.commander_exposed, "Commander transitions to exposed observing posture")
	check(tank.anim.commander_crew.position.y > initial_cmd_y + 0.4, "Commander figure elevates out of cupola into exposed stance")
	
	tank.anim.toggle_commander_posture()
	check(not tank.anim.commander_exposed, "Commander transitions back to buttoned posture")
	check(is_equal_approx(tank.anim.commander_crew.position.y, initial_cmd_y), "Commander figure lowers back to seated station")
	
	# Loader & Driver hatches
	tank.anim.toggle_loader_hatch()
	check(tank.anim.loader_hatch_open, "Loader hatch opens on hinge")
	tank.anim.toggle_driver_hatch()
	check(tank.anim.driver_hatch_open, "Driver hatch opens on hinge")
	
	# Wheel rotation
	tank.set_wheel_speed(5.0)
	var prev_wheel_rot = 0.0
	if tank.anim.road_wheels.size() > 0:
		prev_wheel_rot = tank.anim.road_wheels[0].rotation.x
	tank.anim.update(0.5)
	if tank.anim.road_wheels.size() > 0:
		check(tank.anim.road_wheels[0].rotation.x != prev_wheel_rot, "Road wheels articulate and spin with vehicle motion")
	
	tank.free()

func test_visual_controller_modes() -> void:
	print("\n--- 7. Visual Modes & X-Ray Rendering ---")
	var tank = PLAYER_SCENE.instantiate()
	
	# 1. NORMAL mode: exterior armor opaque, internals hidden
	tank.set_display_mode(MastodonVisualController.DisplayMode.NORMAL)
	check(tank.visual.current_mode == MastodonVisualController.DisplayMode.NORMAL, "Switched to NORMAL mode")
	var armor_sample = tank.find_child("ARM_UpperGlacis", true, false) as MeshInstance3D
	check(armor_sample != null and armor_sample.visible, "Armor is visible in NORMAL mode")
	var engine = tank.find_child("CMP_Engine", true, false) as MeshInstance3D
	check(engine != null and not engine.visible, "Internal engine hidden in NORMAL mode to optimize rendering")
	
	# 2. XRAY mode: exterior armor translucent, internals visible
	tank.set_display_mode(MastodonVisualController.DisplayMode.XRAY)
	check(tank.visual.current_mode == MastodonVisualController.DisplayMode.XRAY, "Switched to XRAY mode")
	check(armor_sample.visible, "Armor visible in XRAY mode")
	check(armor_sample.material_override != null, "Armor has transparent glass material override in XRAY mode")
	check(engine.visible, "Internal engine visible through armor in XRAY mode")
	
	# 3. CUTAWAY mode: exterior armor hidden, internals visible
	tank.set_display_mode(MastodonVisualController.DisplayMode.CUTAWAY)
	check(tank.visual.current_mode == MastodonVisualController.DisplayMode.CUTAWAY, "Switched to CUTAWAY mode")
	check(not armor_sample.visible, "Exterior armor hidden in CUTAWAY mode")
	check(engine.visible, "Internal engine visible in CUTAWAY mode")
	
	# 4. CREW_FOCUS mode
	tank.set_display_mode(MastodonVisualController.DisplayMode.CREW_FOCUS)
	var commander = tank.find_child("CREW_Commander", true, false) as MeshInstance3D
	check(commander != null and commander.visible, "Crew members visible in CREW_FOCUS mode")
	
	# 5. Component Highlight
	tank.highlight_component("CMP_Transmission")
	var trans = tank.find_child("CMP_Transmission", true, false) as MeshInstance3D
	check(trans != null and trans.material_override != null, "Targeted component highlighted with emissive override")
	
	# Clear highlight
	tank.highlight_component("")
	check(trans.material_override == null, "Targeted component highlight cleared")
	
	tank.free()

func test_inspection_scene() -> void:
	print("\n--- 8. TankInspection Scene Integration ---")
	var inspection = INSPECTION_SCENE.instantiate()
	check(inspection != null, "TankInspection scene instantiates successfully")
	check(inspection is TankInspection, "Root node is of type TankInspection")
	
	var tank_child = inspection.get_node_or_null("A47_Mastodon")
	check(tank_child != null and tank_child is A47_Mastodon_Vehicle, "A47_Mastodon vehicle node present in inspection scene")
	
	var cam_pivot = inspection.get_node_or_null("CameraPivot")
	var cam = inspection.get_node_or_null("CameraPivot/Camera3D")
	check(cam_pivot != null and cam != null, "Orbit camera and pivot correctly configured")
	
	inspection.free()
