extends "res://scripts/wego/Engagement.gd"
## Deterministic exercise: opening -> warehouse -> concealed halt/fire -> ridge.
var sandbox_fired: bool = false

func _ready() -> void:
	super._ready()
	player.position = Vector3.ZERO
	player.rotation.y = 0.0
	player.gunner_sight.sync_with_vehicle()
	enemy.position = Vector3(-140, 0, -1500)
	enemy.rotation.y = -PI * 0.5
	cam_target = player.position
	player.obs_commander.world_azimuth = 0.0
	player.obs_gunner.world_azimuth = 0.0
	player.obs_driver.world_azimuth = 0.0
	if tutorial != null: tutorial.hide()
	_log("RECON SANDBOX: Armor reported beyond the warehouse. Observe the openings and ridge.")

func _plan_ai() -> void:
	# Scenario movement is scripted truth. Aiming still uses the AI's knowledge.
	var plan = {"engine": true, "move": 0.0, "fire": false, "bearing": 180.0, "range": 1500.0}
	if enemy_track.has_contact():
		plan.bearing = enemy_track.estimated_bearing_deg
		plan.range = enemy_track.estimated_range
	enemy.commit(plan)
	enemy.obs_commander.set_observe_sector(PI, 45.0)

func _simulation_step(delta: float) -> void:
	# 0-20s crossing; 20-32s stopped behind warehouse; then right to ridge.
	var travel_time: float = sim_time if sim_time < 20.0 else maxf(20.0, sim_time - 12.0)
	enemy.position = Vector3(minf(-140.0 + travel_time * 7.0, 240.0), 0, -1500)
	enemy.speed = 0.0 if (sim_time >= 20.0 and sim_time < 32.0) or enemy.position.x >= 240.0 else 7.0
	if sim_time >= 25.0 and not sandbox_fired:
		enemy.shot_pending = true
		sandbox_fired = true
	super._simulation_step(delta)
	# Vehicle stepping owns physical gunnery; retain the scripted movement clue.
	enemy.speed = 0.0 if (sim_time >= 20.0 and sim_time < 32.0) or enemy.position.x >= 240.0 else 7.0
