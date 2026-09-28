extends RefCounted
class_name ContactTrack
## Maintains intelligence record, uncertainty tracking, last-known silhouette,
## and predicted movement corridor for an individual tracked contact.

const ObservationClass = preload("res://scripts/wego/Observation.gd")

enum Stage { NOTHING, CUE, SUSPECTED, LOCATED, CLASSIFIED, TRACKED, GUNNER_ACQUIRED, FIRING_SOLUTION }
var contact_stage: int = Stage.NOTHING
var cues: Array = []
var visible_fraction: float = 0.0
var has_confirmed_vehicle: bool = false
var has_confirmed_tank: bool = false
var has_orientation: bool = false
var has_speed_estimate: bool = false
var last_visual_time: float = -1.0
var contact_id: String = "CONTACT_A"
var last_observed_position: Vector3 = Vector3.ZERO
var estimated_position: Vector3 = Vector3.ZERO
var last_observed_orientation: float = 0.0 # Radians
var estimated_heading_deg: float = 0.0 # 0-360 deg
var estimated_speed_mps: float = 0.0 # m/s
var estimated_range: float = 0.0 # m
var estimated_bearing_deg: float = 0.0 # deg
var classification: String = "Unconfirmed contact"
var identification_quality: float = 0.0 # 0.0 - 1.0

var last_observation_time: float = -1.0
var time_since_visual: float = 999.0
var has_visual_los: bool = false
var commander_observing: bool = false
var gunner_acquired: bool = false
var gunner_tracking_time: float = 0.0

# Separate uncertainties
var position_uncertainty: float = 30.0 # meters
var range_uncertainty: float = 60.0 # meters
var heading_uncertainty: float = 35.0 # degrees
var speed_uncertainty: float = 6.0 # m/s (approx 21 km/h)
var identification_confidence: float = 0.1

var sources: Array = []
var observation_history: Array[Dictionary] = []

# Last-Known Silhouette (frozen at last visual contact)
var has_silhouette: bool = false
var silhouette_position: Vector3 = Vector3.ZERO
var silhouette_yaw: float = 0.0
var silhouette_time: float = 0.0
var silhouette_heading_deg: float = 0.0
var silhouette_speed_mps: float = 0.0

# Convergence tracking
var consecutive_visual_seconds: float = 0.0

func _init(id: String = "CONTACT_A") -> void:
	contact_id = id

func has_contact() -> bool:
	return contact_stage >= Stage.SUSPECTED

func integrate_observation(obs, _sim_time: float = 0.0, crew_skill: Dictionary = {}) -> void:
	if obs == null: return
	if obs.is_direct_visual:
		update_visual_observation(obs, crew_skill)
	else:
		update_acoustic_observation(obs)

func predict_motion(dt: float, _sim_time: float = 0.0) -> void:
	decay(dt)

func add_cue(cue) -> void:
	if cue == null: return
	for i in range(cues.size() - 1, -1, -1):
		if cues[i].cue_id == cue.cue_id or cues[i].is_expired(cue.timestamp): cues.remove_at(i)
	cues.append(cue)
	if cues.size() > 8: cues.pop_front()
	if contact_stage < Stage.SUSPECTED:
		contact_stage = Stage.CUE
		estimated_bearing_deg = cue.bearing_deg

func sensing_update(result: Dictionary, dt: float, now: float, crew_skill: Dictionary = {}) -> void:
	add_cue(result.get("cue"))
	var report = result.get("visual_observation")
	# This flag means CURRENT measurement; memory is kept in separate fields.
	has_visual_los = report != null
	if report != null:
		update_visual_observation(report, crew_skill)
	else:
		decay(dt)
	var acoustic = result.get("acoustic_observation")
	if acoustic != null: update_acoustic_observation(acoustic)
	for i in range(cues.size() - 1, -1, -1):
		if cues[i].is_expired(now): cues.remove_at(i)
	if contact_stage == Stage.CUE and cues.is_empty(): contact_stage = Stage.NOTHING

func update_visual_observation(obs, crew_skill: Dictionary = {}) -> void:
	has_visual_los = true
	time_since_visual = 0.0
	last_visual_time = obs.time
	last_observation_time = obs.time
	contact_stage = obs.contact_stage
	visible_fraction = obs.visible_fraction
	if obs.target_classification in ["Enemy tank", "A-47 Mastodon"] or obs.source == "Visual silhouette":
		has_confirmed_tank = true
		has_confirmed_vehicle = true
		if contact_stage < Stage.CLASSIFIED:
			contact_stage = Stage.CLASSIFIED
	else:
		has_confirmed_vehicle = contact_stage >= Stage.LOCATED
		has_confirmed_tank = obs.target_classification == "Enemy tank"

	has_orientation = obs.has_orientation or obs.target_heading_deg != 0.0 or obs.heading_uncertainty_deg < 40.0
	has_speed_estimate = obs.has_speed_estimate or obs.target_speed_mps > 0.0 or obs.speed_uncertainty_mps < 5.0
	estimated_position = obs.target_position
	last_observed_position = obs.target_position
	estimated_range = obs.range_m
	estimated_bearing_deg = obs.bearing_deg
	
	# Progressive refinement of uncertainties with visual tracking
	position_uncertainty = obs.position_uncertainty_m
	range_uncertainty = obs.range_uncertainty_m
	classification = obs.target_classification
	if has_confirmed_tank:
		identification_quality = minf(1.0, maxf(0.5, identification_quality + 0.25))
	elif has_confirmed_vehicle:
		identification_quality = minf(0.8, maxf(0.3, identification_quality + 0.15))
	else:
		identification_quality = maxf(0.1, identification_quality)
	identification_confidence = identification_quality
	
	if has_orientation:
		estimated_heading_deg = obs.target_heading_deg
		heading_uncertainty = minf(heading_uncertainty, obs.heading_uncertainty_deg)
		heading_uncertainty = maxf(3.0, heading_uncertainty * 0.75)
		last_observed_orientation = -deg_to_rad(estimated_heading_deg)
	if has_speed_estimate:
		estimated_speed_mps = obs.target_speed_mps
		speed_uncertainty = minf(speed_uncertainty, obs.speed_uncertainty_mps)
		speed_uncertainty = maxf(0.5, speed_uncertainty * 0.75)
		
	# Gunner tracking refinement
	if (commander_observing and gunner_acquired) or crew_skill.has("gunner_tracking"):
		var tracking_time = maxf(gunner_tracking_time, crew_skill.get("gunner_tracking", 0.0))
		range_uncertainty = minf(range_uncertainty, maxf(4.0, 16.0 - tracking_time * 3.0))
		speed_uncertainty = minf(speed_uncertainty, maxf(0.5, 4.0 - tracking_time * 0.8))
		
	consecutive_visual_seconds += obs.observation_duration
	if (has_confirmed_tank or obs.source == "Visual silhouette") and has_orientation and contact_stage >= Stage.CLASSIFIED:
		has_silhouette = true
		silhouette_position = estimated_position
		silhouette_yaw = last_observed_orientation
		silhouette_time = obs.time
		silhouette_heading_deg = estimated_heading_deg
		silhouette_speed_mps = estimated_speed_mps
	if not sources.has(obs.source): sources.append(obs.source)
	observation_history.append(obs.to_dict())
	if observation_history.size() > 64: observation_history.pop_front()

func update_acoustic_observation(obs) -> void:
	if not sources.has(obs.source): sources.append(obs.source)
	# Sound never creates a silhouette, classification, motion, or visual LOS.
	if obs.source != "Cross-bearing fix" or has_visual_los or has_silhouette: return
	last_observation_time = obs.time
	contact_stage = Stage.SUSPECTED
	classification = "Possible sound source"
	estimated_bearing_deg = obs.bearing_deg
	estimated_position = obs.target_position
	position_uncertainty = obs.position_uncertainty_m
	range_uncertainty = obs.range_uncertainty_m
	estimated_range = obs.range_m

func decay(delta: float) -> void:
	time_since_visual += delta
	if time_since_visual > 0.35: has_visual_los = false
	if has_visual_los: return
	consecutive_visual_seconds = maxf(0.0, consecutive_visual_seconds - delta * 0.5)
	if has_speed_estimate and has_orientation:
		var rad = deg_to_rad(estimated_heading_deg)
		estimated_position += Vector3(sin(rad), 0, -cos(rad)) * estimated_speed_mps * delta
	position_uncertainty += (absf(estimated_speed_mps) * 0.25 + 0.6) * delta
	range_uncertainty += delta * 1.2
	heading_uncertainty = minf(90.0, heading_uncertainty + delta * 2.5)
	speed_uncertainty = minf(12.0, speed_uncertainty + delta * 0.4)
	gunner_acquired = false
	gunner_tracking_time = 0.0

func stage_name() -> String:
	return Stage.keys()[contact_stage].replace("_", " ")

func intel_text() -> String:
	var lines: Array[String] = [classification.to_upper(), stage_name()]
	if contact_stage >= Stage.LOCATED:
		lines.append("Range %.0f–%.0f m" % [maxf(0.0, estimated_range - range_uncertainty), estimated_range + range_uncertainty])
	else:
		lines.append("Position uncertain • investigate sector")
	if has_orientation: lines.append("Heading %03d° ±%d°" % [int(estimated_heading_deg), int(heading_uncertainty)])
	if has_speed_estimate: lines.append("Speed %.0f–%.0f km/h" % [maxf(0.0, estimated_speed_mps - speed_uncertainty) * 3.6, (estimated_speed_mps + speed_uncertainty) * 3.6])
	if not has_visual_los: lines.append("Last visual %.1fs ago" % time_since_visual if last_visual_time >= 0.0 else "No visual confirmation")
	return "\n".join(lines)
func apply_observed_impact(relation: String) -> void:
	# Observed shell splash relative to target adjusts range/bearing
	match relation:
		"SHORT":
			# Shell landed short of target -> target is farther than we thought
			estimated_range += range_uncertainty * 0.35
			range_uncertainty = maxf(5.0, range_uncertainty * 0.7)
		"OVER":
			# Shell landed beyond target -> target is closer than we thought
			estimated_range = maxf(20.0, estimated_range - range_uncertainty * 0.35)
			range_uncertainty = maxf(5.0, range_uncertainty * 0.7)
		"LEFT":
			estimated_bearing_deg = fposmod(estimated_bearing_deg + 1.2, 360.0)
			heading_uncertainty = maxf(3.0, heading_uncertainty * 0.75)
		"RIGHT":
			estimated_bearing_deg = fposmod(estimated_bearing_deg - 1.2, 360.0)
			heading_uncertainty = maxf(3.0, heading_uncertainty * 0.75)

func get_predicted_corridor(duration_seconds: float = 6.0) -> Dictionary:
	# Returns the predicted travel path and expanding corridor bounds
	var origin = silhouette_position if has_silhouette else estimated_position
	var rad = deg_to_rad(estimated_heading_deg)
	var forward_dir = Vector3(sin(rad), 0, -cos(rad)).normalized()
	var right_dir = forward_dir.cross(Vector3.UP).normalized()
	
	var samples: Array[Vector3] = []
	var left_bounds: Array[Vector3] = []
	var right_bounds: Array[Vector3] = []
	
	var steps = 6
	var elapsed = maxf(0.0, time_since_visual if last_visual_time >= 0.0 else 0.0)
	for i in range(steps + 1):
		var t = (float(i) / float(steps)) * duration_seconds
		var center_pt = origin + forward_dir * (estimated_speed_mps * t)
		var lateral_half_width = maxf(2.5, position_uncertainty * 0.5 + tan(deg_to_rad(heading_uncertainty * 0.5)) * (estimated_speed_mps * (elapsed + t)))
		samples.append(center_pt)
		left_bounds.append(center_pt - right_dir * lateral_half_width)
		right_bounds.append(center_pt + right_dir * lateral_half_width)
		
	return {
		"origin": origin,
		"center_line": samples,
		"left_edge": left_bounds,
		"right_edge": right_bounds,
		"speed": estimated_speed_mps,
		"heading": estimated_heading_deg
	}

func to_dict() -> Dictionary:
	var primary_source = "Visual silhouette" if (has_silhouette and time_since_visual < 13.0) else (sources.back() if not sources.is_empty() else "Unconfirmed")
	return {
		"id": contact_id,
		"position": estimated_position,
		"uncertainty": position_uncertainty,
		"range": estimated_range,
		"range_uncertainty": range_uncertainty,
		"bearing": estimated_bearing_deg,
		"heading": estimated_heading_deg,
		"heading_uncertainty": heading_uncertainty,
		"speed": estimated_speed_mps,
		"speed_uncertainty": speed_uncertainty,
		"classification": classification,
		"confidence": identification_confidence,
		"source": primary_source,
		"time": last_observation_time,
		"is_visual": has_visual_los,
		"has_silhouette": has_silhouette,
		"silhouette_pos": silhouette_position,
		"silhouette_yaw": silhouette_yaw,
		"silhouette_time": silhouette_time
	}

