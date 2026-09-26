extends RefCounted
## Concurrent action timeline: coordinates Driver, Gunner, Loader, and Commander
## across the 8-second WEGO pulse, replacing the sequential single-file queue.

const ConcurrentScheduler = preload("res://scripts/wego/ConcurrentScheduler.gd")
const VehicleConfig = preload("res://scripts/wego/VehicleConfig.gd")

const TITLES = {
	"move": "Move",
	"hull": "Turn hull",
	"aim": "Aim turret",
	"fire": "Aim & fire",
	"scan": "Scan",
	"reload": "Reload",
	"wait": "Wait"
}

var actions: Array[Dictionary] = []
var running: bool = false
var scheduler: ConcurrentScheduler = ConcurrentScheduler.new()
var pulse_time: float = 0.0

func append(kind: String, point: Vector3, limit: float = -1.0, creep: bool = false) -> void:
	var crew_ch = ConcurrentScheduler.get_crew_for_kind(kind)
	var sys_ch = ConcurrentScheduler.get_subsystem_for_kind(kind)
	actions.append({
		"kind": kind,
		"point": point,
		"limit": limit,
		"spent": 0.0,
		"creep": creep,
		"crew": crew_ch,
		"system": sys_ch,
		"active": false,
		"completed": false
	})
	scheduler.actions = actions

static func reload_seconds(tank) -> float:
	var penalty: float = 1.0 if tank.model.occupied("Loader") else 3.5
	return tank.model.reload * penalty

static func hold_plan(tank) -> Dictionary:
	return {
		"move": 0.0,
		"pivot": 0.0,
		"bearing": fposmod(rad_to_deg(-(tank.rotation.y + tank.model.turret_yaw)), 360),
		"range": 75.0,
		"height": 1.4,
		"fire": false,
		"engine": tank.engine_on,
		"observe": true,
		"light": false,
		"extinguish": tank.orders.get("extinguish", false)
	}

# Starts concurrent execution by compiling all currently ready actions into the tank plan
func start(tank) -> void:
	if actions.is_empty() or running: return
	scheduler.actions = actions
	pulse_time = 0.0
	running = true
	_apply_active_orders(tank)

func _apply_active_orders(tank) -> void:
	var plan = hold_plan(tank)
	
	# Determine which actions can run concurrently right now
	var driver_busy = false
	var gunner_busy = false
	var loader_busy = false
	var commander_busy = false
	
	for action in actions:
		if action.completed: continue
		
		# Driver channel: Move or Turn Hull
		if action.crew == "DRIVER" and not driver_busy:
			driver_busy = true
			action.active = true
			if action.kind == "move":
				plan.destination = action.point
				plan.engine = true
				plan.creep = action.creep
			elif action.kind == "hull":
				var offset: Vector3 = action.point - tank.position
				plan.pivot = rad_to_deg(angle_difference(tank.rotation.y, -atan2(offset.x, -offset.z)))
				plan.engine = true
				
		# Gunner channel: Aim or Fire
		elif action.crew == "GUNNER" and not gunner_busy:
			if action.kind == "fire" and driver_busy:
				plan.aim_point = action.point
				plan.fire = false
			else:
				gunner_busy = true
				action.active = true
				plan.aim_point = action.point
				plan.fire = (action.kind == "fire")
			
		# Loader channel: Reload
		elif action.crew == "LOADER" and not loader_busy:
			loader_busy = true
			action.active = true
			plan.extinguish = false
			
		# Commander channel: Scan
		elif action.crew == "COMMANDER" and not commander_busy:
			commander_busy = true
			action.active = true
			plan.light = (action.kind == "scan")
			if action.kind == "scan":
				plan.aim_point = action.point
				plan.engine = false # Idle engine for quiet listening/scan if specified
				
		# Generic / Wait
		elif action.kind == "wait" and not driver_busy and not gunner_busy:
			action.active = true
			break
			
	tank.commit(plan)

# Advances all concurrent timelines simultaneously
func advance(tank, delta: float) -> String:
	if actions.is_empty() or not running: return ""
	pulse_time += delta
	
	var completed_notices: Array[String] = []
	var need_replan: bool = false
	
	for i in range(actions.size() - 1, -1, -1):
		var action = actions[i]
		if not action.active or action.completed: continue
		action.spent += delta
		
		var done: bool = false
		match action.kind:
			"move":
				done = tank.position.distance_to(action.point) < 0.15
			"hull":
				done = absf(tank.remaining_pivot) < 0.005
			"aim":
				var aimed = absf(angle_difference(tank.rotation.y + tank.model.turret_yaw, tank.gun_goal_yaw())) < 0.02
				done = aimed
			"fire":
				done = not tank.shot_pending
			"scan":
				var aimed = absf(angle_difference(tank.rotation.y + tank.model.turret_yaw, tank.gun_goal_yaw())) < 0.02
				done = aimed and action.spent >= 2.0
			"reload":
				done = tank.model.reload <= 0.0
			"wait":
				done = action.spent >= (action.limit if action.limit > 0.0 else 1.0)
				
		var capped: bool = action.limit > 0.0 and action.spent + 0.00001 >= action.limit
		
		if done or capped:
			action.completed = true
			action.active = false
			need_replan = true
			var note = TITLES[action.kind] + (" complete." if done else " stopped at time limit.")
			completed_notices.append(note)
			actions.remove_at(i)
			
	if need_replan:
		if actions.is_empty():
			running = false
			tank.commit(hold_plan(tank))
		else:
			_apply_active_orders(tank)
			
	return "\n".join(completed_notices)

# Generates concurrent schedule estimates
func estimates(tank) -> Array[Dictionary]:
	scheduler.actions = actions
	var scheduled = scheduler.schedule_timeline(tank)
	var result: Array[Dictionary] = []
	for item in scheduled:
		result.append({
			"seconds": item.duration,
			"start": item.start_time,
			"end": item.end_time,
			"reason": item.reason,
			"title": TITLES[item.kind],
			"crew": item.crew,
			"system": item.system
		})
	return result

func render_timeline(tank) -> String:
	scheduler.actions = actions
	return scheduler.render_ascii_timeline(tank)
