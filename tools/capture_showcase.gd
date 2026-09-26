extends SceneTree

const ARTIFACT_DIR = "C:/Users/lloyd/.gemini/antigravity/brain/ed4dbe74-3d16-4895-99c7-be6ff9a3c63c/"
const PROJECT_DIR = "res://screenshots/"

var game: Node3D
var step: int = 0
var frame_wait: int = 0

func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PROJECT_DIR))
	call_deferred("_start")

func _start() -> void:
	print("--- Starting 10-Shot Showcase Capture ---")
	game = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	
	process_frame.connect(_on_process_frame)

func _save_screenshot(filename: String) -> void:
	var vp = root.get_viewport()
	var img = vp.get_texture().get_image()
	if img != null and not img.is_empty():
		var proj_path = ProjectSettings.globalize_path(PROJECT_DIR + filename)
		var art_path = ARTIFACT_DIR + filename
		img.save_png(proj_path)
		img.save_png(art_path)
		print("  [SAVED] ", filename, " (", img.get_width(), "x", img.get_height(), ")")
	else:
		push_error("Failed to capture image for " + filename)

func _on_process_frame() -> void:
	if frame_wait > 0:
		frame_wait -= 1
		return
		
	step += 1
	match step:
		1:
			# Setup 1: Normal planning view
			print("Setting up Shot 1: Normal planning view...")
			game.left_drawer.visible = false
			game.right_drawer.visible = false
			game.cam_target = Vector3(-178, 0, 110)
			game.cam_yaw = deg_to_rad(-65.0)
			game.cam_pitch = deg_to_rad(-22.0)
			game.cam_distance = 24.0
			game._update_camera(0.0)
			game.action_hint.text = "PLANNING — ORDERS NOT EXECUTING"
			game.action_hint.add_theme_color_override("font_color", Color(0.45, 0.85, 0.95))
			game.radio_callout_label.text = "RADIO: 1ST PLATOON ADVANCING ALONG AXIS ALPHA • OVERCAST CONDITIONS"
			game.radio_callout_label.get_parent().visible = true
			game.tank_card_label.text = "A-47 MASTODON • OPERATIONAL\nAMMO: 25/25 AP • SPEED: 0.0 m/s\nCREW STATIONS GREEN • 128mm READY"
			frame_wait = 20
			
		2:
			_save_screenshot("01_normal_planning_view.png")
			# Setup 2: Close view of player tank
			print("Setting up Shot 2: Close view of player tank...")
			game.cam_target = game.player.global_position + Vector3(0, 1.8, 0)
			game.cam_yaw = deg_to_rad(-45.0)
			game.cam_pitch = deg_to_rad(-18.0)
			game.cam_distance = 11.5
			game._update_camera(0.0)
			game.radio_callout_label.text = "COMMANDER: ALL CREW STATIONS MANNED • 128mm MAIN BREECH INSPECTED"
			frame_wait = 20
			
		3:
			_save_screenshot("02_close_view_player_tank.png")
			# Setup 3: Movement path planning
			print("Setting up Shot 3: Movement path planning...")
			game.cam_target = Vector3(-168, 0, 110)
			game.cam_yaw = deg_to_rad(-65.0)
			game.cam_pitch = deg_to_rad(-22.0)
			game.cam_distance = 28.0
			game._update_camera(0.0)
			game.travel_target = Vector3(-140, 0, 110)
			game.world_graphics.update_route(game.player.global_position, game.travel_target, [], true)
			game.action_queue.append("move", game.travel_target, 5.0, false)
			game._rebuild_queue()
			game.left_drawer.visible = true
			game.radio_callout_label.text = "DRIVER: ROUTE PLOTTED • ESTIMATED TRANSIT TIME 4.2 SECONDS"
			frame_wait = 20
			
		4:
			_save_screenshot("03_movement_path_planning.png")
			# Setup 4: Enemy visual contact
			print("Setting up Shot 4: Enemy visual contact...")
			game.left_drawer.visible = false
			game.action_queue.actions.clear()
			game._rebuild_queue()
			game.travel_target = null
			game.world_graphics.update_route(game.player.position, null, [], false)
			game.is_orbiting = true
			game.enemy.position = Vector3(-145, 0, 110)
			game.player_track.has_visual_los = true
			game.player_track.time_since_visual = 0.0
			game.player_track.last_observation_time = game.sim_time
			game.player_track.estimated_position = game.enemy.position
			game.player_track.position_uncertainty = 1.8
			game.player_track.range_uncertainty = 2.0
			game.player_track.identification_confidence = 0.98
			game._publish_contact()
			game.enemy.visible = true
			game.contact_visual_position = game.enemy.position
			game.contact_visual_radius = 2.5
			game.world_graphics.update_observation(game.player.position, game.player.rotation.y + game.player.model.turret_yaw, true)
			game.cam_target = (game.player.position + game.enemy.position) * 0.5 + Vector3(0, 1.2, 0)
			game.cam_yaw = deg_to_rad(-65.0)
			game.cam_pitch = deg_to_rad(-20.0)
			game.cam_distance = 30.0
			game._update_camera(0.0)
			game.radio_callout_label.text = "GUNNER: TARGET IDENTIFIED! ENEMY HEAVY TANK SIGHTED AT 40 METERS"
			frame_wait = 20
			
		5:
			_save_screenshot("04_enemy_visual_contact.png")
			# Setup 5: Enemy last-known ghost + prediction corridor
			print("Setting up Shot 5: Enemy last-known ghost + prediction corridor...")
			game.is_orbiting = true
			game.display_contact = {}
			game.player_track.has_visual_los = false
			game.player_track.time_since_visual = 3.0
			game.player_track.has_silhouette = true
			game.player_track.silhouette_position = Vector3(-140, 0, 110)
			game.player_track.silhouette_yaw = PI / 2
			game.player_track.silhouette_speed_mps = 4.5
			game.player_track.silhouette_heading_deg = 90.0
			game.player_track.silhouette_time = game.sim_time - 3.0
			game.player_track.heading_uncertainty = 18.0
			game.player_track.estimated_speed_mps = 4.5
			game.ghost_tank.visible = true
			game.ghost_tank.position = game.player_track.silhouette_position
			game.ghost_tank.rotation.y = game.player_track.silhouette_yaw
			game.world_graphics.update_predicted_corridor(game.player_track.get_predicted_corridor(5.5), true)
			game.cam_target = (game.player.position + game.player_track.silhouette_position) * 0.5 + Vector3(0, 1.2, 0)
			game.cam_yaw = deg_to_rad(-65.0)
			game.cam_pitch = deg_to_rad(-20.0)
			game.cam_distance = 32.0
			game._update_camera(0.0)
			game.radio_callout_label.text = "COMMANDER: VISUAL LOST • TRACKING LAST-KNOWN GHOST & PREDICTED CORRIDOR"
			frame_wait = 20
			
		6:
			_save_screenshot("05_enemy_last_known_ghost_corridor.png")
			# Setup 6: Simultaneous execution
			print("Setting up Shot 6: Simultaneous execution...")
			game.ghost_tank.visible = false
			game.world_graphics.update_predicted_corridor({}, false)
			game.world_graphics.update_observation(game.player.position, 0.0, false)
			game.left_drawer.visible = false
			game.right_drawer.visible = false
			game.phase = "EXECUTION"
			game.time_left = 3.2
			game.execution_progress.value = 1.8
			game.action_hint.text = "EXECUTING: 3.2 → 0.0 SEC (PULSE IN PROGRESS)"
			game.action_hint.add_theme_color_override("font_color", Color(1.0, 0.82, 0.28))
			game.radio_callout_label.text = "TACTICAL: SIMULTANEOUS EXECUTION IN PROGRESS • ADVANCING TO ENGAGEMENT LINE"
			game.player.speed = 4.5
			game.enemy.speed = 4.0
			frame_wait = 20
			
		7:
			_save_screenshot("06_simultaneous_execution.png")
			# Setup 7: Main gun firing (with muzzle blast FX)
			print("Setting up Shot 7: Main gun firing (with muzzle blast FX)...")
			game.phase = "PLANNING"
			game.player.speed = 0.0
			game.enemy.speed = 0.0
			# Position dramatic firing camera
			game.cam_target = game.player.global_position + Vector3(4, 1.8, 0)
			game.cam_yaw = deg_to_rad(-115.0)
			game.cam_pitch = deg_to_rad(-14.0)
			game.cam_distance = 19.0
			game._update_camera(0.0)
			var muzzle_pos = game.player.global_position - game.player.turret.global_basis.z * 6.5 + Vector3(0, 2.25, 0)
			var muzzle_dir = -game.player.turret.global_basis.z
			game.CombatEffects.spawn_muzzle_blast(game, muzzle_pos, muzzle_dir)
			if game.player.visual_tank != null:
				game.player.visual_tank.fire_recoil()
			game.radio_callout_label.text = "GUNNER: ON THE WAY! 128mm APCBC-HE ROUND DISCHARGED"
			frame_wait = 12
			
		8:
			_save_screenshot("07_main_gun_firing_fx.png")
			# Setup 8: Penetration replay
			print("Setting up Shot 8: Penetration replay...")
			for child in game.get_children():
				if child is GPUParticles3D:
					child.queue_free()
			var record = game.enemy.model.resolve(Vector3(0.1, 1.5, 8.0), Vector3(0, -0.05, -1).normalized(), 920.0, 42)
			record.range = 65.0
			record.speed = 920.0
			record.shooter = "Your tank"
			record.target = "Contact A"
			record.shot_id = 1
			record.time = 2.4
			game.records.append(record.duplicate(true))
			game.playback.enqueue(record)
			game._begin_impact()
			game.playback.replay_time = 4.5
			game.impact_viewer.seek(4.5)
			game._refresh_impact()
			game.radio_callout_label.text = "COMMANDER: DIRECT HIT CONFIRMED! CATASTROPHIC PENETRATION ON TARGET"
			frame_wait = 20
			
		9:
			_save_screenshot("08_penetration_replay.png")
			# Setup 9: Crew drawer
			print("Setting up Shot 9: Crew drawer...")
			for child in game.get_children():
				if child is GPUParticles3D:
					child.queue_free()
			game.impact_panel.visible = false
			game.right_drawer.visible = true
			game.detail_tabs.current_tab = 2
			game.detail_tabs.tab_changed.emit(2)
			game.crew_label.text = "1. Commander: LT. VANCE · READY (CUPOLA HATCH OPEN)\n2. Gunner: CPL. STONE · LAID ON TARGET (OPTICS CLEAR)\n3. Driver: SGT. KOVACS · IN GEAR (TERRAIN STABLE)\n4. Loader: PFC. MILLER · 128mm APCBC READY (RELOAD 0.0s)\n5. Radio Operator: CPL. REYES · MONITORING TAC-NET\n\nCREW MORALE: 95% • FATIGUE: 8% (FRESH)"
			game.cam_target = game.player.global_position + Vector3(0, 1.5, 0)
			game.cam_yaw = deg_to_rad(-45.0)
			game.cam_pitch = deg_to_rad(-18.0)
			game.cam_distance = 14.0
			game._update_camera(0.0)
			game.radio_callout_label.text = "CREW ROSTER: ALL STATIONS COMBAT-READY AND FUNCTIONAL"
			frame_wait = 20
			
		10:
			_save_screenshot("09_crew_drawer.png")
			# Setup 10: Intelligence drawer
			print("Setting up Shot 10: Intelligence drawer...")
			game.detail_tabs.current_tab = 0
			game.detail_tabs.tab_changed.emit(0)
			game.contact_label.text = "CONTACT ALPHA TACTICAL RECONNAISSANCE\n========================================\nCLASSIFICATION: Heavy Armored Combat Vehicle\nCONFIDENCE: 94% (Visual + Acoustic Triangulation)\nRANGE: 165m (Uncertainty ±8m)\nBEARING: 088° East\nESTIMATED SPEED: 14 km/h\nARMAMENT: 122mm / 152mm High-Velocity\nARMOR PROFILE: Heavy Cast Turret / Sloped Glacis\nTARGET STATUS: Moving to hull-down position\nRECOMMENDED SOP: Fire on halt / AP sabot loaded"
			game.radio_callout_label.text = "INTELLIGENCE: TARGET PROFILE CORRELATED WITH BRIGADE RECON NETWORK"
			frame_wait = 20
			
		11:
			_save_screenshot("10_intelligence_drawer.png")
			print("--- All 10 Showcase Screenshots Captured Successfully! ---")
			quit(0)
