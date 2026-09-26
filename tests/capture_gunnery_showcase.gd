extends SceneTree

const GunnerSightSystem = preload("res://scripts/wego/GunnerSightSystem.gd")

var game
var artifact_dir = "C:/Users/lloyd/.gemini/antigravity/brain/ed4dbe74-3d16-4895-99c7-be6ff9a3c63c/"

func _initialize() -> void:
	call_deferred("run")

func capture_frame(filename: String) -> void:
	game._process(0)
	await process_frame
	await RenderingServer.frame_post_draw
	var img = root.get_texture().get_image()
	if img != null:
		var target_path = artifact_dir + filename + ".png"
		img.save_png(target_path)
		print("  📸 Saved screenshot: ", target_path)

func run() -> void:
	print("=== Running Gunnery Sight Visual Showcase Capture ===")
	var scene = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	game = scene
	await physics_frame
	game.set_physics_process(false)
	game._process(0)
	await process_frame

	# Step 1: Detect contact so intelligence drawer has contact info
	game.player_track.estimated_position = game.enemy.position + Vector3(0, 0, 15)
	game.player_track.estimated_range = 1485.0
	game.player_track.range_uncertainty = 45.0
	game.player_track.estimated_bearing_deg = 90.0
	game.player_track.estimated_heading_deg = 270.0
	game.player_track.estimated_speed_mps = 6.2
	game.player_track.last_observation_time = game.sim_time
	game.player_track.has_silhouette = true
	game.player_track.silhouette_position = game.player_track.estimated_position
	game._publish_contact()
	game._process(0)
	await process_frame

	# Show Intelligence Drawer with new SLEW TURRET TO CONTACT [G] button
	game.right_drawer.visible = true
	await capture_frame("gunner_intel_drawer_slew_button")

	# Step 2: Slew to contact & Enter Gunner Sight View
	game._slew_to_contact_and_aim()
	game._process(0.1)
	await capture_frame("gunner_sight_periscope_view")

	# Step 3: Dial range, apply lead, queue fire
	game.player.gunner_sight.sight_range_m = 1500.0
	game.player.gunner_sight.commanded_pitch = 0.005 # Small superelevation
	game.player.gunner_sight.settling_state = GunnerSightSystem.SettlingState.STABLE
	game._queue_gunner_fire()
	game._process(0.1)
	await capture_frame("gunner_sight_fire_queued")

	# Step 4: Exit to Tactical Perspective
	game._exit_gunner_view()
	game.left_drawer.visible = true
	game._process(0.1)
	await capture_frame("gunner_tactical_orders_perspective")

	print("=== Visual Showcase Complete ===")
	quit(0)
