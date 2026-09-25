extends SceneTree
const Harness = preload("res://tests/PlaybackHarness.gd")
const Damage = preload("res://scripts/wego/DamageReport.gd")
const Armor = preload("res://scripts/wego/ArmorModel.gd")
var game
var failures = 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func new_game():
	if is_instance_valid(game):
		game.queue_free()
		await process_frame
	var scene = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await physics_frame
	scene.set_physics_process(false)
	scene._process(0)
	return scene

func capture(filename: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args(): return
	game._process(0)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/" + filename + ".png")

func run() -> void:
	game = await new_game()
	game._append_action("aim", game.player.position + Vector3(0, 1.4, -75))
	var hull: float = game.player.rotation.y
	var position: Vector3 = game.player.position
	var turret: float = game.player.model.turret_yaw
	check(absf(game.action_queue.estimates(game.player)[0].seconds - PI) < 0.01, "Turret estimate includes angular travel at its actual rate")
	game._execute()
	for i in range(60):
		await physics_frame
		game._physics_process(1.0 / 60)
	check(game.player.rotation.y == hull and game.player.position == position, "Aim turret never turns or moves the hull")
	check(game.player.model.turret_yaw != turret and game.player.model.rounds == 25, "Aim traverses without firing")
	game._stop_and_edit()
	var remaining: float = game.time_left
	var frozen: float = game.sim_time
	for i in range(60): game._physics_process(1.0 / 60)
	check(game.sim_time == frozen and game.time_left == remaining, "Stop/edit freezes the budget")
	check(game._can_edit_orders() and game.fields.range.editable, "Stopped player turn accepts edits")
	game._cancel_action(0)
	game._append_action("wait", game.player.position, 0.5)
	game._execute()
	check(not game.playback.paused and game.time_left == remaining, "Resume preserves the remaining budget")
	check(await Harness.finish_turn(game), "Edited action sequence finishes")
	check(absf(game.sim_time - 10) < 0.001 and game.turn == 2, "Editing cannot reset or extend a five-second turn")

	game = await new_game()
	position = game.player.position
	game.next_action_limit.value = 0.5
	game._queue_move(position + Vector3(14, 0, 0))
	game.next_action_limit.value = 0
	game._append_action("fire", position + Vector3(100, 15, 0))
	game._append_action("reload", position)
	var estimates = game.action_queue.estimates(game.player)
	check(absf(estimates[0].seconds - 0.5) < 0.001 and estimates[1].seconds >= 0.6, "Limited move and shot have separate time costs")
	check(estimates[2].end > 5, "Preview includes the reload and shows carryover beyond the turn")
	await capture("tank_action_queue")
	game._execute()
	for i in range(400):
		await physics_frame
		game._physics_process(0.05)
		if game.player.model.rounds < 25: break
	check(game.player.model.rounds == 24, "Move then fire executes in one player turn")
	check(absf(game.player.position.x - position.x - 3.5) < 0.15, "Time-limited movement stops before the next action")
	check(game.player.speed == 0, "Fire action holds the hull still")
	check(game.sim_time < 2, "Short actions consume only their own part of the five-second budget")
	game._stop_and_edit()
	var rounds: int = game.player.model.rounds
	var shell_count: int = game.shells.size()
	remaining = game.time_left
	game._clear_orders()
	check(game.player.model.rounds == rounds and game.shells.size() == shell_count, "Clearing cannot undo a shot or erase shells in flight")
	game._append_action("reload", game.player.position)
	game._execute()
	check(game.time_left == remaining, "Clearing orders does not refund spent time")
	check(await Harness.finish_turn(game), "Move, fire, and reload sequence finishes")
	check(game.action_queue.actions.size() == 1 and game.action_queue.actions[0].kind == "reload", "Unfinished reload action remains queued next turn")
	check(game.player.model.reload > 0 and game.player.model.reload < 6.5, "Reload advances during the unused player time")

	game = await new_game()
	var gun_bearing: float = game.player.rotation.y + game.player.model.turret_yaw
	game._append_action("hull", game.player.position + Vector3(0, 0, -75), 0.5)
	game._execute()
	for i in range(60):
		await physics_frame
		game._physics_process(1.0 / 60)
	check(absf(angle_difference(gun_bearing, game.player.rotation.y + game.player.model.turret_yaw)) < 0.001, "Hull turning preserves the separate gun bearing")
	check(absf(game.player.rotation.y + PI / 2) > 0.1, "Turn hull actually pivots the vehicle")

	game = await new_game()
	game._queue_fire(game.enemy.position)
	game._execute()
	for i in range(500):
		await physics_frame
		game._physics_process(0.1)
		if not game.playback.active.is_empty(): break
	check(not game.playback.active.is_empty(), "Armor hit opens the damage presentation")
	if not game.playback.active.is_empty():
		frozen = game.sim_time
		var report: Dictionary = game.playback.active.damage.duplicate(true)
		game._physics_process(30)
		check(not game.playback.active.is_empty() and game.sim_time == frozen, "Finished impact stays open indefinitely without spending turn time")
		check(game.impact_effects.text == Damage.text(report), "Impact explains the recorded component and crew changes")
		check(game.impact_systems.text.contains("MOVEMENT") and game.impact_systems.text.contains("MAIN GUN"), "Impact lists practical system capabilities")
		await capture("tank_damage_assessment")
		game.playback.restart_replay()
		game._continue_impact()
		check(not game.playback.active.is_empty() and game.playback.replay_time == game.Playback.IMPACT_DURATION, "Early Continue reveals the report without dismissing it")
		game._continue_impact()
		check(game.playback.active.is_empty(), "Second Continue acknowledges the report")
		check(game.records[0].damage == report, "Presentation never mutates the recorded damage")

	var model = Armor.new()
	var before = Damage.snapshot(model)
	for module in model.modules:
		if module.name == "Engine": module.state = "Disabled"
	var report = Damage.summarize(before, Damage.snapshot(model))
	check(Damage.text(report).contains("cannot move") and report.changes.size() == 1, "Engine damage explains loss of movement")
	before = Damage.snapshot(model)
	report = Damage.summarize(before, Damage.snapshot(model))
	check(report.changes.is_empty() and Damage.text(report).contains("No new"), "Previously disabled systems are not reported as new damage")
	var queued = game.Actions.new()
	game.player.model.rounds = 21
	game.player.model.rack_counts["Ready rack"] = 2
	game.player.model.reload = 0
	for kind in ["fire", "fire", "reload"]: queued.append(kind, game.player.position + Vector3(75, 1.4, 0), 0)
	var ammo_estimates = queued.estimates(game.player)
	check(absf(ammo_estimates[1].seconds - 6.5) < 0.001 and absf(ammo_estimates[2].seconds - 10.8) < 0.001, "Future reload estimates account for emptying the ready rack")
	print("Action and damage checks completed; failures: ", failures)
	quit(failures)
