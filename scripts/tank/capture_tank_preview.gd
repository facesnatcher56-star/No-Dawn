extends SceneTree

const INSPECTION_SCENE = preload("res://scenes/tank/TankInspection.tscn")
const MastodonVisualController = preload("res://scripts/tank/MastodonVisualController.gd")

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var scene = INSPECTION_SCENE.instantiate()
	root.add_child(scene)
	current_scene = scene
	
	# Wait for setup and frames to render
	for i in range(10):
		await process_frame
	await RenderingServer.frame_post_draw
	
	# 1. Capture Normal View
	var img_normal = root.get_texture().get_image()
	img_normal.save_png("res://assets/models/tank/mastodon_exterior.png")
	img_normal.save_png("C:/Users/lloyd/.gemini/antigravity/brain/ed4dbe74-3d16-4895-99c7-be6ff9a3c63c/mastodon_exterior.png")
	print("Captured mastodon_exterior.png")
	
	# 2. Switch to X-Ray View
	scene.tank_instance.set_display_mode(MastodonVisualController.DisplayMode.XRAY)
	for i in range(10):
		await process_frame
	await RenderingServer.frame_post_draw
	
	var img_xray = root.get_texture().get_image()
	img_xray.save_png("res://assets/models/tank/mastodon_xray.png")
	img_xray.save_png("C:/Users/lloyd/.gemini/antigravity/brain/ed4dbe74-3d16-4895-99c7-be6ff9a3c63c/mastodon_xray.png")
	print("Captured mastodon_xray.png")

	# 3. Switch to Cutaway View with Articulated Hatches & Recoil
	scene.tank_instance.set_display_mode(MastodonVisualController.DisplayMode.CUTAWAY)
	scene.tank_instance.set_commander_hatch(true)
	scene.tank_instance.set_commander_exposed(true)
	scene.tank_instance.set_loader_hatch(true)
	scene.tank_instance.set_driver_hatch(true)
	scene.tank_instance.rotate_turret(deg_to_rad(25.0))
	scene.tank_instance.elevate_gun(deg_to_rad(10.0))
	for i in range(10):
		await process_frame
	await RenderingServer.frame_post_draw
	
	var img_cutaway = root.get_texture().get_image()
	img_cutaway.save_png("res://assets/models/tank/mastodon_cutaway.png")
	img_cutaway.save_png("C:/Users/lloyd/.gemini/antigravity/brain/ed4dbe74-3d16-4895-99c7-be6ff9a3c63c/mastodon_cutaway.png")
	print("Captured mastodon_cutaway.png")
	
	# 4. Front-three-quarter view in normal mode
	scene.tank_instance.set_display_mode(MastodonVisualController.DisplayMode.NORMAL)
	scene.camera_yaw = deg_to_rad(-145.0)
	scene.camera_pitch = deg_to_rad(-14.0)
	scene.camera_distance = 10.5
	scene._update_camera()
	for i in range(10):
		await process_frame
	await RenderingServer.frame_post_draw
	
	var img_front = root.get_texture().get_image()
	img_front.save_png("res://assets/models/tank/mastodon_front.png")
	img_front.save_png("C:/Users/lloyd/.gemini/antigravity/brain/ed4dbe74-3d16-4895-99c7-be6ff9a3c63c/mastodon_front.png")
	print("Captured mastodon_front.png")
	
	quit(0)
