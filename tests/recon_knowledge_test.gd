extends SceneTree
const Vehicle = preload("res://scripts/wego/TacticalVehicle.gd")
const Sensor = preload("res://scripts/wego/SensorModel.gd")
const Track = preload("res://scripts/wego/ContactTrack.gd")
const Visibility = preload("res://scripts/wego/CrewVisibility.gd")
const Knowledge = preload("res://scripts/wego/BattlefieldKnowledge.gd")
var failures: int = 0
var assertions: int = 0
var sensor = Sensor.new()
var observer
var target
var track
var now: float = 0.0
var fixture: Node3D

func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", message)

func _initialize() -> void:
	call_deferred("run")

func reset_pair(distance: float = 1500.0) -> void:
	if observer != null: observer.free()
	if target != null: target.free()
	observer = Vehicle.new()
	target = Vehicle.new()
	target.name = "Target"
	target.position = Vector3(0, 0, -distance)
	target.engine_on = false
	track = Track.new()
	observer.track = track
	now = 0.0
	sensor.rng.seed = 42017

func tick(seconds: float, world: World3D = null) -> Dictionary:
	var result: Dictionary = {}
	for i in range(ceili(seconds / 0.25)):
		now += 0.25
		result = sensor.evaluate(observer, target, world, now, false, null, 0.25)
		track.sensing_update(result, 0.25, now)
	return result

func run() -> void:
	reset_pair()
	check(not track.has_contact() and track.cues.is_empty(), "A: no contact or cue at spawn")
	observer.speed = 5.0
	tick(20.0)
	check(not track.has_contact() and track.cues.is_empty(), "B/L: driving past distant stationary target produces no automatic marker")
	target.speed = 5.0
	tick(3.0)
	check(not track.cues.is_empty() and not track.has_contact() and not track.has_silhouette, "C: passive movement gives only bearing cue")
	observer.speed = 0.0
	observer.obs_commander.set_observe_sector(0.0, 45.0)
	tick(2.0)
	check(track.contact_stage == Track.Stage.SUSPECTED, "D: deliberate attention starts with suspected vehicle")
	check(track.position_uncertainty > 100.0 and track.estimated_position.distance_to(target.position) > 2.0, "Q: early visual position is noisy and broad")
	check(not track.has_silhouette and not track.has_speed_estimate, "Q: early report does not contain silhouette or speed")
	tick(18.0)
	check(track.contact_stage == Track.Stage.TRACKED and track.has_speed_estimate and track.has_orientation, "D: repeated observation develops independent motion and classification")
	var progress: float = observer.obs_commander.detection_progress[target.name]
	observer.obs_commander.set_observe_sector(PI, 18.0)
	var frozen: Vector3 = track.silhouette_position
	var believed: Vector3 = track.estimated_position
	target.speed = 0.0
	target.position += Vector3(100, 0, 0)
	tick(8.0)
	check(not track.has_visual_los and observer.obs_commander.detection_progress[target.name] < progress, "E/F/R: wrong sector loses LOS and decays evidence")
	check(track.silhouette_position == frozen, "S: ghost remains fixed after hidden maneuver")
	check(track.estimated_position.distance_to(believed) > 1.0, "T: prediction continues when truth secretly stops")
	observer.gunner_sight.slew_to_contact(track)
	check(is_equal_approx(observer.gunner_sight.commanded_yaw, -deg_to_rad(track.estimated_bearing_deg)), "P: handoff uses estimated bearing")
	var aim_yaw: float = observer.gunner_sight.commanded_yaw
	target.position += Vector3(700, 0, 0)
	observer.gunner_sight.slew_to_contact(track)
	check(is_equal_approx(aim_yaw, observer.gunner_sight.commanded_yaw), "X: changing hidden truth cannot change aim")
	reset_pair(80.0)
	target.speed = 4.0
	tick(1.0)
	check(track.has_confirmed_tank, "K: obvious 80m crossing is rapidly recognized")
	reset_pair(1500.0)
	observer.obs_commander.set_observe_sector(PI, 45)
	var acoustic = sensor.evaluate(observer, target, null, 1.0, true)
	track.sensing_update(acoustic, 0.25, 1.0)
	check(acoustic.cue.category == "GUN_REPORT" and acoustic.cue.bearing_uncertainty <= 8.0, "N: gun report gives strong bearing")
	check(not track.has_contact() and not track.has_visual_los and not track.has_silhouette, "M: sound alone never grants position, LOS or silhouette")
	for i in range(10): sensor.evaluate(observer, target, null, 2.0 + i, true)
	check(observer.history.size() == 1, "O: same-location bearings do not triangulate")
	# Deterministic geometric crossing: north from x=0 and northwest from x=1000.
	observer.history = [{"position": Vector2.ZERO, "direction": Vector2(0, -1), "time": 0.0}]
	observer.position = Vector3(1000, 0, 0)
	var cue = preload("res://scripts/wego/ReconCue.gd").new()
	cue.timestamp = 1.0
	cue.observer_position = observer.position
	cue.bearing_deg = 315.0
	cue.bearing_uncertainty = 8.0
	var fix = sensor.cross_bearing(observer, cue)
	check(fix != null and fix.target_position.distance_to(Vector3(0, 0, -1000)) < 0.1 and fix.position_uncertainty_m > 40.0, "O: separated bearings produce uncertain geometric fix")
	# Actual physics geometry, not a mocked LOS result.
	reset_pair(100.0)
	fixture = Node3D.new()
	root.add_child(fixture)
	fixture.add_child(observer)
	fixture.add_child(target)
	observer.obs_commander.set_observe_sector(0, 18)
	var wall = StaticBody3D.new()
	wall.position = Vector3(0, 2.5, -50)
	var shape = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(30, 5, 4)
	shape.shape = box
	wall.add_child(shape)
	fixture.add_child(wall)
	await physics_frame
	await physics_frame
	var blocked = tick(3.0, fixture.get_world_3d())
	check(not blocked.has_los and not track.has_visual_los, "G: physical warehouse blocks all vehicle samples")
	var camera = Camera3D.new()
	fixture.add_child(camera)
	camera.position = Vector3(0, 100, -80)
	var orbited = tick(1.0, fixture.get_world_3d())
	check(not orbited.has_los, "H: camera above/behind warehouse cannot reveal target")
	wall.position.y = -0.35 # top at 2.15m: lower samples blocked, turret rays clear
	await physics_frame
	await physics_frame
	var partial = Visibility.sample_vehicle(observer, observer.obs_commander, target, fixture.get_world_3d())
	check(partial.fraction > 0.0 and partial.fraction < 1.0, "I: hull-down physics produces fractional exposure")
	observer.obs_commander.evidence.clear()
	observer.obs_commander.detection_progress.clear()
	tick(1.0, fixture.get_world_3d())
	var partial_detail: float = observer.obs_commander.evidence[target.name].classification
	wall.position.x = 200
	await physics_frame
	await physics_frame
	observer.obs_commander.evidence.clear()
	tick(1.0, fixture.get_world_3d())
	check(observer.obs_commander.evidence[target.name].classification > partial_detail, "J: full exposure refines faster than partial")
	var knowledge = Knowledge.new()
	var point = Vector3(20, 0.3, -100)
	observer.obs_commander.set_observe_sector(0, 90)
	knowledge.update([observer], fixture.get_world_3d(), 1.0)
	check(knowledge.state_at(point) == Knowledge.State.CURRENT, "U: observed ground becomes current")
	for station in observer.observers.values(): station.world_azimuth = PI
	knowledge.update([observer], fixture.get_world_3d(), 3.0)
	check(knowledge.state_at(point) == Knowledge.State.REMEMBERED, "U: ground remains remembered after FOV loss")
	check(knowledge.state_at(Vector3(3500, 0, 3500)) == Knowledge.State.UNKNOWN, "V: unseen region remains unknown")
	knowledge.remember_dynamic("truck", {"position": Vector3.ZERO}, true)
	var memory = knowledge.remember_dynamic("truck", {"position": Vector3.ONE * 500}, false)
	check(memory.position == Vector3.ZERO, "U: hidden dynamic state never updates remembered snapshot")
	observer.obs_driver.world_azimuth = 0.0
	check(knowledge.is_live(Vector3(20, 1.5, -100), [observer], fixture.get_world_3d()), "W: driver visibility contributes independently of commander")
	observer.obs_commander.set_observe_sector(1.0, 18)
	observer.step(0.01)
	check(is_equal_approx(observer.obs_commander.world_azimuth, 1.0), "Assigned commander sector survives vehicle update")
	fixture.queue_free()
	observer = null
	target = null
	await process_frame
	# Real engagement starting state and UI boundary.
	var game = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	await physics_frame
	game._process(0.0)
	check(game.display_contact.is_empty() and not game.enemy.visible and not game.ghost_tank.visible, "A/V: real scene starts without enemy model, label, or ghost")
	game._toggle_commander_view()
	check(game.view_mode == "COMMANDER" and not game.battlefield_overlay.visible, "Commander binocular view has no tactical outlines")
	game._toggle_commander_view()
	game.queue_free()
	await process_frame
	print("RECON: %d assertions, %d failures" % [assertions, failures])
	quit(failures)

