extends SceneTree

const GunnerSightSystem = preload("res://scripts/wego/GunnerSightSystem.gd")
const ARTIFACT_DIR = "C:/Users/lloyd/.gemini/antigravity/brain/ed4dbe74-3d16-4895-99c7-be6ff9a3c63c"

var game

func _init() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	call_deferred("run_capture")

func capture_frame(filename: String) -> void:
	game._process(0.016)
	await process_frame
	await RenderingServer.frame_post_draw
	var img = root.get_texture().get_image()
	if img != null:
		var target_path = ARTIFACT_DIR + "/" + filename + ".png"
		img.save_png(target_path)
		print("  📸 Captured: ", filename, ".png")

func run_capture() -> void:
	print("\n==================================================")
	print("       CAPTURING DELIVERABLE SHOWCASE SUITE       ")
	print("==================================================")
	
	var scene = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	game = scene
	await physics_frame
	await process_frame
	game._update_camera(0.0)
	game._process(0.016)
	await process_frame

	# Ensure tutorial is at initial step
	if game.tutorial != null:
		game.tutorial.current_step = 0
		game.tutorial._update_step_ui()

	# ---------------------------------------------------------
	# 1. 01_corrected_gunner_optic.png
	# ---------------------------------------------------------
	print("\n--- Capturing 01_corrected_gunner_optic ---")
	game._enter_gunner_view()
	game.player.gunner_sight.sight_range_m = 1450.0
	game.player.gunner_sight.settling_state = GunnerSightSystem.SettlingState.STABLE
	game._process(0.016)
	await capture_frame("01_corrected_gunner_optic")

	# ---------------------------------------------------------
	# 2. 02_barrel_no_obstruction.png
	# ---------------------------------------------------------
	print("\n--- Capturing 02_barrel_no_obstruction ---")
	# Traverse slightly right to showcase that barrel remains cleanly beside aperture
	game.player.gunner_sight.commanded_yaw += 0.05
	game._process(0.016)
	await capture_frame("02_barrel_no_obstruction")
	game.player.gunner_sight.commanded_yaw -= 0.05

	# ---------------------------------------------------------
	# 3. 03_tactical_view_collapsed_ui.png
	# ---------------------------------------------------------
	print("\n--- Capturing 03_tactical_view_collapsed_ui ---")
	game._exit_gunner_view()
	game.left_drawer.visible = false
	game.debug_overlay_enabled = false
	game._process(0.016)
	await capture_frame("03_tactical_view_collapsed_ui")

	# ---------------------------------------------------------
	# 4. 04_contact_selected.png
	# ---------------------------------------------------------
	print("\n--- Capturing 04_contact_selected ---")
	# Populate contact in intelligence
	game.player_track.estimated_position = game.enemy.position + Vector3(0, 0, 15)
	game.player_track.estimated_range = 1450.0
	game.player_track.range_uncertainty = 35.0
	game.player_track.estimated_bearing_deg = 89.5
	game.player_track.estimated_heading_deg = 270.0
	game.player_track.estimated_speed_mps = 5.0
	game.player_track.last_observation_time = game.sim_time
	game.player_track.has_silhouette = true
	game.player_track.silhouette_position = game.player_track.estimated_position
	game._publish_contact()
	game._update_contextual_bar()
	game._process(0.016)
	await capture_frame("04_contact_selected")

	# ---------------------------------------------------------
	# 5. 05_clean_orders_drawer.png
	# ---------------------------------------------------------
	print("\n--- Capturing 05_clean_orders_drawer ---")
	game.left_drawer.visible = true
	# Clear existing actions and add clean human-intent actions
	game.action_queue.actions.clear()
	game._append_action("move", game.player.position + Vector3(0, 0, -45))
	game._append_action("aim", game.player_track.estimated_position)
	game._append_action("fire", game.player_track.estimated_position)
	game._process(0.016)
	await capture_frame("05_clean_orders_drawer")
	game.left_drawer.visible = false

	# ---------------------------------------------------------
	# 6. 06_f3_debug_view.png
	# ---------------------------------------------------------
	print("\n--- Capturing 06_f3_debug_view ---")
	game.debug_overlay_enabled = true
	if game.gunner_overlay != null:
		game.gunner_overlay.debug_mode = true
	game.player.set_debug_visuals(true)
	game.enemy.set_debug_visuals(true)
	game._process(0.016)
	await capture_frame("06_f3_debug_view")
	game.debug_overlay_enabled = false
	if game.gunner_overlay != null:
		game.gunner_overlay.debug_mode = false
	game.player.set_debug_visuals(false)
	game.enemy.set_debug_visuals(false)

	# ---------------------------------------------------------
	# 7. 07_wrong_range_short_test.png
	# ---------------------------------------------------------
	print("\n--- Capturing 07_wrong_range_short_test ---")
	game._enter_gunner_view()
	# Wrong range: 500m dialed for 1450m target
	game.player.gunner_sight.sight_range_m = 500.0
	game.action_queue.actions.clear()
	game._queue_gunner_fire()
	# Execute pulse to simulate shell flight and splash short
	game._execute()
	for i in range(50):
		game._physics_process(1.0 / 60.0)
		game._process(1.0 / 60.0)
	await capture_frame("07_wrong_range_short_test")

	# ---------------------------------------------------------
	# 8. 08_corrected_range_hit_test.png
	# ---------------------------------------------------------
	print("\n--- Capturing 08_corrected_range_hit_test ---")
	# Re-enter planning and dial correct range
	game._stop_and_edit()
	game.phase = "PLANNING"
	game.player.model.rounds = 25
	game.player.shot_pending = false
	game.player.gunner_sight.sight_range_m = 1450.0
	game.action_queue.actions.clear()
	game._queue_gunner_fire()
	game._execute()
	for i in range(80):
		game._physics_process(1.0 / 60.0)
		game._process(1.0 / 60.0)
	await capture_frame("08_corrected_range_hit_test")

	print("\n==================================================")
	print("       ALL 8 SHOWCASE SCREENSHOTS CAPTURED!       ")
	print("==================================================")
	game.queue_free()
	quit(0)
