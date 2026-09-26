extends RefCounted
class_name ContactTrack
## Maintains intelligence record, uncertainty tracking, last-known silhouette,
## and predicted movement corridor for an individual tracked contact.

const ObservationClass = preload("res://scripts/wego/Observation.gd")

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

func integrate_observation(obs, _sim_time: float = 0.0, crew_skill: Dictionary = {}) -> void:
	if obs == null: return
	if obs.is_direct_visual:
		update_visual_observation(obs, crew_skill)
	else:
		update_acoustic_observation(obs)

func predict_motion(dt: float, _sim_time: float = 0.0) -> void:
	decay(dt)

func update_visual_observation(obs, crew_skill: Dictionary = {}) -> void:
	has_visual_los = true
	time_since_visual = 0.0
	last_observation_time = obs.time
	last_observed_position = obs.target_position
	last_observed_orientation = deg_to_rad(obs.target_heading_deg)
	
	# Update ghost / silhouette
	has_silhouette = true
	silhouette_position = obs.target_position
	silhouette_yaw = last_observed_orientation
	silhouette_time = obs.time
	silhouette_heading_deg = obs.target_heading_deg
	silhouette_speed_mps = obs.target_speed_mps
	
	if not sources.has("Visual silhouette"):
		sources.append("Visual silhouette")
		
	# Rate of convergence modified by crew skill
	var spotter_skill = crew_skill.get("commander_spotting", 1.0)
	var gunner_skill = crew_skill.get("gunner_tracking", 1.0)
	
	consecutive_visual_seconds += 0.5 * spotter_skill
	var convergence_factor = clampf(consecutive_visual_seconds / 4.0, 0.0, 1.0)
	
	# Position & Range convergence
	estimated_position = estimated_position.lerp(obs.target_position, 0.4 + 0.5 * convergence_factor)
	estimated_range = obs.range_m
	estimated_bearing_deg = obs.bearing_deg
	
	# Convergence of uncertainties
	var min_pos_unc = 1.5
	var min_range_unc = 6.0
	var min_heading_unc = 3.0
	var min_speed_unc = 0.8
	
	position_uncertainty = lerpf(maxf(min_pos_unc, position_uncertainty * 0.7), min_pos_unc, convergence_factor * 0.4)
	range_uncertainty = lerpf(maxf(min_range_unc, range_uncertainty * 0.7), min_range_unc, convergence_factor * 0.5)
	
	# Heading convergence
	var heading_diff = angle_difference(deg_to_rad(estimated_heading_deg), deg_to_rad(obs.target_heading_deg))
	estimated_heading_deg = fposmod(rad_to_deg(deg_to_rad(estimated_heading_deg) - heading_diff * (0.35 + 0.4 * convergence_factor)), 360.0)
	heading_uncertainty = lerpf(maxf(min_heading_unc, heading_uncertainty * 0.75), min_heading_unc, convergence_factor * 0.4)
	
	# Speed convergence
	estimated_speed_mps = lerpf(estimated_speed_mps, obs.target_speed_mps, 0.35 + 0.45 * convergence_factor)
	speed_uncertainty = lerpf(maxf(min_speed_unc, speed_uncertainty * 0.75), min_speed_unc, convergence_factor * 0.4)
	
	# Classification progression
	identification_quality = minf(1.0, identification_quality + 0.25 * spotter_skill)
	if identification_quality > 0.75:
		classification = obs.target_classification
		identification_confidence = 0.95
	elif identification_quality > 0.4:
		classification = "Probable medium armor"
		identification_confidence = 0.7
	else:
		classification = "Armored vehicle"
		identification_confidence = 0.4
		
	# Gunner tracking progression
	if commander_observing and gunner_acquired:
		gunner_tracking_time += 0.5 * gunner_skill
		# Gunner tracking provides even tighter range and lead resolution
		range_uncertainty = minf(range_uncertainty, maxf(4.0, 16.0 - gunner_tracking_time * 3.0))
		speed_uncertainty = minf(speed_uncertainty, maxf(0.5, 4.0 - gunner_tracking_time * 0.8))

func update_acoustic_observation(obs) -> void:
	last_observation_time = obs.time
	estimated_bearing_deg = obs.bearing_deg
	if not sources.has(obs.source):
		sources.append(obs.source)
		
	if obs.source == "Cross-bearing fix":
		estimated_position = obs.target_position
		position_uncertainty = obs.position_uncertainty_m
		range_uncertainty = obs.range_uncertainty_m
		estimated_range = obs.range_m
	elif not has_visual_los:
		# Acoustic report from single station gives directional arc, but coarse range
		estimated_range = obs.range_m
		range_uncertainty = maxf(range_uncertainty, obs.range_uncertainty_m)
		# Update position along bearing if we don't have a recent fix
		if time_since_visual > 5.0 and position_uncertainty > 25.0:
			estimated_position = obs.target_position
			position_uncertainty = obs.position_uncertainty_m

func decay(delta: float) -> void:
	if not has_visual_los:
		time_since_visual += delta
		consecutive_visual_seconds = maxf(0.0, consecutive_visual_seconds - delta * 0.5)
		
		# Movement projection based on last-estimated heading and speed
		# NOTE: AI or hidden target might have stopped or turned, but our prediction
		# continues strictly on our own belief!
		var rad = deg_to_rad(estimated_heading_deg)
		var forward_vec = Vector3(sin(rad), 0, -cos(rad))
		estimated_position += forward_vec * estimated_speed_mps * delta
		
		# Uncertainty expands over time
		var speed_expansion = (estimated_speed_mps * 0.25 + 0.6) * delta
		position_uncertainty = minf(80.0, position_uncertainty + speed_expansion)
		range_uncertainty = minf(100.0, range_uncertainty + speed_expansion * 1.2)
		heading_uncertainty = minf(90.0, heading_uncertainty + delta * 2.5)
		speed_uncertainty = minf(12.0, speed_uncertainty + delta * 0.4)
		
		if time_since_visual > 2.5:
			gunner_acquired = false
			gunner_tracking_time = maxf(0.0, gunner_tracking_time - delta)
			
		# Filter visual from active sources after 13s decay
		if time_since_visual > 13.0 and sources.has("Visual silhouette"):
			sources.erase("Visual silhouette")
			sources.erase("Commander optics")
			sources.erase("Gunner sight")

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
	for i in range(steps + 1):
		var t = (float(i) / float(steps)) * duration_seconds
		var center_pt = origin + forward_dir * (estimated_speed_mps * t)
		var lateral_half_width = maxf(2.5, position_uncertainty * 0.5 + tan(deg_to_rad(heading_uncertainty * 0.5)) * (estimated_speed_mps * t))
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
