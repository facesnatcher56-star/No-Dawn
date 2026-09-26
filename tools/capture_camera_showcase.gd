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
	print("--- Starting Camera & Control Showcase Capture ---")
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
			print("Setting up Shot 1: Top-down high altitude battlefield overview...")
			game.left_drawer.visible = false
			game.right_drawer.visible = false
			game.cam_distance = 220.0
			game.cam_pitch = deg_to_rad(-84.0)
			game.cam_yaw = deg_to_rad(-65.0)
			game.cam_following_player = true
			game._update_camera(0.0)
			game.action_hint.text = "TACTICAL OVERVIEW — TOP-DOWN PERSPECTIVE • 3.6 KM BATTLEFIELD"
			game.action_hint.add_theme_color_override("font_color", Color(0.45, 0.85, 0.95))
			frame_wait = 25
			
		2:
			_save_screenshot("top_down_high_altitude_view.png")
			frame_wait = 10

		3:
			print("Setting up Shot 2: Left-click auto-move route planning & undo...")
			game.cam_distance = 32.0
			game.cam_pitch = deg_to_rad(-26.0)
			game.cam_following_player = true
			game._update_camera(0.0)
			game._clear_orders()
			game._queue_move(game.player.position + Vector3(45, 0, 0))
			game._append_action("aim", game.player.position + Vector3(50, 1.6, 20))
			game.action_hint.text = "PLANNING — Left-click ground to MOVE • Right-click to UNDO last order"
			game.order_notice = "Aim Added. Right-click cancels last order."
			frame_wait = 25

		4:
			_save_screenshot("left_click_move_and_undo.png")
			frame_wait = 10

		5:
			print("Setting up Shot 3: Simultaneous execution tracking player tank...")
			game.cam_distance = 26.0
			game.cam_pitch = deg_to_rad(-22.0)
			game.cam_following_player = true
			game._update_camera(0.0)
			game._execute()
			frame_wait = 30

		6:
			_save_screenshot("simultaneous_execution_cam_on_player.png")
			print("--- Showcase Capture Complete ---")
			quit(0)
