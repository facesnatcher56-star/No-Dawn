extends SceneTree

var failures: int = 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FAILED: " + message)
	else:
		print("  ✅ PASS: " + message)

func _init() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	call_deferred("run_tutorial_tests")

func run_tutorial_tests() -> void:
	print("\n==================================================")
	print("       INTERACTIVE TUTORIAL TEST SUITE            ")
	print("==================================================")
	
	var main_scene = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	await process_frame
	
	main_scene._update_camera(0.0)
	main_scene._process(0.016)
	
	print("\n--- Test 1: Tutorial Initialization & Launch State ---")
	var tut = main_scene.tutorial
	check(tut != null, "Tutorial instance is valid and attached to Engagement")
	check(tut.is_active, "Tutorial starts active automatically on launch")
	check(tut.current_step == 0, "Tutorial starts at Step 0 (Step 1 of 8)")
	check(tut.main_panel.visible, "Tutorial card panel is visible")
	check(not tut.reopen_button.visible, "Reopen button is hidden while tutorial is active")
	check(tut.step_title_label.text.contains("CAMERA"), "Step 1 title describes Camera & View")
	check(tut.prev_button.visible == false, "PREV button is hidden on first step")
	check(tut.next_button.visible == true, "NEXT button is visible on first step")

	print("\n--- Test 2: Step 0 Objective & Advancing to Step 1 ---")
	# Simulate camera orbit change
	main_scene.cam_yaw += 0.3
	tut._process(0.016)
	check(tut.objective_achieved, "Camera rotation satisfies Step 0 objective")
	check(tut.objective_icon_label.text.contains("✔"), "Checkmark icon appears upon completion")
	
	tut._on_next_pressed()
	check(tut.current_step == 1, "Advanced to Step 1 (Movement Planning)")
	check(tut.step_title_label.text.contains("MOVEMENT"), "Step 2 title describes Movement Waypoint")
	check(tut.prev_button.visible == true, "PREV button is now visible")

	print("\n--- Test 3: Step 1 Movement Waypoint Objective ---")
	check(not tut.objective_achieved, "Step 1 objective starts incomplete")
	var test_move_pt = main_scene.player.position + Vector3(25, 0, 0)
	main_scene._queue_move(test_move_pt)
	tut._process(0.016)
	check(tut.objective_achieved, "Queueing move waypoint completes Step 1 objective")
	
	tut._on_next_pressed()
	check(tut.current_step == 2, "Advanced to Step 2 (Observation Sector)")
	check(tut.step_title_label.text.contains("OBSERVATION"), "Step 3 title describes Observation Sector")

	print("\n--- Test 4: Step 2 Observation Sector Objective ---")
	check(not tut.objective_achieved, "Step 2 objective starts incomplete")
	main_scene._start_observe_sector_mode()
	tut._process(0.016)
	check(tut.objective_achieved, "Entering observe mode completes Step 2 objective")
	
	tut._on_next_pressed()
	check(tut.current_step == 3, "Advanced to Step 3 (Simultaneous WEGO Pulse)")
	check(tut.step_title_label.text.contains("PULSE"), "Step 4 title describes Pulse Execution")

	print("\n--- Test 5: Step 3 Execute Pulse Objective ---")
	check(not tut.objective_achieved, "Step 3 objective starts incomplete")
	main_scene._execute()
	tut._process(0.016)
	check(tut.objective_achieved, "Executing pulse completes Step 3 objective")
	
	tut._on_next_pressed()
	check(tut.current_step == 4, "Advanced to Step 4 (Contact Acquired)")
	check(tut.step_title_label.text.contains("CONTACT"), "Step 5 title describes Contact Acquisition")

	print("\n--- Test 6: Step 5 Gunner Sight Objective ---")
	tut._on_next_pressed()
	check(tut.current_step == 5, "Advanced to Step 5 (Entering Gunner Sight)")
	check(tut.step_title_label.text.contains("GUNNER SIGHT"), "Step 6 title describes Gunner Sight")
	check(not tut.objective_achieved, "Step 5 objective starts incomplete")
	
	main_scene._enter_gunner_view()
	tut._process(0.016)
	check(tut.objective_achieved, "Entering gunner view completes Step 5 objective")

	print("\n--- Test 7: Step 6 Range Drum & Reticle Objective ---")
	tut._on_next_pressed()
	check(tut.current_step == 6, "Advanced to Step 6 (Range Drum & Laying)")
	check(tut.step_title_label.text.contains("RANGE DRUM"), "Step 7 title describes Range Drum")
	
	main_scene.player.gunner_sight.sight_range_m = 1500.0
	tut._process(0.016)
	check(tut.objective_achieved, "Dialing range drum to 1500m completes Step 6 objective")

	print("\n--- Test 8: Step 7 Ballistic Engagement & Completion ---")
	tut._on_next_pressed()
	check(tut.current_step == 7, "Advanced to Step 7 (Fire Order)")
	check(tut.next_button.text.contains("FINISH"), "Last step button shows FINISH TUTORIAL")
	
	tut._on_next_pressed()
	check(not tut.is_active, "Tutorial finishes and deactivates")
	check(tut.main_panel.visible == false, "Tutorial card hidden after finish")
	check(tut.reopen_button.visible == true, "Reopen button appears after finishing")

	print("\n--- Test 9: Reopen / Minimize Functionality ---")
	tut._on_reopen_pressed()
	check(tut.is_active, "Reopen button reactivates tutorial")
	check(tut.main_panel.visible == true, "Tutorial card visible again")
	check(tut.reopen_button.visible == false, "Reopen button hidden while active")
	
	tut._on_skip_pressed()
	check(not tut.is_active, "Skip button deactivates tutorial")
	check(tut.reopen_button.visible == true, "Reopen button available after skipping")

	print("\n==================================================")
	print("Tutorial Test Suite Completed! Failures: ", failures)
	print("==================================================")
	
	main_scene.queue_free()
	quit(failures)
