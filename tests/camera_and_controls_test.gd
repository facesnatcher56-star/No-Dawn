extends SceneTree

var game
var failures = 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FAILURE: " + message)
	else:
		print("PASS: " + message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	game = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await physics_frame
	game.set_physics_process(false)
	await process_frame

	print("=== Running Camera & Controls Test Suite ===")

	# 1. Test Camera Initialization
	game._update_camera(0.0)
	check(game.cam_target.is_equal_approx(game.player.position), "Camera target initializes on player tank position")
	check(game.camera.far >= 4000.0, "Camera far clip is extended to 4500m for full battlefield overview")

	# 2. Test Zoom-Out to Top-Down View
	var init_dist = game.cam_distance
	var init_pitch = game.cam_pitch
	
	# Simulate wheel down (zoom out) multiple times
	for i in range(15):
		var wheel_down = InputEventMouseButton.new()
		wheel_down.pressed = true
		wheel_down.button_index = MOUSE_BUTTON_WHEEL_DOWN
		game._unhandled_input(wheel_down)

	check(game.cam_distance > 180.0, "Camera zooms out to expansive overview (cam_distance = %.1fm)" % game.cam_distance)
	check(game.cam_pitch < deg_to_rad(-65.0), "Camera pitch tilts smoothly towards top-down (cam_pitch = %.1f°)" % rad_to_deg(game.cam_pitch))

	# Zoom back in
	for i in range(15):
		var wheel_up = InputEventMouseButton.new()
		wheel_up.pressed = true
		wheel_up.button_index = MOUSE_BUTTON_WHEEL_UP
		game._unhandled_input(wheel_up)

	check(game.cam_distance < 35.0, "Camera zooms back in to close tactical range (cam_distance = %.1fm)" % game.cam_distance)
	check(game.cam_pitch > deg_to_rad(-40.0), "Camera pitch eases back down to third-person angle (cam_pitch = %.1f°)" % rad_to_deg(game.cam_pitch))

	# 3. Test Camera Behavior During Turn Execution
	# Set a custom camera distance and pitch before execution
	game.cam_distance = 68.0
	game.cam_pitch = deg_to_rad(-45.0)
	var expected_dist = game.cam_distance
	var expected_pitch = game.cam_pitch

	game._execute()
	check(game.phase == "EXECUTION", "Turn execution started")
	
	# Simulate multiple frames of camera update during execution
	for i in range(60):
		game._update_camera(1.0 / 60.0)

	check(is_equal_approx(game.cam_distance, expected_dist), "Camera distance is NOT forcibly yanked to 22m on execution (stayed at %.1fm)" % game.cam_distance)
	check(is_equal_approx(game.cam_pitch, expected_pitch), "Camera pitch is NOT forcibly yanked to -20° on execution (stayed at %.1f°)" % rad_to_deg(game.cam_pitch))
	check(game.cam_target.distance_to(game.player.position) < 0.5, "Camera target stays anchored to player tank, NOT combat midpoint or enemy")

	# Finish turn execution
	game.phase = "PLANNING"
	game._clear_orders()

	# 4. Test Left-Click With Nothing Selected Auto-Queues Move
	check(game.input_mode == "select", "Default input mode is 'select' (nothing selected)")
	var move_dest = game.player.position + Vector3(25, 0, 0)
	var screen_pos = game.camera.unproject_position(move_dest)
	
	var left_click = InputEventMouseButton.new()
	left_click.pressed = true
	left_click.button_index = MOUSE_BUTTON_LEFT
	left_click.position = screen_pos
	game._unhandled_input(left_click)

	check(game.travel_target != null and game.travel_target.distance_to(move_dest) < 0.2, "Left-clicking ground with nothing selected auto-assumes move to destination")
	check(game.action_queue.actions.size() == 1 and game.action_queue.actions[0].kind == "move", "Move action was added to queue automatically")

	# Queue a second action (aim)
	var aim_point = game.player.position + Vector3(0, 0, 50)
	game._append_action("aim", aim_point)
	check(game.action_queue.actions.size() == 2, "Two actions now in queue (move + aim)")

	# 5. Test Right-Click Removes/Pops Last Queued Order
	var right_click_down = InputEventMouseButton.new()
	right_click_down.pressed = true
	right_click_down.button_index = MOUSE_BUTTON_RIGHT
	right_click_down.position = Vector2(400, 300)
	game._unhandled_input(right_click_down)

	var right_click_up = InputEventMouseButton.new()
	right_click_up.pressed = false
	right_click_up.button_index = MOUSE_BUTTON_RIGHT
	right_click_up.position = Vector2(400, 300) # No drag
	game._unhandled_input(right_click_up)

	check(game.action_queue.actions.size() == 1, "First right-click popped last action (aim removed, 1 action left)")
	check(game.action_queue.actions[0].kind == "move", "Remaining action is move")

	# Second right-click
	game._unhandled_input(right_click_down)
	game._unhandled_input(right_click_up)
	check(game.action_queue.actions.is_empty(), "Second right-click popped remaining move action (queue empty)")
	check(game.travel_target == null, "Travel target cleared when queue becomes empty")

	# 6. Test Right-Click Drag Orbit Does NOT Pop Orders
	game._queue_move(game.player.position + Vector3(20, 0, 0))
	check(game.action_queue.actions.size() == 1, "Queued move order before drag test")

	# Press right click
	game._unhandled_input(right_click_down)
	# Drag mouse by 40 pixels
	var mouse_motion = InputEventMouseMotion.new()
	mouse_motion.position = Vector2(440, 300)
	game._unhandled_input(mouse_motion)
	# Release right click
	right_click_up.position = Vector2(440, 300)
	game._unhandled_input(right_click_up)

	check(game.action_queue.actions.size() == 1, "Right-click drag orbiting did NOT pop queued order (orbit distinguished from click)")

	print("\n=== Test Results: %d failures ===" % failures)
	quit(1 if failures > 0 else 0)
