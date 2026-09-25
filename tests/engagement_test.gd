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

func run() -> void:
	game = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await physics_frame
	game.set_physics_process(false)
	var position_before: Vector3 = game.player.position
	var clock_before: float = game.sim_time
	for i in range(60): game._physics_process(1.0 / 60)
	check(game.player.position == position_before and game.sim_time == clock_before, "Planning freezes movement and simulation clock")
	game.fields.fire.button_pressed = false
	game.fields.light.button_pressed = true
	game._execute()
	check(game.phase == "EXECUTION" and game.fields.range.editable == false, "Execute commits and locks orders")
	check(await Harness.finish_turn(game), "Execution and all impact replays finish")
	check(game.phase == "ASSESSMENT", "Five seconds ends in assessment")
	check(absf(game.sim_time - 5) < 0.001, "Execution advances exactly five simulation seconds")
	check(game.player.model.rounds == 25, "Observe-only turn consumes no ammunition")
	check(not game.player.lamp.visible, "Two-second searchlight order ends")
	check(game.display_contact.source == "Visual silhouette", "A scan retains its useful last-seen fix instead of replacing it with weaker sound estimates")
	game.fields.fire.button_pressed = true
	game._execute()
	check(await Harness.finish_turn(game), "Execution and all impact replays finish")
	check(absf(game.sim_time - 10) < 0.001, "Second simultaneous execution completes")
	check(game.phase in ["ASSESSMENT", "COMPLETE"], "Execution ends with assessment or a physical knockout")
	check(game.player.model.rounds == 24, "One fire order consumes exactly one round")
	check(game.player.model.reload > 0, "Reload longer than a turn persists")
	check(game.records.size() > 0, "Playable default firing solution hits geometric target armor")
	if game.records.size() > 0:
		check(game.viewer.record == game.records.back(), "Cutaway consumes the exact recorded result")
		check(not game.viewer.paths.is_empty(), "Cutaway creates geometry from recorded projectile paths")
	var reload_before: float = game.player.model.reload
	for i in range(60): game._physics_process(1.0 / 60)
	check(game.player.model.reload == reload_before, "Assessment freezes reload")
	if "--capture" in OS.get_cmdline_user_args():
		game.viewer.seek(game.viewer.DURATION)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tests/engagement.png")
	print("Engagement checks completed; failures: ", failures)
	quit(failures)
