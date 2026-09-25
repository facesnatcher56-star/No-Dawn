extends SceneTree
const Harness = preload("res://tests/PlaybackHarness.gd")
var game
var failures = 0
func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func capture(filename: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args(): return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/" + filename + ".png")

func run() -> void:
	game = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await physics_frame
	game.set_physics_process(false)
	await process_frame
	# process_frame is emitted before node processing; initialize camera/UI
	# explicitly so headless mode exercises the same projected clicks.
	game._process(0.0)
	await capture("planning")
	check(game.help_box.visible and game.movement_button.visible and game.fire_button.visible, "Basic actions and help are visible on first launch")
	check(game.order_summary.text.contains("No shot queued"), "No implicit shot on startup")
	game.movement_button.pressed.emit()
	check(game.input_mode == "move", "MOVE button selects destination input")
	var start: Vector3 = game.player.position
	var destination = start + Vector3(12, 0, 0)
	var point: Vector2 = game.camera.unproject_position(destination)
	var click = InputEventMouseButton.new()
	click.pressed = true
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = point
	game._unhandled_input(click)
	check(game.travel_target != null and game.travel_target.distance_to(destination) < 0.1, "Clicking the yard queues the projected destination")
	check(game.player.position == start, "Queuing movement never moves during planning")
	await capture("move_order")
	var displayed: Dictionary = game.display_contact.duplicate(true)
	game._execute()
	game.enemy.orders.fire = false
	game._set_mode("fire")
	check(game.input_mode == "select", "Target selection cannot change during execution")
	for i in range(120):
		await physics_frame
		game._physics_process(1.0 / 60)
	check(game.display_contact == displayed, "Ordinary acoustic samples do not jitter the displayed contact mid-turn")
	check(await Harness.finish_turn(game), "Execution and all impact replays finish")
	check(game.phase == "ASSESSMENT", "Move completes in a five-second execution")
	check(game.player.position.distance_to(destination) < 0.7, "Destination movement reaches the previewed point")
	check(game.travel_target == null, "Reached destinations clear their route marker")
	check(game.display_contact.time > displayed.time, "Accumulated acoustic report publishes at turn end")
	game._queue_move(Vector3(-95, 0, 160))
	check(game.travel_target == null and game.order_notice.contains("blocked"), "Route through warehouse cover is rejected with an explanation")
	game._queue_scan()
	check(not game.fields.fire.button_pressed and game.fields.light.button_pressed and not game.fields.engine.button_pressed, "Scan queues observation, searchlight and quiet engine without firing")
	game._clear_orders()
	game._queue_move(game.player.position + Vector3(55, 0, 0))
	check(game.travel_target != null and game.fields.engine.button_pressed, "Move restarts the engine after scanning")
	game.fire_button.pressed.emit()
	var aim_point: Vector3 = game.display_contact.position
	click.position = game.camera.unproject_position(aim_point)
	game._unhandled_input(click)
	check(game.fields.fire.button_pressed and game.aim_selected, "AIM & FIRE plus battlefield click queues a shot")
	var fixed_aim: Vector3 = game._planned_aim()
	game.player.position += Vector3(1, 0, 0)
	check(game._planned_aim() == fixed_aim, "Firing point stays anchored to the selected world location when the tank moves")
	game.player.position -= Vector3(1, 0, 0)
	await capture("fire_order")
	game._clear_orders()
	check(game.travel_target == null and not game.fields.fire.button_pressed and not game.aim_selected, "Clear orders removes move and shot previews")
	game.contact_fire_button.pressed.emit()
	check(game.fields.fire.button_pressed and game.aim_target == game.display_contact.position, "Contact card queues fire at the displayed estimate, not hidden truth")
	game._clear_orders()
	var turn_destination: Vector3 = game.player.position + Vector3(0, 0, -10)
	game._queue_move(turn_destination)
	game._execute()
	game.enemy.shot_pending = false
	check(await Harness.finish_turn(game), "Execution and all impact replays finish")
	check(game.player.position.distance_to(turn_destination) < 0.7, "Click-to-move turns the hull before advancing to the actual destination")
	game._clear_orders()
	var long_destination: Vector3 = game.player.position + Vector3(55, 0, 0)
	game._queue_move(long_destination)
	game._execute()
	game.enemy.shot_pending = false
	check(await Harness.finish_turn(game), "Execution and all impact replays finish")
	check(game.travel_target != null and game.player.position.distance_to(long_destination) > 1, "Long destination stays queued after the execution budget runs out")
	check(game.phase_report.contains("Move still queued"), "Assessment explains why a long movement has not finished")
	print("Usability checks completed; failures: ", failures)
	quit(failures)
