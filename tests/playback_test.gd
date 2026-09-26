extends SceneTree
const Playback = preload("res://scripts/wego/CombatPlayback.gd")
const Harness = preload("res://tests/PlaybackHarness.gd")
var failures = 0
var game

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func capture(filename: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args(): return
	game._process(0)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/" + filename + ".png")

func new_game():
	var scene = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await physics_frame
	scene.set_physics_process(false)
	scene._process(0)
	return scene

func commit_duel(scene) -> void:
	scene.fields.bearing.value = 90.0
	scene.fields.range.value = scene.player.position.distance_to(scene.enemy.position)
	scene.fields.fire.button_pressed = true
	scene._execute()
	# Both tanks commit a shot at a known test bearing before either executes.
	scene.enemy.orders.bearing = 270.0
	scene.enemy.orders.range = scene.player.position.distance_to(scene.enemy.position)
	scene.enemy.orders.height = 1.4
	scene.enemy.shot_pending = true

func run() -> void:
	var clock = Playback.new()
	clock.feed(1)
	var ticks = 0
	while clock.take_step(): ticks += 1
	check(ticks == 30, "Default playback runs five simulated seconds over ten real seconds")
	clock.shot_fired()
	check(is_equal_approx(clock.rate(), 0.08), "Gunfire enters readable 8 percent slow motion")
	clock.enqueue({"shot_id": 1})
	clock.enqueue({"shot_id": 2})
	check(clock.start_next().shot_id == 1 and clock.pending.size() == 1, "Concurrent impacts queue without overwriting the first replay")
	clock.feed(2)
	check(not clock.take_step(), "Impact presentation never advances combat ticks")
	clock.paused = true
	clock.feed(5)
	check(clock.replay_time == 2, "Manual pause freezes the replay clock")
	clock.finish_replay()
	check(clock.start_next().shot_id == 2, "Continue advances to the next recorded shot")
	game = await new_game()
	commit_duel(game)
	for i in range(400):
		await physics_frame
		game._physics_process(0.05)
		if not game.shot_events.is_empty(): break
	check(not game.shot_events.is_empty() and game.shot_events.any(func(s): return s.shooter == game.player.name), "Player shot is recorded in flight")
	check(game.playback.rate() <= 0.08, "Live shot flight slows the actual battlefield")
	await capture("shot_flight")
	for i in range(800):
		await physics_frame
		game._physics_process(0.05)
		if not game.playback.active.is_empty(): break
	check(not game.playback.active.is_empty(), "An actual armor hit opens the impact camera")
	if game.playback.active.is_empty():
		quit(failures)
		return
	var frozen_time: float = game.sim_time
	var frozen_reload: float = game.player.model.reload
	var frozen_position: Vector3 = game.player.position
	var first_id: int = game.playback.active.shot_id
	check(game.impact_viewer.record == game.playback.active, "Large cutaway uses the exact recorded result")
	check(game.impact_title.text.contains("→"), "Impact title identifies shooter and victim")
	check(game.impact_viewer.reached_volumes.is_empty(), "Modules are not highlighted before the projectile reaches them")
	check(game.impact_viewer.paths.all(func(p): return not p.data.fragment or not p.mesh.visible), "Spall is hidden before armor contact")
	game._physics_process(1)
	game._toggle_playback_pause()
	game._physics_process(2)
	check(game.playback.replay_time == 1, "Pause Action also pauses the impact camera")
	game._toggle_playback_pause()
	game._physics_process(0.9)
	check(game.impact_viewer.impact_marker.visible, "Armor contact has its own visible replay stage")
	check(game.impact_viewer.paths.all(func(p): return not p.data.fragment or not p.mesh.visible), "Fragments never appear before the impact hold ends")
	game._physics_process(3)
	check(not game.impact_viewer.reached_volumes.is_empty(), "Internal strikes highlight in time with the recorded paths")
	check(game.sim_time == frozen_time and game.player.model.reload == frozen_reload and game.player.position == frozen_position, "Movement, reload and combat clock freeze throughout impact review")
	await capture("impact_replay")
	game.playback.restart_replay()
	game._physics_process(0)
	check(game.impact_viewer.reached_volumes.is_empty(), "Replay resets highlights without rerunning damage")
	game._skip_impact()
	check(game.playback.active.is_empty() or game.playback.active.shot_id != first_id, "Continue cannot reopen the same shot accidentally")
	check(await Harness.finish_turn(game), "Battlefield resumes after queued impact reviews")
	check(game.sim_time >= 2.9, "Slow motion and reviews preserve the action budget")
	check(game.player.model.rounds == 24 and game.enemy.model.rounds in [24, 25], "Replays never expend ammunition or resolve shots again")
	check(game.turn_report.text.contains("YOU") and game.turn_report.text.contains("FIRED"), "Turn report retains both firing events")
	check(game.records.size() >= 1, "Resolved armor impacts are retained")
	check(game.phase != "COMPLETE" or game.movement_button.disabled, "Terminal results disable unavailable action controls")
	check(game.records.all(func(r): return r.has("shooter") and r.has("shot_id")), "Every impact keeps explicit attribution")
	await capture("turn_report")
	var expected: Array = game.records.duplicate(true)
	game.queue_free()
	await process_frame
	game = await new_game()
	game.playback.speed = 1.0
	commit_duel(game)
	check(await Harness.finish_turn(game), "Normal-speed playback completes")
	check(game.records == expected, "Changing playback speed and replay pauses cannot change ballistic outcomes")
	game.queue_free()
	await process_frame
	game = await new_game()
	game.turn = 2
	game._execute()
	# Force harmless shots in opposite directions so both crews survive.
	game.player.orders.aim_point = game.player.position + Vector3(0, 1.4, -75)
	game.player.rotation.y = 0
	game.player.shot_pending = true
	game.enemy.orders.aim_point = game.enemy.position + Vector3(0, 1.4, 75)
	game.enemy.rotation.y = PI
	game.enemy.shot_pending = true
	check(await Harness.finish_turn(game), "Simultaneous duel execution completes")
	check(game.player.model.rounds == 24 and game.enemy.model.rounds == 24, "Both sides fire in simultaneous execution")
	check(game.turn_report.text.contains("FIRED"), "Report includes simultaneous firing events")
	game._execute()
	game.enemy.model.catastrophic = true
	check(await Harness.finish_turn(game), "Terminal player action completes")
	check(game.phase == "COMPLETE", "Knocked-out enemy completes engagement")
	print("Playback checks completed; failures: ", failures)
	quit(failures)
