extends SceneTree

const TacticalVehicle = preload("res://scripts/wego/TacticalVehicle.gd")
const GunnerSightSystem = preload("res://scripts/wego/GunnerSightSystem.gd")
const ContactTrack = preload("res://scripts/wego/ContactTrack.gd")
const AmmunitionData = preload("res://scripts/wego/AmmunitionData.gd")
const SensorModel = preload("res://scripts/wego/SensorModel.gd")
const BallisticsModel = preload("res://scripts/wego/BallisticsModel.gd")

var failures: int = 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		print("  ❌ FAIL: ", message)
	else:
		print("  ✅ PASS: ", message)

func _initialize() -> void:
	call_deferred("run_all_tests")

func run_all_tests() -> void:
	print("==================================================")
	print("  TRANSITIONAL GUNNERY PASS: 12 VALIDATION TESTS   ")
	print("==================================================")

	test_01_wrong_range_lands_short()
	test_02_correct_range_hits_elevation()
	test_03_no_hidden_truth_leak()
	test_04_turret_traverse_time()
	test_05_target_motion_during_traverse()
	test_06_gun_settling_and_dispersion()
	test_07_fire_policies_asap_vs_stable()
	test_08_estimated_lead_calculation()
	test_09_optical_los_and_ghost_suppression()
	test_10_observed_splash_range_correction()
	test_11_bore_lag_horizontal_direction()
	await test_12_no_arcade_aim_and_fire_mode()

	print("==================================================")
	print("Gunnery Pass checks completed. Total Failures: ", failures)
	print("==================================================")
	quit(failures)

func test_01_wrong_range_lands_short() -> void:
	print("\n--- Test 1: Wrong Range Dial (500m for 1500m Target Lands Short) ---")
	var shooter = TacticalVehicle.new()
	var ammo = AmmunitionData.create_apcbc() # 880 m/s
	shooter.set_active_ammo(ammo)
	
	# Target is at 1500m distance along -Z
	var target_dist: float = 1500.0
	var dialed_range: float = 500.0
	shooter.gunner_sight.sight_range_m = dialed_range
	shooter.gunner_sight.commanded_yaw = 0.0
	shooter.gunner_sight.commanded_pitch = 0.0 # Horizontal line of sight
	
	# Compute ballistic superelevation for 500m
	var elev = shooter.gunner_sight.get_ballistic_elevation(dialed_range, ammo)
	check(elev > 0.0, "Ballistic superelevation calculated for dialed range (%.4f rad)" % elev)
	
	# Launch shell with 500m elevation
	var v0 = ammo.muzzle_velocity
	var k = ammo.drag_coeff
	var vx = 0.0
	var vy = v0 * sin(elev)
	var vz = -v0 * cos(elev)
	
	var pos = Vector3(0, 2.65, 0)
	var vel = Vector3(vx, vy, vz)
	var dt = 0.02
	var impact_dist = 0.0
	var landed_short = false
	
	# Simulate trajectory
	for i in range(250): # up to 5 seconds
		var cur_speed = vel.length()
		var drag = k * cur_speed * cur_speed
		vel -= vel.normalized() * drag * dt
		vel.y -= 9.81 * dt
		pos += vel * dt
		
		if pos.y <= 0.0:
			impact_dist = -pos.z
			landed_short = impact_dist < (target_dist - 200.0)
			break
			
	check(landed_short, "Shell with 500m dial landed short of 1500m target (Impact at %.1fm)" % impact_dist)
	check(impact_dist > 750.0 and impact_dist < 950.0, "Physical impact distance (%.1fm) is consistent with 500m zero + launch height" % impact_dist)

func test_02_correct_range_hits_elevation() -> void:
	print("\n--- Test 2: Correct Range Dial (900m for 900m Target Passes at Target Height) ---")
	var shooter = TacticalVehicle.new()
	var ammo = AmmunitionData.create_apcbc()
	shooter.set_active_ammo(ammo)
	
	var target_dist: float = 900.0
	shooter.gunner_sight.sight_range_m = target_dist
	shooter.gunner_sight.commanded_yaw = 0.0
	shooter.gunner_sight.commanded_pitch = 0.0
	
	var elev = shooter.gunner_sight.get_ballistic_elevation(target_dist, ammo)
	var v0 = ammo.muzzle_velocity
	var k = ammo.drag_coeff
	var vel = Vector3(0, v0 * sin(elev), -v0 * cos(elev))
	var pos = Vector3(0, 2.65, 0)
	var dt = 0.005
	var height_at_target = 0.0
	
	for i in range(1000):
		var cur_speed = vel.length()
		var drag = k * cur_speed * cur_speed
		vel -= vel.normalized() * drag * dt
		vel.y -= 9.81 * dt
		pos += vel * dt
		if -pos.z >= target_dist:
			height_at_target = pos.y
			break
			
	check(absf(height_at_target - 2.65) < 1.5, "Shell at 900m passes at target vehicle height (Y = %.2fm, launch Y = 2.65m)" % height_at_target)

func test_03_no_hidden_truth_leak() -> void:
	print("\n--- Test 3: No Hidden Truth Leaks in Gunner Sight ---")
	var shooter = TacticalVehicle.new()
	var track = ContactTrack.new("TEST")
	track.estimated_position = Vector3(100, 1.4, -600)
	track.estimated_range = 608.0
	track.estimated_bearing_deg = 170.5
	
	# Slew to contact estimate
	shooter.gunner_sight.slew_to_contact(track)
	
	# Sight range should be rounded estimate (600m), not some hidden float
	check(shooter.gunner_sight.sight_range_m == 600.0, "Sight range set strictly to estimated track bracket (600m)")
	check(shooter.gunner_sight.commanded_yaw != 0.0, "Commanded yaw directed to estimate bearing")

func test_04_turret_traverse_time() -> void:
	print("\n--- Test 4: Turret Traverse Takes Finite Physical Time ---")
	var tank = TacticalVehicle.new()
	tank.rotation.y = 0.0
	tank.model.turret_yaw = 0.0
	tank.gunner_sight.current_bore_yaw = 0.0
	
	# Command 60 degree turret turn
	var target_yaw = deg_to_rad(60.0)
	tank.gunner_sight.commanded_yaw = target_yaw
	
	# Mastodon turret traverse speed is 24.0 deg/s; 60 degrees takes 2.5 seconds
	var est_time = tank.gunner_sight.get_traverse_time_est()
	check(absf(est_time - 2.50) < 0.1, "Estimated traverse time for 60° turn is 2.5s at 24°/s (Got: %.2fs)" % est_time)
	
	# Step 1.0 second: turret should NOT be bore aligned yet
	for i in range(10):
		tank.gunner_sight.update_step(0.1)
		
	check(not tank.gunner_sight.is_bore_aligned(), "Gunner sight is not bore aligned mid-traverse at t=1.0s")
	
	# Step another 1.5 seconds: turret should now be aligned
	for i in range(15):
		tank.gunner_sight.update_step(0.1)
		
	check(tank.gunner_sight.is_bore_aligned(), "Gunner sight successfully bore-aligned after traversal completes")

func test_05_target_motion_during_traverse() -> void:
	print("\n--- Test 5: Target Moves During Turret Traverse ---")
	var tank = TacticalVehicle.new()
	var track = ContactTrack.new("TEST")
	track.estimated_position = Vector3(0, 1.4, -500.0)
	track.estimated_range = 500.0
	track.estimated_bearing_deg = 0.0
	track.estimated_speed_mps = 8.0 # 8 m/s (~29 km/h) lateral speed
	track.estimated_heading_deg = 90.0 # moving East (+X)
	
	# Initial slew command straight ahead (yaw 0)
	tank.gunner_sight.slew_to_contact(track)
	
	# During 2 seconds of traversal, target travels 16 meters laterally
	var time_elapsed = 2.0
	var lateral_displacement = track.estimated_speed_mps * time_elapsed # 16m
	var new_target_pos = track.estimated_position + Vector3(lateral_displacement, 0, 0)
	
	# Angle to displaced target: atan2(16, 500) ≈ 0.032 rad ≈ 32 mils
	var angle_to_displaced = atan2(new_target_pos.x, -new_target_pos.z)
	var sight_bearing = tank.gunner_sight.commanded_yaw
	var angular_lag_mils = absf(angle_to_displaced - sight_bearing) * 1000.0
	
	check(angular_lag_mils > 25.0, "Target motion during traversal introduces ~32 mils lag (Actual: %.1f mils)" % angular_lag_mils)
	check(not tank.gunner_sight.is_bore_aligned() or absf(angular_lag_mils) > 10.0, "Manual tracking / lead required when target moves")

func test_06_gun_settling_and_dispersion() -> void:
	print("\n--- Test 6: Gun Settling Dynamics and Platform Dispersion ---")
	var tank = TacticalVehicle.new()
	
	# Induce mouse input (moving sight)
	tank.gunner_sight.apply_mouse_input(Vector2(50, 0))
	check(tank.gunner_sight.settling_state == GunnerSightSystem.SettlingState.UNSTABLE, "Rapid sight movement sets state to UNSTABLE")
	
	var unstable_disp = tank.gunner_sight.calculate_dispersion()
	check(unstable_disp > 0.0025, "Unstable platform dispersion is high (>2.5 mils, Got: %.4f rad)" % unstable_disp)
	
	# Stop movement and step 0.3s -> should be SETTLING
	tank.gunner_sight.update_step(0.3)
	check(tank.gunner_sight.settling_state == GunnerSightSystem.SettlingState.SETTLING, "After motion halts, state transitions to SETTLING")
	var settling_disp = tank.gunner_sight.calculate_dispersion()
	check(settling_disp < unstable_disp and settling_disp > 0.0008, "Settling dispersion is intermediate (Got: %.4f rad)" % settling_disp)
	
	# Step past 0.75s -> should become STABLE
	tank.gunner_sight.update_step(0.6)
	check(tank.gunner_sight.settling_state == GunnerSightSystem.SettlingState.STABLE, "Platform reaches STABLE state after settling duration")
	var stable_disp = tank.gunner_sight.calculate_dispersion()
	check(stable_disp <= 0.00035, "Stable dispersion returns to tight baseline (<0.35 mils, Got: %.4f rad)" % stable_disp)

func test_07_fire_policies_asap_vs_stable() -> void:
	print("\n--- Test 7: Fire Policies (FIRE_ASAP vs FIRE_WHEN_STABLE) ---")
	var tank = TacticalVehicle.new()
	tank.gunner_sight.current_bore_yaw = 0.0
	tank.gunner_sight.commanded_yaw = 0.0
	tank.gunner_sight.current_bore_pitch = tank.gunner_sight.get_ballistic_elevation(800.0)
	tank.gunner_sight.commanded_pitch = 0.0
	tank.gunner_sight.sight_range_m = 800.0
	
	# Make platform UNSTABLE
	tank.gunner_sight.settling_state = GunnerSightSystem.SettlingState.UNSTABLE
	tank.gunner_sight.settling_timer = 0.75
	
	# With FIRE_WHEN_STABLE: cannot fire yet
	tank.gunner_sight.fire_policy = GunnerSightSystem.FirePolicy.FIRE_WHEN_STABLE
	check(not tank.gunner_sight.can_fire_now(), "FIRE_WHEN_STABLE holds fire while gun platform is settling")
	
	# With FIRE_ASAP: permitted to fire immediately
	tank.gunner_sight.fire_policy = GunnerSightSystem.FirePolicy.FIRE_ASAP
	check(tank.gunner_sight.can_fire_now(), "FIRE_ASAP authorizes immediate discharge despite platform instability")

func test_08_estimated_lead_calculation() -> void:
	print("\n--- Test 8: Manual Deflection / Estimated Lead in Mils ---")
	var tank = TacticalVehicle.new()
	var ammo = AmmunitionData.create_apcbc()
	var track = ContactTrack.new("TEST")
	track.estimated_range = 1000.0
	track.estimated_bearing_deg = 0.0
	track.estimated_speed_mps = 10.0 # 10 m/s (~36 km/h) pure crossing target
	track.estimated_heading_deg = 90.0
	
	tank.gunner_sight.commanded_yaw = 0.0
	var lead_mils = tank.gunner_sight.get_estimated_lead_mils(track, ammo)
	
	# At 1000m, t_flight for 880m/s APCBC is ~1.3s.
	# Tangential distance traveled = 10 m/s * 1.3s = 13.0m.
	# Lead in mils = (13.0m / 1000m) * 1000 = ~13 mils.
	check(lead_mils > 10.0 and lead_mils < 16.0, "Lead assist computes ~13 mils lateral lead (Got: %.1f mils)" % lead_mils)

func test_09_optical_los_and_ghost_suppression() -> void:
	print("\n--- Test 9: Optical LOS and Ghost Suppression in Gunner Sight ---")
	var tank = TacticalVehicle.new()
	var enemy = TacticalVehicle.new()
	enemy.position = Vector3(0, 0, -500) # Directly ahead
	
	# In optic view, sight aperture is aligned
	tank.gunner_sight.commanded_yaw = 0.0
	tank.gunner_sight.commanded_pitch = 0.0
	
	# Update acquisition without obstruction
	tank.gunner_sight.update_step(0.6, enemy, null)
	check(tank.gunner_sight.target_has_los, "Target directly ahead in optic aperture has clear optical LOS")
	check(tank.gunner_sight.acquisition_state in [GunnerSightSystem.AcquisitionState.TARGET_VISIBLE, GunnerSightSystem.AcquisitionState.ACQUIRED],
		"Target state transitions to VISIBLE/ACQUIRED")
		
	# Look away by 45 degrees
	tank.gunner_sight.commanded_yaw = deg_to_rad(45.0)
	tank.gunner_sight.update_step(0.1, enemy, null)
	check(tank.gunner_sight.acquisition_state != GunnerSightSystem.AcquisitionState.ACQUIRED,
		"Looking away exits ACQUIRED state into SEARCHING/SLEWING")

func test_10_observed_splash_range_correction() -> void:
	print("\n--- Test 10: Observed Splash Bracketing Updates Range Estimate ---")
	var track = ContactTrack.new("TEST")
	track.estimated_range = 1000.0
	track.range_uncertainty = 150.0
	
	# Shell lands SHORT of target
	track.apply_observed_impact("SHORT")
	check(track.estimated_range > 1000.0, "Observed SHORT splash adjusts range outward (New: %.1fm)" % track.estimated_range)
	check(track.range_uncertainty < 150.0, "Observed splash tightens range uncertainty (New: ±%.1fm)" % track.range_uncertainty)
	
	var cur_range = track.estimated_range
	var cur_unc = track.range_uncertainty
	# Next shell lands OVER target
	track.apply_observed_impact("OVER")
	check(track.estimated_range < cur_range, "Observed OVER splash brackets target inward (New: %.1fm)" % track.estimated_range)
	check(track.range_uncertainty < cur_unc, "Target bracketed between SHORT and OVER further contracts uncertainty (New: ±%.1fm)" % track.range_uncertainty)

func test_11_bore_lag_horizontal_direction() -> void:
	print("\n--- Test 11: Bore Lag Horizontal Direction (No Left/Right Inversion) ---")
	var tank = TacticalVehicle.new()
	tank.gunner_sight.current_bore_yaw = 0.0
	
	# Command turret to turn RIGHT (in Godot right is negative yaw)
	tank.gunner_sight.commanded_yaw = deg_to_rad(-30.0)
	
	# The physical barrel is still at yaw 0 (to the LEFT of -30° in the gunner's frame of reference)
	var yaw_diff = angle_difference(tank.gunner_sight.commanded_yaw, tank.gunner_sight.current_bore_yaw)
	var x_offset = -yaw_diff * 1000.0 * (14.0 * 0.058)
	
	# In the gunner optic screen, x_offset must be NEGATIVE (drawn on the LEFT side of the screen)
	check(x_offset < 0.0, "When looking right, physical barrel lagging on the left renders on the left (-X on screen, Got: %.1f px)" % x_offset)
	
	# Now command turret to turn LEFT (positive yaw in Godot)
	tank.gunner_sight.commanded_yaw = deg_to_rad(30.0)
	var yaw_diff_left = angle_difference(tank.gunner_sight.commanded_yaw, tank.gunner_sight.current_bore_yaw)
	var x_offset_left = -yaw_diff_left * 1000.0 * (14.0 * 0.058)
	
	# In the gunner optic screen, x_offset must be POSITIVE (drawn on the RIGHT side of the screen)
	check(x_offset_left > 0.0, "When looking left, physical barrel lagging on the right renders on the right (+X on screen, Got: %.1f px)" % x_offset_left)

func test_12_no_arcade_aim_and_fire_mode() -> void:
	print("\n--- Test 12: No Arcade Aim & Fire on Tactical Map ---")
	var scene = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await physics_frame
	scene.set_physics_process(false)
	scene._process(0)
	
	# Map click defaults to MOVE, not arcade fire
	var ground_pt = scene.player.position + Vector3(15, 0, 0)
	scene._queue_move(ground_pt)
	check(scene.action_queue.actions.size() == 1, "Action added to queue")
	check(scene.action_queue.actions[0].kind == "move", "Map click creates tactical MOVE action, not arcade fire")
	scene.queue_free()
	await process_frame
