extends RefCounted
## Sequential orders and their estimates use the same rates as TacticalVehicle.
const TITLES = {"move": "Move", "hull": "Turn hull", "aim": "Aim turret", "fire": "Aim & fire", "scan": "Scan", "reload": "Reload", "wait": "Wait"}
var actions: Array[Dictionary] = []
var running = false

func append(kind: String, point: Vector3, limit: float, creep: bool = false) -> void:
	actions.append({"kind": kind, "point": point, "limit": limit, "spent": 0.0, "creep": creep})

static func reload_seconds(tank) -> float:
	return tank.model.reload * (1.0 if tank.model.occupied("Loader") else 3.8)

static func hold_plan(tank) -> Dictionary:
	return {"move": 0.0, "pivot": 0.0, "bearing": fposmod(rad_to_deg(-(tank.rotation.y + tank.model.turret_yaw)), 360), "range": 75.0, "height": 1.4, "fire": false, "engine": tank.engine_on, "observe": true, "light": false, "extinguish": tank.orders.get("extinguish", false)}

func start(tank) -> void:
	if actions.is_empty() or running: return
	var action = actions[0]
	var plan = hold_plan(tank)
	match action.kind:
		"move":
			plan.destination = action.point
			plan.engine = true
			plan.creep = action.creep
		"hull":
			var offset: Vector3 = action.point - tank.position
			plan.pivot = rad_to_deg(angle_difference(tank.rotation.y, -atan2(offset.x, -offset.z)))
			plan.engine = true
		"aim", "fire", "scan":
			plan.aim_point = action.point
			plan.fire = action.kind == "fire"
			plan.light = action.kind == "scan"
			if action.kind == "scan": plan.engine = false
		"reload": plan.extinguish = false
	tank.commit(plan)
	running = true

func advance(tank, delta: float) -> String:
	if actions.is_empty() or not running: return ""
	var action = actions[0]
	action.spent += delta
	var aimed = absf(angle_difference(tank.rotation.y + tank.model.turret_yaw, tank.gun_goal_yaw())) < 0.02
	var done = false
	match action.kind:
		"move": done = tank.position.distance_to(action.point) < 0.1
		"hull": done = absf(tank.remaining_pivot) < 0.001
		"aim": done = aimed
		"fire": done = not tank.shot_pending
		"scan": done = aimed and action.spent >= 2.0
		"reload": done = tank.model.reload <= 0
		"wait": done = action.spent >= (action.limit if action.limit > 0 else 1.0)
	var capped = action.limit > 0 and action.spent + 0.00001 >= action.limit
	if not done and not capped: return ""
	actions.pop_front()
	running = false
	tank.commit(hold_plan(tank))
	return TITLES[action.kind] + (" complete." if done else " stopped at its time limit.")

func estimates(tank) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var position: Vector3 = tank.position
	var hull: float = tank.rotation.y
	var turret: float = hull + tank.model.turret_yaw
	var reload_left = reload_seconds(tank)
	var ready_rounds: int = tank.model.rack_counts["Ready rack"]
	var rounds_left: int = tank.model.rounds
	var reload_paused: bool = tank.orders.get("extinguish", false)
	var total = 0.0
	for i in range(actions.size()):
		var action = actions[i]
		var offset: Vector3 = action.point - position
		var goal = -atan2(offset.x, -offset.z)
		var duration = 0.0
		var reason = ""
		var destination = position
		var next_hull = hull
		var next_turret = turret
		match action.kind:
			"move":
				var turning = absf(angle_difference(hull, goal)) / 0.6
				var driving = Vector2(offset.x, offset.z).length() / (2.0 if action.creep else 7.0)
				duration = turning + driving
				next_hull = goal
				destination = action.point
				if not tank.model.can_move(): reason = "Movement unavailable"
			"hull":
				duration = absf(angle_difference(hull, goal)) / 0.3
				next_hull = goal
				if not tank.model.can_move(): reason = "Movement unavailable"
			"aim", "fire", "scan":
				duration = absf(angle_difference(turret, goal)) / 0.5
				next_turret = goal
				if action.kind == "fire":
					duration = maxf(duration, maxf(reload_left, maxf(0, 0.6 - (tank.elapsed if running and i == 0 else 0.0))))
					if not tank.model.can_fire() or rounds_left <= 0: reason = "Gun or ammunition unavailable"
					elif reload_paused and reload_left > 0: reason = "Reload paused: loader fighting fire"
				elif action.kind == "scan": duration = maxf(duration, maxf(0, 2.0 - action.spent))
			"reload":
				reload_paused = false
				duration = reload_left
				if (not tank.model.can_fire() or rounds_left <= 0) and reload_left > 0: reason = "Reload unavailable"
			"wait": duration = maxf(0, (action.limit if action.limit > 0 else 1.0) - action.spent)
		var full_duration = maxf(duration, 1.0 / 60.0)
		var capped = action.limit > 0
		duration = minf(full_duration, maxf(0, action.limit - action.spent)) if capped else full_duration
		if not reason.is_empty(): duration = maxf(0, action.limit - action.spent) if capped else INF
		# Predict where a deliberately shortened move/turn will leave the tank.
		if action.kind == "move":
			var turning = absf(angle_difference(hull, goal)) / 0.6
			next_hull = rotate_toward(hull, goal, duration * 0.6)
			var travel = maxf(0, duration - turning) * (2.0 if action.creep else 7.0)
			destination = position.move_toward(action.point, travel)
		elif action.kind == "hull": next_hull = rotate_toward(hull, goal, duration * 0.3)
		elif action.kind in ["aim", "fire", "scan"]: next_turret = rotate_toward(turret, goal, duration * 0.5)
		result.append({"seconds": duration, "start": total, "end": total + duration, "reason": reason, "title": TITLES[action.kind]})
		total += duration
		position = destination
		hull = next_hull
		turret = next_turret
		if not reload_paused: reload_left = maxf(0, reload_left - duration)
		if action.kind == "fire" and reason.is_empty() and duration + 0.0001 >= full_duration:
			ready_rounds = maxi(0, ready_rounds - 1)
			rounds_left = maxi(0, rounds_left - 1)
			reload_left = (6.5 if ready_rounds > 0 else 10.8) * (1.0 if tank.model.occupied("Loader") else 3.8)
	return result
