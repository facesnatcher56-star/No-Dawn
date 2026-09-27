extends SceneTree

const IndustrialMapBuilder = preload("res://scripts/environment/IndustrialMapBuilder.gd")
const EngagementScript = preload("res://scripts/wego/Engagement.gd")
const GunnerSightSystem = preload("res://scripts/wego/GunnerSightSystem.gd")

func _init() -> void:
	print("\n==================================================")
	print("  GUNNER SIGHT LANDMARK & 3D VIEWPORT VALIDATION  ")
	print("==================================================\n")
	
	var pass_count = 0
	var fail_count = 0
	
	# Test 1: Instantiate Engagement Scene
	var engagement = load("res://scenes/Main.tscn").instantiate()
	root.add_child(engagement)
	
	# Allow ready and setup
	await process_frame
	await process_frame
	
	print("--- Test 1: Physical Optic Mount and Alignment ---")
	if engagement.player != null and engagement.player.gunner_sight != null:
		var sight: GunnerSightSystem = engagement.player.gunner_sight
		if sight.sight_camera != null and is_instance_valid(sight.sight_camera):
			print("  ✅ PASS: Gunner sight camera is valid and instantiated")
			pass_count += 1
		else:
			print("  ❌ FAIL: Gunner sight camera is missing")
			fail_count += 1
			
		var optic_marker = engagement.player.get_gunner_optic_marker()
		if optic_marker != null:
			print("  ✅ PASS: Optic marker MKR_GunnerOptic found on tank at %s" % optic_marker.global_position)
			pass_count += 1
		else:
			print("  ❌ FAIL: MKR_GunnerOptic marker missing from tank")
			fail_count += 1
			
		# Check near / far clipping planes
		if sight.sight_camera.near <= 0.2 and sight.sight_camera.far >= 3000.0:
			print("  ✅ PASS: Camera clipping planes properly configured (near: %.1fm, far: %.1fm)" % [sight.sight_camera.near, sight.sight_camera.far])
			pass_count += 1
		else:
			print("  ❌ FAIL: Clipping planes misconfigured: near=%.1f, far=%.1f" % [sight.sight_camera.near, sight.sight_camera.far])
			fail_count += 1
	else:
		print("  ❌ FAIL: Player or gunner_sight is null")
		fail_count += 1

	print("\n--- Test 2: Calibration Landmark Presence in 3D World ---")
	var landmark = engagement.get_node_or_null("MapBuilder/LANDMARK_TargetPanel")
	if landmark != null and is_instance_valid(landmark):
		print("  ✅ PASS: LANDMARK_TargetPanel present in map at position %s" % landmark.global_position)
		pass_count += 1
	else:
		print("  ❌ FAIL: LANDMARK_TargetPanel missing from MapBuilder")
		fail_count += 1

	print("\n--- Test 3: Landmark Visibility and Projection Through Gunner Sight ---")
	engagement._enter_gunner_view()
	var sight_cam: Camera3D = engagement.player.gunner_sight.sight_camera
	if sight_cam != null and sight_cam.current:
		print("  ✅ PASS: Sight camera is active camera when in Gunner View")
		pass_count += 1
	else:
		print("  ❌ FAIL: Sight camera is not active camera")
		fail_count += 1

	if landmark != null and sight_cam != null:
		var lm_pos = landmark.global_position
		var is_behind = sight_cam.is_position_behind(lm_pos)
		if not is_behind:
			var scr_pos = sight_cam.unproject_position(lm_pos)
			print("  ✅ PASS: Landmark is directly in front of optic aperture (Projected screen pos: %s)" % scr_pos)
			pass_count += 1
		else:
			print("  ❌ FAIL: Landmark is behind the sight camera (Orientation inverted!)")
			fail_count += 1

	print("\n--- Test 4: Landmark Shifts Consistently When Turret Traverses ---")
	if landmark != null and sight_cam != null:
		var initial_scr = sight_cam.unproject_position(landmark.global_position)
		# Traverse visual tank turret by +5 degrees
		if engagement.player.visual_tank != null:
			engagement.player.visual_tank.rotate_turret(deg_to_rad(5.0))
		engagement.player.model.turret_yaw += deg_to_rad(5.0)
		engagement.player.gunner_sight._update_camera_transform()
		await process_frame
		var traversed_scr = sight_cam.unproject_position(landmark.global_position)
		
		var delta_x = traversed_scr.x - initial_scr.x
		# In Godot, positive Y rotation rotates counter-clockwise (left toward North).
		# When camera turns left, world landmark shifts RIGHT on screen (+X).
		if delta_x > 20.0:
			print("  ✅ PASS: Turning turret left (+5°) shifts landmark to the right (Delta X: %.1f px)" % delta_x)
			pass_count += 1
		else:
			print("  ❌ FAIL: Landmark did not shift right as expected (Delta X: %.1f px)" % delta_x)
			fail_count += 1

	print("\n--- Test 5: UI Elements Hidden During Gunner Sight (Clear Field of View) ---")
	if engagement.tactical_ui != null and not engagement.tactical_ui.visible:
		print("  ✅ PASS: Tactical UI root container is hidden in gunner view")
		pass_count += 1
	else:
		print("  ❌ FAIL: Tactical UI remained visible during gunner view")
		fail_count += 1

	if engagement.battlefield_overlay != null and not engagement.battlefield_overlay.visible:
		print("  ✅ PASS: Battlefield 2D tactical overlay is hidden in gunner view")
		pass_count += 1
	else:
		print("  ❌ FAIL: Battlefield overlay remained visible in gunner view")
		fail_count += 1

	engagement._exit_gunner_view()
	if engagement.tactical_ui != null and engagement.tactical_ui.visible:
		print("  ✅ PASS: Tactical UI reappears upon exiting gunner view")
		pass_count += 1
	else:
		print("  ❌ FAIL: Tactical UI failed to reappear upon exiting gunner view")
		fail_count += 1

	print("\n==================================================")
	print("Landmark & 3D Sight validation completed. Failures: %d" % fail_count)
	print("==================================================\n")
	
	engagement.queue_free()
	quit(0 if fail_count == 0 else 1)
