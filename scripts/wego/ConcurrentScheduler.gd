extends RefCounted
class_name ConcurrentScheduler
## Schedules concurrent crew and subsystem timelines across the 8-second WEGO pulse.
## Replaces single-file sequential queue with independent resource channels:
## - Crew channels: DRIVER, GUNNER, LOADER, COMMANDER
## - Subsystem channels: HULL_POWERTRAIN, TURRET_DRIVE, MAIN_GUN, OPTICS_FCS
##
## Actions that require distinct crew and subsystems operate simultaneously,
## while conflicting actions serialize on their respective channels.

const VehicleConfig = preload("res://scripts/wego/VehicleConfig.gd")

const CHANNELS = {
	"DRIVER": "Driver",
	"GUNNER": "Gunner",
	"LOADER": "Loader",
	"COMMANDER": "Commander",
	"HULL_POWERTRAIN": "Hull / Powertrain",
	"TURRET_DRIVE": "Turret Drive",
	"MAIN_GUN": "Main Gun",
	"OPTICS_FCS": "Optics / Fire Control"
}

var actions: Array[Dictionary] = []
var running: bool = false
var pulse_time: float = 0.0

# Action structure:
# {
#   "id": int,
#   "kind": "move" | "hull" | "aim" | "fire" | "scan" | "reload" | "wait",
#   "point": Vector3,
#   "limit": float,
#   "creep": bool,
#   "spent": float,
#   "crew": "DRIVER" | "GUNNER" | "LOADER" | "COMMANDER" | "",
#   "system": "HULL_POWERTRAIN" | "TURRET_DRIVE" | "MAIN_GUN" | "OPTICS_FCS" | "",
#   "start_time": float,
#   "duration": float,
#   "end_time": float,
#   "completed": bool,
#   "reason": String
# }

func clear() -> void:
	actions.clear()
	running = false
	pulse_time = 0.0

func append_action(kind: String, point: Vector3, limit: float = -1.0, creep: bool = false) -> Dictionary:
	var crew_req = get_crew_for_kind(kind)
	var sys_req = get_subsystem_for_kind(kind)
	var action = {
		"id": actions.size() + 1,
		"kind": kind,
		"point": point,
		"limit": limit,
		"creep": creep,
		"spent": 0.0,
		"crew": crew_req,
		"system": sys_req,
		"start_time": 0.0,
		"duration": 0.0,
		"end_time": 0.0,
		"completed": false,
		"reason": ""
	}
	actions.append(action)
	return action

static func get_crew_for_kind(kind: String) -> String:
	match kind:
		"move", "hull": return "DRIVER"
		"aim", "fire": return "GUNNER"
		"reload": return "LOADER"
		"scan": return "COMMANDER"
		"wait": return ""
	return ""

static func get_subsystem_for_kind(kind: String) -> String:
	match kind:
		"move", "hull": return "HULL_POWERTRAIN"
		"aim": return "TURRET_DRIVE"
		"fire": return "MAIN_GUN"
		"reload": return "MAIN_GUN"
		"scan": return "OPTICS_FCS"
		"wait": return ""
	return ""

# Calculates whether actions conflict with each other based on crew and subsystem allocation
static func actions_conflict(a: Dictionary, b: Dictionary) -> bool:
	if a.kind == "wait" or b.kind == "wait":
		return false
	if not a.crew.is_empty() and a.crew == b.crew:
		return true
	if not a.system.is_empty() and a.system == b.system:
		return true
	return false

# Computes concurrent schedule for all queued actions on an 8-second timeline
func schedule_timeline(tank) -> Array[Dictionary]:
	var config: VehicleConfig = tank.config if ("config" in tank and tank.config != null) else VehicleConfig.create_mastodon()
	
	# Resource channel release times
	var channel_free_time: Dictionary = {
		"DRIVER": 0.0,
		"GUNNER": 0.0,
		"LOADER": 0.0,
		"COMMANDER": 0.0,
		"HULL_POWERTRAIN": 0.0,
		"TURRET_DRIVE": 0.0,
		"MAIN_GUN": 0.0,
		"OPTICS_FCS": 0.0
	}
	
	var scheduled: Array[Dictionary] = []
	var sim_pos: Vector3 = tank.position
	var sim_hull_yaw: float = tank.rotation.y
	var sim_turret_yaw: float = sim_hull_yaw + tank.model.turret_yaw
	var sim_ready_rounds: int = tank.model.rack_counts.get("Ready rack", 0)
	var sim_rounds: int = tank.model.rounds
	var reload_left: float = tank.model.reload * (1.0 if tank.model.occupied("Loader") else 3.8)
	
	for action in actions:
		var item = action.duplicate(true)
		var earliest_start: float = 0.0
		
		# Crew substitution and availability checks
		var crew_pen: float = 1.0
		var can_execute: bool = true
		var blocked_reason: String = ""
		
		if item.crew == "DRIVER":
			if not tank.model.occupied("Driver"):
				can_execute = false
				blocked_reason = "Driver station unoccupied"
			elif not tank.model.can_move():
				can_execute = false
				blocked_reason = "Powertrain / engine disabled"
			else:
				crew_pen = get_crew_penalty(tank, "Driver")
				
		elif item.crew == "GUNNER":
			if not tank.model.occupied("Gunner"):
				# Gunner casualty: check if commander can override
				if config.commander_weapon_override and tank.model.occupied("Commander"):
					crew_pen = config.substitution_penalties.get("Gunner", 1.6)
					# Commander is substituting, so commander channel is also occupied!
					earliest_start = maxf(earliest_start, channel_free_time["COMMANDER"])
				else:
					can_execute = false
					blocked_reason = "Gunner lost, no override"
			else:
				crew_pen = get_crew_penalty(tank, "Gunner")
				
		elif item.crew == "LOADER":
			if not tank.model.occupied("Loader"):
				# Loader casualty: other turret crewman must load
				crew_pen = config.substitution_penalties.get("Loader", 3.5)
				if not tank.model.occupied("Commander") and not tank.model.occupied("Gunner"):
					can_execute = false
					blocked_reason = "No turret crew to load gun"
			else:
				crew_pen = get_crew_penalty(tank, "Loader")
				
		elif item.crew == "COMMANDER":
			if not tank.model.occupied("Commander"):
				can_execute = false
				blocked_reason = "Commander lost"
			else:
				crew_pen = get_crew_penalty(tank, "Commander")

		# Calculate earliest start based on crew & subsystem availability
		if not item.crew.is_empty():
			earliest_start = maxf(earliest_start, channel_free_time.get(item.crew, 0.0))
		if not item.system.is_empty():
			earliest_start = maxf(earliest_start, channel_free_time.get(item.system, 0.0))
			
		# Compute realistic physical duration
		var base_duration: float = 0.0
		match item.kind:
			"move":
				var offset: Vector3 = item.point - sim_pos
				var dist: float = Vector2(offset.x, offset.z).length()
				var goal_yaw = -atan2(offset.x, -offset.z)
				var turn_time = absf(angle_difference(sim_hull_yaw, goal_yaw)) / 0.6
				var drive_time = dist / (2.0 if item.creep else 7.0)
				base_duration = (turn_time + drive_time) * crew_pen
				sim_pos = item.point
				sim_hull_yaw = goal_yaw
			"hull":
				var offset: Vector3 = item.point - sim_pos
				var goal_yaw = -atan2(offset.x, -offset.z)
				base_duration = (absf(angle_difference(sim_hull_yaw, goal_yaw)) / 0.3) * crew_pen
				sim_hull_yaw = goal_yaw
			"aim":
				var offset: Vector3 = item.point - sim_pos
				var goal_yaw = -atan2(offset.x, -offset.z)
				var traverse_rate = 0.5
				base_duration = (absf(angle_difference(sim_turret_yaw, goal_yaw)) / maxf(0.1, traverse_rate)) * crew_pen
				sim_turret_yaw = goal_yaw
			"fire":
				var offset: Vector3 = item.point - sim_pos
				var goal_yaw = -atan2(offset.x, -offset.z)
				var traverse_rate = 0.5
				var aim_time = (absf(angle_difference(sim_turret_yaw, goal_yaw)) / maxf(0.1, traverse_rate)) * crew_pen
				base_duration = maxf(0.6, maxf(aim_time, reload_left))
				sim_turret_yaw = goal_yaw
				earliest_start = maxf(earliest_start, channel_free_time["DRIVER"])
				if sim_rounds <= 0:
					blocked_reason = "Out of ammunition"
				else:
					sim_ready_rounds = maxi(0, sim_ready_rounds - 1)
					sim_rounds = maxi(0, sim_rounds - 1)
					reload_left = (6.5 if sim_ready_rounds > 0 else 10.8) * (1.0 if tank.model.occupied("Loader") else 3.8)
			"reload":
				base_duration = reload_left if reload_left > 0 else (6.5 if sim_ready_rounds > 0 else 10.8) * (1.0 if tank.model.occupied("Loader") else 3.8)
				reload_left = 0.0
			"scan":
				var offset: Vector3 = item.point - sim_pos
				var goal_yaw = -atan2(offset.x, -offset.z)
				base_duration = 2.0 * crew_pen
				sim_turret_yaw = goal_yaw
			"wait":
				base_duration = item.limit if item.limit > 0.0 else 1.0

		if not can_execute:
			item.duration = 0.0
			item.start_time = earliest_start
			item.end_time = earliest_start
			item.reason = blocked_reason
		else:
			var dur = base_duration
			if item.limit > 0.0:
				dur = minf(dur, item.limit)
			item.duration = dur
			item.start_time = earliest_start
			item.end_time = earliest_start + dur
			item.reason = ""
			
			# Advance channel release times
			if not item.crew.is_empty():
				channel_free_time[item.crew] = item.end_time
			if not item.system.is_empty():
				channel_free_time[item.system] = item.end_time
				
		scheduled.append(item)
		
	return scheduled

# Helper to calculate crew member state penalty (Wounded / Seriously Wounded)
static func get_crew_penalty(tank, crew_name: String) -> float:
	for c in tank.model.crew:
		if c.name == crew_name:
			match c.state:
				"Wounded": return 1.35
				"Seriously wounded": return 2.0
				"Incapacitated", "Dead": return 999.0
				_: return 1.0
	return 1.0

# Returns an ASCII visual representation of the concurrent crew channels across 8 seconds
func render_ascii_timeline(tank) -> String:
	var sched = schedule_timeline(tank)
	var width: int = 36
	var max_pulse: float = 8.0
	
	var tracks: Dictionary = {
		"DRIVER": " " .repeat(width),
		"GUNNER": " " .repeat(width),
		"LOADER": " " .repeat(width),
		"COMMANDER": " " .repeat(width)
	}
	
	for item in sched:
		var c = item.crew
		if not tracks.has(c): continue
		var s_idx = clampi(int((item.start_time / max_pulse) * width), 0, width - 1)
		var e_idx = clampi(int((item.end_time / max_pulse) * width), s_idx + 1, width)
		var seg_len = maxi(1, e_idx - s_idx)
		var tag = item.kind.to_upper()
		var fill = tag.substr(0, mini(tag.length(), seg_len))
		while fill.length() < seg_len:
			fill += "="
		var original: String = tracks[c]
		tracks[c] = original.substr(0, s_idx) + fill + original.substr(s_idx + seg_len)
		
	var lines = PackedStringArray()
	lines.append("0.0s " + "-" .repeat(width - 2) + " 8.0s")
	lines.append("DRIVER    : [%s]" % tracks["DRIVER"])
	lines.append("GUNNER    : [%s]" % tracks["GUNNER"])
	lines.append("LOADER    : [%s]" % tracks["LOADER"])
	lines.append("COMMANDER : [%s]" % tracks["COMMANDER"])
	return "\n".join(lines)
