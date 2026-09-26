extends SceneTree

const INSPECTION_SCENE = preload("res://scenes/tank/TankInspection.tscn")
const MastodonVisualController = preload("res://scripts/tank/MastodonVisualController.gd")

var ARTIFACT_DIR = "C:/Users/lloyd/.gemini/antigravity/brain/ed4dbe74-3d16-4895-99c7-be6ff9a3c63c/"
var MODEL_DIR = "res://assets/models/tank/"

func _initialize() -> void:
	call_deferred("capture_all")

func capture_all() -> void:
	var scene = INSPECTION_SCENE.instantiate()
	root.add_child(scene)
	current_scene = scene
	
	# Hide UI for clean beauty shots
	if scene.ui_root:
		scene.ui_root.visible = false
		
	# Helper to wait for render
	var wait_render = func():
		for i in range(12):
			await process_frame
		await RenderingServer.frame_post_draw
		
	var save_shot = func(name: String):
		var img = root.get_texture().get_image()
		img.save_png(MODEL_DIR + name + ".png")
		img.save_png(ARTIFACT_DIR + name + ".png")
		print("  📸 Captured: ", name, ".png")

	print("\n--- Starting Tank Beauty Capture Suite ---")

	# 1. Front 3/4 View (Normal Exterior)
	scene.tank_instance.set_display_mode(MastodonVisualController.DisplayMode.NORMAL)
	scene.camera_yaw = deg_to_rad(-145.0)
	scene.camera_pitch = deg_to_rad(-14.0)
	scene.camera_distance = 10.5
	scene._update_camera()
	await wait_render.call()
	save_shot.call("mastodon_front_34")
	save_shot.call("mastodon_front") # Also update default front

	# 2. Side View
	scene.camera_yaw = deg_to_rad(-90.0)
	scene.camera_pitch = deg_to_rad(-5.0)
	scene.camera_distance = 11.0
	scene._update_camera()
	await wait_render.call()
	save_shot.call("mastodon_side")

	# 3. Rear 3/4 View
	scene.camera_yaw = deg_to_rad(-35.0)
	scene.camera_pitch = deg_to_rad(-16.0)
	scene.camera_distance = 10.5
	scene._update_camera()
	await wait_render.call()
	save_shot.call("mastodon_rear_34")

	# 4. Top-Down View
	scene.camera_yaw = deg_to_rad(0.0)
	scene.camera_pitch = deg_to_rad(-78.0)
	scene.camera_distance = 12.0
	scene._update_camera()
	await wait_render.call()
	save_shot.call("mastodon_top")

	# 5. Cutaway View (Armor hidden, showing internal V12 engine, transmission, ammo racks, crew)
	scene.tank_instance.set_display_mode(MastodonVisualController.DisplayMode.CUTAWAY)
	scene.camera_yaw = deg_to_rad(-140.0)
	scene.camera_pitch = deg_to_rad(-22.0)
	scene.camera_distance = 9.8
	scene._update_camera()
	await wait_render.call()
	save_shot.call("mastodon_cutaway")

	# 6. X-Ray View (Translucent armor, glowing components)
	scene.tank_instance.set_display_mode(MastodonVisualController.DisplayMode.XRAY)
	scene.camera_yaw = deg_to_rad(-135.0)
	scene.camera_pitch = deg_to_rad(-18.0)
	scene.camera_distance = 10.0
	scene._update_camera()
	await wait_render.call()
	save_shot.call("mastodon_xray")
	save_shot.call("mastodon_exterior") # Update exterior

	# 7. Commander Hatch Open (Close-up of cupola with hatch opened)
	scene.tank_instance.set_display_mode(MastodonVisualController.DisplayMode.NORMAL)
	scene.tank_instance.set_commander_hatch(true)
	scene.tank_instance.set_commander_exposed(false)
	scene.camera_pivot.position = Vector3(0.62, 2.7, 0.20)
	scene.camera_yaw = deg_to_rad(45.0)
	scene.camera_pitch = deg_to_rad(-24.0)
	scene.camera_distance = 2.4
	scene._update_camera()
	await wait_render.call()
	save_shot.call("mastodon_commander_hatch_open")

	# 8. Commander Exposed Posture
	scene.tank_instance.set_commander_exposed(true)
	scene.camera_pivot.position = Vector3(0.62, 2.7, 0.20)
	scene.camera_yaw = deg_to_rad(40.0)
	scene.camera_pitch = deg_to_rad(-16.0)
	scene.camera_distance = 2.4
	scene._update_camera()
	await wait_render.call()
	save_shot.call("mastodon_commander_exposed")

	# 9. Turret Rotated (45 degrees traverse)
	scene.camera_pivot.position = Vector3(0, 0, 0)
	scene.tank_instance.set_commander_exposed(false)
	scene.tank_instance.set_commander_hatch(false)
	scene.tank_instance.rotate_turret(deg_to_rad(45.0))
	scene.tank_instance.elevate_gun(deg_to_rad(0.0))
	scene.camera_yaw = deg_to_rad(-145.0)
	scene.camera_pitch = deg_to_rad(-15.0)
	scene.camera_distance = 10.5
	scene._update_camera()
	await wait_render.call()
	save_shot.call("mastodon_turret_rotated")

	# 10. Gun Elevated (+18 degrees elevation)
	scene.camera_pivot.position = Vector3(0, 0, 0)
	scene.tank_instance.rotate_turret(deg_to_rad(0.0))
	scene.tank_instance.elevate_gun(deg_to_rad(18.0))
	scene.camera_yaw = deg_to_rad(-130.0)
	scene.camera_pitch = deg_to_rad(-8.0)
	scene.camera_distance = 9.8
	scene._update_camera()
	await wait_render.call()
	save_shot.call("mastodon_gun_elevated")

	print("--- Tank Beauty Capture Suite Completed Cleanly! ---\n")
	quit(0)
