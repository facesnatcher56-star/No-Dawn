extends SceneTree
const Harness = preload("res://tests/PlaybackHarness.gd")

var game
var failures = 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FAILED: " + message)
	else:
		print("  ✅ PASS: " + message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	print("==================================================")
	print("   CONTACT DETECTION & STARTING STATE TEST SUITE  ")
	print("==================================================")
	
	game = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await physics_frame
	game.set_physics_process(false)
	game._process(0.0)
	
	print("\n--- 1. Spawn Starting State (Zero Contacts) ---")
	check(game.display_contact.is_empty(), "Zero initial contacts in display_contact on spawn")
	check(not game.player_track.has_contact(), "player_track has no observations or contact on spawn")
	check(not game.enemy.visible, "Enemy 3D model is invisible at spawn")
	check(not game.ghost_tank.visible, "Ghost tank is invisible at spawn")
	check(game.contact_visual_radius == 0.0, "contact_visual_radius is 0.0 (no uncertainty geometry)")
	check(game.contact_label.text.contains("NO CONTACTS"), "Intelligence UI explicitly states NO CONTACTS")
	check(game.contact_fire_button.disabled, "FIRE AT ESTIMATE is disabled when no contact exists")
	check(not game.scan_button.disabled, "SCAN FOR ENEMY is enabled on spawn")
	
	print("\n--- 2. Idle State Over Time (No Phantom Creation) ---")
	# Simulate 30 seconds of quiet idling with engine quiet/observe
	for i in range(180):
		game._process(1.0 / 60.0)
	check(game.display_contact.is_empty(), "Contact remains empty while idling with no scans or gunfire")
	check(not game.player_track.has_contact(), "No phantom contact created during idle period")
	check(game.contact_visual_radius == 0.0, "Uncertainty visual radius remains 0.0")
	
	print("\n--- 3. Active Scan For Enemy ---")
	game.scan_button.pressed.emit()
	check(game.fields.light.button_pressed, "Scan order activated searchlight")
	check(game.fields.observe.button_pressed, "Scan order activated crew observation")
	check(not game.fields.engine.button_pressed, "Scan order idled engine for quiet listening")
	
	print("\n--- 4. Simultaneous Execution of Scan ---")
	game._execute()
	check(game.phase == "EXECUTION", "Execution began for scan pulse")
	game._physics_process(0.1)
	check(game.player.lamp.visible, "Searchlight is physically illuminated in 3D world")
	
	# Finish the scan turn
	check(await Harness.finish_turn(game), "Scan pulse execution completed")
	check(game.phase == "ASSESSMENT", "Engagement reached assessment after scan")
	
	print("\n--- 5. Post-Scan Detection Verification ---")
	check(game.player_track.has_contact(), "Enemy contact successfully detected by searchlight scan")
	check(not game.display_contact.is_empty(), "display_contact is now populated with detected enemy")
	check(game.display_contact.get("id", "") == "CONTACT_A", "Contact A registered in intelligence system")
	check(game.contact_visual_radius > 0.0 and game.contact_visual_radius <= 6.0, "Visual contact radius is tightly clamped (<= 6.0m, never 35m)")
	check(not game.contact_fire_button.disabled, "FIRE AT ESTIMATE is now enabled with acquired target")
	
	print("==================================================")
	print("Contact Detection checks completed; failures: ", failures)
	print("==================================================")
	quit(failures)
