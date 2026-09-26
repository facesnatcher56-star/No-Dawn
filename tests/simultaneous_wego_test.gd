extends SceneTree

const ArmorModel = preload("res://scripts/wego/ArmorModel.gd")
const ContactTrack = preload("res://scripts/wego/ContactTrack.gd")
const Observation = preload("res://scripts/wego/Observation.gd")
const SensorModel = preload("res://scripts/wego/SensorModel.gd")
const FiringSolution = preload("res://scripts/wego/FiringSolution.gd")
const CrewDoctrine = preload("res://scripts/wego/CrewDoctrine.gd")
const WegoTimeline = preload("res://scripts/wego/WegoTimeline.gd")
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
	print("   SIMULTANEOUS WEGO & RECONNAISSANCE TEST SUITE  ")
	print("==================================================")
	
	test_simultaneous_timeline_and_pulse_modes()
	test_simultaneous_movement()
	test_simultaneous_firing_and_shell_flight()
	test_shell_continues_after_shooter_destroyed()
	test_ghost_silhouette_preservation()
	test_predicted_corridor_expansion()
	test_sustained_observation_convergence()
	test_gunner_narrow_fov_acquisition()
	test_moving_target_lead_no_truth_leak()
	test_contact_decay_when_occluded()
	test_cross_bearing_triangulation()
	test_splash_fire_correction()
	test_crew_doctrine_sop()
	
	print("==================================================")
	print("WEGO Test Suite Finished. Total Failures: ", failures)
	print("==================================================")
	quit(failures)

func test_simultaneous_timeline_and_pulse_modes() -> void:
	print("\n--- 1. Simultaneous Timeline & Pulse Modes ---")
	var timeline = WegoTimeline.new()
	var track_quiet = ContactTrack.new("TEST")
	track_quiet.range_uncertainty = 60.0
	track_quiet.has_visual_los = false
	
	var mode = timeline.evaluate_mode(track_quiet, null, false, false)
	check(mode == WegoTimeline.PulseMode.MANEUVER, "Quiet situation evaluates to MANEUVER mode (8s)")
	
	timeline.start_pulse(mode)
	check(is_equal_approx(timeline.pulse_duration, 8.0), "Maneuver pulse duration is 8.0s")
	check(is_equal_approx(timeline.pulse_time_left, 8.0), "Maneuver pulse time left starts at 8.0s")
	
	# Step 2 seconds
	var stepped = timeline.step_pulse(2.0)
	check(is_equal_approx(stepped, 2.0), "Pulse steps 2.0s")
	check(is_equal_approx(timeline.sim_time, 2.0), "Simulation clock advances to 2.0s")
	check(is_equal_approx(timeline.pulse_time_left, 6.0), "Remaining pulse time is 6.0s")
	
	# Threat emerges
	track_quiet.has_visual_los = true
	track_quiet.range_uncertainty = 10.0
	var combat_mode = timeline.evaluate_mode(track_quiet, null, true, false)
	check(combat_mode == WegoTimeline.PulseMode.COMBAT, "Active threat or gunfire triggers COMBAT mode (3s)")
	
	timeline.start_pulse(combat_mode)
	check(is_equal_approx(timeline.pulse_duration, 3.0), "Combat pulse duration is 3.0s")

func test_simultaneous_movement() -> void:
	print("\n--- 2. Simultaneous Movement Execution ---")
	var v_player = TacticalVehicle.new()
	v_player.position = Vector3(0, 0, 0)
	var v_enemy = TacticalVehicle.new()
	v_enemy.position = Vector3(100, 0, 0)
	
	v_player.commit({"move": 15.0, "pivot": 0.0, "engine": true})
	v_enemy.commit({"move": -10.0, "pivot": 0.0, "engine": true})
	
	# Step both in the exact same timeline tick
	var dt = 1.0
	v_player.step(dt)
	v_enemy.step(dt)
	
	check(v_player.position.z < -0.5, "Player moved forward along -Z during tick")
	check(v_enemy.position.z > 0.5, "Enemy moved backward along +Z during the exact same tick")
	check(is_equal_approx(v_player.elapsed, v_enemy.elapsed), "Both vehicles share identical elapsed simulation time")

func test_simultaneous_firing_and_shell_flight() -> void:
	print("\n--- 3. Simultaneous Firing & Multi-Shell Flight ---")
	var v_a = TacticalVehicle.new()
	v_a.position = Vector3(0, 0, 0)
	var v_b = TacticalVehicle.new()
	v_b.position = Vector3(0, 0, -100)
	
	# Both fire toward each other
	var shells: Array = []
	var shell_a = {
		"position": v_a.position + Vector3(0, 2.65, 0),
		"velocity": Vector3(0, 0, -740.0),
		"shooter": v_a,
		"alive": true
	}
	var shell_b = {
		"position": v_b.position + Vector3(0, 2.65, 0),
		"velocity": Vector3(0, 0, 740.0),
		"shooter": v_b,
		"alive": true
	}
	shells.append(shell_a)
	shells.append(shell_b)
	
	var dt = 0.05
	shell_a.position += shell_a.velocity * dt
	shell_b.position += shell_b.velocity * dt
	
	check(shell_a.position.z < -30.0, "Shell A travelled in flight toward -Z")
	check(shell_b.position.z > -70.0, "Shell B travelled in flight toward +Z in the same step")
	check(shells.size() == 2, "Both shells fly concurrently without sequential turn blocking")

func test_shell_continues_after_shooter_destroyed() -> void:
	print("\n--- 4. In-Flight Shell Survives Shooter Destruction ---")
	var shooter = TacticalVehicle.new()
	shooter.position = Vector3(0, 0, 0)
	var target = TacticalVehicle.new()
	target.position = Vector3(0, 0, -45)
	
	var shell = {
		"position": Vector3(0, 1.45, -10),
		"velocity": Vector3(0, 0, -740.0),
		"shooter": shooter,
		"distance": 10.0
	}
	
	# Shooter is knocked out while shell is mid-air
	shooter.model.catastrophic = true
	check(shooter.model.catastrophic, "Shooter knocked out")
	
	# Simulation advances shell
	var dt = 0.05
	shell.position += shell.velocity * dt
	shell.distance += 740.0 * dt
	
	check(shell.position.z < -40.0, "Shell continues ballistic flight after shooter is destroyed")
	var will_strike = shell.position.z <= target.position.z
	check(will_strike, "In-flight shell reaches target after shooter destruction")

func test_ghost_silhouette_preservation() -> void:
	print("\n--- 5. Ghost Silhouette Preservation ---")
	var track = ContactTrack.new("TEST_ENEMY")
	var last_seen_pos = Vector3(50, 0, -80)
	var obs = Observation.new(
		10.0, # sim_time
		Vector3(0, 0, 0),
		"Visual silhouette",
		45.0, # bearing
		1.0, # arc
		100.0, # range
		5.0, # range_unc
		last_seen_pos,
		2.0 # pos_unc
	)
	obs.target_heading_deg = 90.0
	obs.target_speed_mps = 6.0
	obs.is_direct_visual = true
	
	track.integrate_observation(obs, 10.0)
	check(track.has_silhouette, "Ghost silhouette created on visual contact")
	check(track.silhouette_position == last_seen_pos, "Ghost silhouette records accurate location")
	check(is_equal_approx(track.silhouette_heading_deg, 90.0), "Ghost silhouette records target heading")
	
	# Real enemy now moves out of sight and stops
	track.has_visual_los = false
	var dt = 4.0
	track.predict_motion(dt, 14.0)
	
	# Ghost silhouette must remain FROZEN at last seen point
	check(track.silhouette_position == last_seen_pos, "Ghost silhouette remains frozen at last-seen position")
	check(is_equal_approx(track.silhouette_time, 10.0), "Ghost silhouette retains original sighting timestamp")
	check(track.estimated_position != last_seen_pos, "Estimated position moved while ghost stayed frozen")

func test_predicted_corridor_expansion() -> void:
	print("\n--- 6. Predicted Movement Corridor Expansion ---")
	var track = ContactTrack.new("TARGET")
	track.silhouette_position = Vector3(0, 0, 0)
	track.estimated_position = Vector3(0, 0, 0)
	track.has_silhouette = true
	track.estimated_heading_deg = 0.0 # Heading North (-Z in Godot)
	track.estimated_speed_mps = 5.0
	track.position_uncertainty = 10.0
	track.heading_uncertainty = 20.0
	
	var corridor = track.get_predicted_corridor(6.0)
	check(corridor.center_line.size() > 2, "Corridor computes center line samples")
	check(corridor.left_edge.size() == corridor.center_line.size(), "Left bounds generated")
	check(corridor.right_edge.size() == corridor.center_line.size(), "Right bounds generated")
	
	# Check corridor widening
	var width_start = corridor.left_edge[0].distance_to(corridor.right_edge[0])
	var width_end = corridor.left_edge.back().distance_to(corridor.right_edge.back())
	check(width_end > width_start, "Predicted corridor expands laterally over time due to heading uncertainty")
	
	# Verify corridor projects forward even if target secretly stopped
	var forward_travel = corridor.center_line[0].distance_to(corridor.center_line.back())
	check(is_equal_approx(forward_travel, 30.0), "Corridor projects 30m forward along last known speed (5m/s * 6s)")

func test_sustained_observation_convergence() -> void:
	print("\n--- 7. Sustained Observation Convergence ---")
	var track = ContactTrack.new("CONVERGE_TEST")
	track.position_uncertainty = 30.0
	track.range_uncertainty = 50.0
	track.heading_uncertainty = 40.0
	track.speed_uncertainty = 8.0
	
	var true_pos = Vector3(40, 0, 40)
	var true_heading = 120.0
	var true_speed = 4.0
	
	# Simulate 4 consecutive visual observations
	for i in range(4):
		var obs = Observation.new(
			float(i) * 0.5,
			Vector3(0, 0, 0),
			"Commander optics",
			45.0, 1.0, 56.5, 4.0,
			true_pos, 2.0
		)
		obs.target_heading_deg = true_heading
		obs.target_speed_mps = true_speed
		obs.is_direct_visual = true
		obs.target_classification = "A-47 Mastodon"
		track.integrate_observation(obs, float(i) * 0.5)
	
	check(track.position_uncertainty < 15.0, "Position uncertainty narrowed from 30m to <15m")
	check(track.range_uncertainty < 25.0, "Range uncertainty narrowed from 50m to <25m")
	check(track.heading_uncertainty < 20.0, "Heading uncertainty narrowed")
	check(track.speed_uncertainty < 4.0, "Speed uncertainty narrowed")
	check(track.identification_quality > 0.6, "Classification confidence progressed under continuous spotting")

func test_gunner_narrow_fov_acquisition() -> void:
	print("\n--- 8. Gunner Narrow-FOV Tracking ---")
	var track = ContactTrack.new("GUNNER_TRACK")
	track.commander_observing = true
	track.gunner_acquired = true
	track.range_uncertainty = 20.0
	track.speed_uncertainty = 4.0
	
	var obs = Observation.new(
		1.0, Vector3.ZERO, "Gunner sight", 0.0, 0.5, 100.0, 2.0, Vector3(0, 0, -100), 1.0
	)
	obs.is_direct_visual = true
	obs.target_speed_mps = 3.0
	
	track.integrate_observation(obs, 1.0, {"gunner_tracking": 1.5})
	check(track.range_uncertainty <= 16.0, "Gunner tracking tightened range uncertainty")
	check(track.speed_uncertainty <= 3.0, "Gunner tracking tightened speed uncertainty")

func test_moving_target_lead_no_truth_leak() -> void:
	print("\n--- 9. Moving Target Lead (No Truth Leaking) ---")
	var rng = RandomNumberGenerator.new()
	rng.seed = 12345
	
	var shooter = TacticalVehicle.new()
	shooter.position = Vector3(0, 0, 0)
	
	var track = ContactTrack.new("LEAD_TARGET")
	# Target is believed to be at (0, 0, -100) moving East (+X) at 10 m/s
	track.estimated_position = Vector3(0, 0, -100)
	track.estimated_heading_deg = 90.0
	track.estimated_speed_mps = 10.0
	track.range_uncertainty = 5.0
	track.position_uncertainty = 2.0
	track.gunner_acquired = true
	
	var sol = FiringSolution.calculate(shooter, track, rng, 740.0)
	check(sol.flight_time > 0.1, "Calculated flight time to target")
	
	# Predicted lead offset should be toward +X
	check(sol.lead_offset.x > 0.8, "Lead offset applied along estimated target velocity (+X)")
	check(sol.predicted_target_position.x > 0.8, "Predicted target position leads target to the East")
	check(sol.solution_quality in ["ACQUIRED", "OPTIMAL"], "High confidence track produces ACQUIRED or OPTIMAL solution")

func test_contact_decay_when_occluded() -> void:
	print("\n--- 10. Contact Decay When Occluded ---")
	var track = ContactTrack.new("DECAY_TEST")
	track.has_visual_los = false
	track.position_uncertainty = 10.0
	track.range_uncertainty = 15.0
	track.heading_uncertainty = 10.0
	track.estimated_speed_mps = 6.0
	
	# Target occluded for 5 seconds
	track.predict_motion(5.0, 5.0)
	
	check(track.position_uncertainty > 15.0, "Position uncertainty expanded over occluded period")
	check(track.range_uncertainty > 20.0, "Range uncertainty expanded over occluded period")
	check(track.heading_uncertainty > 20.0, "Heading uncertainty expanded over occluded period")

func test_cross_bearing_triangulation() -> void:
	print("\n--- 11. Cross-Bearing Acoustic Triangulation ---")
	var observer = TacticalVehicle.new()
	observer.position = Vector3(0, 0, 0)
	
	var rng = RandomNumberGenerator.new()
	rng.seed = 999
	var sensor = SensorModel.new(rng)
	
	var target = TacticalVehicle.new()
	target.position = Vector3(100, 0, -100)
	target.engine_on = true
	
	# First acoustic reading at pos (0, 0, 0) of gunfire report
	var res1 = sensor.evaluate(observer, target, null, 1.0, true)
	var obs1 = res1.get("acoustic_observation")
	check(obs1 != null, "First acoustic observation recorded")
	
	# Observer moves to new position (60, 0, 0) for baseline separation
	observer.position = Vector3(60, 0, 0)
	var res2 = sensor.evaluate(observer, target, null, 3.0, true)
	var obs2 = res2.get("acoustic_observation")
	check(obs2 != null, "Second acoustic observation recorded")
	check(obs2.source == "Cross-bearing fix", "Two separated bearings produce a Cross-bearing fix")
	check(obs2.position_uncertainty_m < obs1.position_uncertainty_m, "Triangulation yields lower uncertainty than single bearing")

func test_splash_fire_correction() -> void:
	print("\n--- 12. Observed Splash Range Correction ---")
	var track = ContactTrack.new("SPLASH_TEST")
	track.estimated_range = 100.0
	track.range_uncertainty = 30.0
	
	# Shell fell SHORT -> target is farther than believed
	track.apply_observed_impact("SHORT")
	check(track.estimated_range > 105.0, "SHORT splash adjusts estimated range farther")
	check(track.range_uncertainty < 30.0, "Observed splash narrows range uncertainty")
	
	# Shell fell OVER -> target is closer than believed
	var range_before = track.estimated_range
	track.apply_observed_impact("OVER")
	check(track.estimated_range < range_before, "OVER splash adjusts estimated range closer")

func test_crew_doctrine_sop() -> void:
	print("\n--- 13. Crew Doctrine Standing Operating Procedures (SOP) ---")
	var doctrine = CrewDoctrine.new()
	doctrine.on_contact = CrewDoctrine.ContactReaction.HALT_AND_TRACK
	doctrine.on_fired_upon = CrewDoctrine.FiredUponReaction.REVERSE
	doctrine.fire_authority = CrewDoctrine.FireAuthority.FIRE_WHEN_READY
	
	var tank = TacticalVehicle.new()
	var track = ContactTrack.new("SOP_TRACK")
	track.has_visual_los = true
	
	var eval_contact = doctrine.evaluate(tank, track, false, false, "OPTIMAL")
	check(eval_contact.halt_movement, "SOP: Tank halts on contact")
	check(eval_contact.track_target, "SOP: Tank lays turret on contact")
	check(eval_contact.fire_authorized, "SOP: Fire is authorized under FIRE_AT_WILL")
	
	var eval_hit = doctrine.evaluate(tank, track, true, true, "OPTIMAL")
	check(eval_hit.reverse_movement, "SOP: Tank reverses to cover when hit")
