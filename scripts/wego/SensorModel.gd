extends RefCounted
class_name SensorModel
## Manages visual line-of-sight, commander/gunner optics sectors, acoustic detection,
## cross-bearing triangulation, and shell impact observation.

const ObservationClass = preload("res://scripts/wego/Observation.gd")

var rng: RandomNumberGenerator

func _init(p_rng: RandomNumberGenerator = null) -> void:
	if p_rng != null:
		rng = p_rng
	else:
		rng = RandomNumberGenerator.new()
		rng.randomize()

func evaluate(
	observer,
	target,
	world_3d: World3D,
	sim_time: float,
	gun_report: bool = false,
	impact_pos: Variant = null
) -> Dictionary:
	var result: Dictionary = {
		"visual_observation": null,
		"acoustic_observation": null,
		"impact_observation": null,
		"gunner_can_acquire": false,
		"has_los": false
	}
	
	if observer == null or target == null:
		return result
		
	var offset: Vector3 = target.position - observer.position
	var distance = offset.length()
	var actual_bearing_rad = atan2(offset.x, -offset.z)
	var actual_bearing_deg = fposmod(rad_to_deg(actual_bearing_rad), 360.0)
	
	var observer_hull_yaw = observer.rotation.y
	var observer_turret_yaw = observer_hull_yaw + observer.model.turret_yaw
	var observer_gun_bearing = -observer_turret_yaw
	
	# Check Line of Sight
	var observer_eye = observer.position + Vector3(0, 2.75, 0)
	var target_center = target.position + Vector3(0, 1.85, 0)
	
	var has_clear_los = false
	if world_3d != null:
		var space_state = world_3d.direct_space_state
		if space_state != null:
			var query = PhysicsRayQueryParameters3D.create(observer_eye, target_center, 1) # Layer 1 terrain
			var hit = space_state.intersect_ray(query)
			has_clear_los = hit.is_empty()
	else:
		has_clear_los = true
		
	result["has_los"] = has_clear_los
	
	# Commander & Optics status
	var has_commander = observer.model.occupied("Commander")
	var commander_optics_ok = observer.model.functional("Commander optics")
	var commander_exposed = observer.orders.get("commander_exposed", false)
	
	# Sector Check:
	# Commander cupola provides 360 observation if exposed or 110 deg front arc if buttoned
	var commander_sector_ok = false
	if has_commander and commander_optics_ok:
		if commander_exposed:
			commander_sector_ok = true # Full 360 degree scan
		else:
			var angle_off_turret = absf(angle_difference(observer_gun_bearing, actual_bearing_rad))
			commander_sector_ok = angle_off_turret < deg_to_rad(55.0)
			
	# Gunner Optics check (narrow precision FOV ~14 degrees)
	var has_gunner = observer.model.occupied("Gunner")
	var angle_to_gun = absf(angle_difference(observer_gun_bearing, actual_bearing_rad))
	var in_gunner_fov = angle_to_gun < deg_to_rad(14.0)
	var gunner_can_acquire = has_clear_los and has_gunner and in_gunner_fov
	result["gunner_can_acquire"] = gunner_can_acquire
	
	# Visual Detection Criteria
	var target_lit = (target.lamp != null and target.lamp.visible) or (observer.lamp != null and observer.lamp.visible) or target.flash > 0.0
	var max_visual_dist = 140.0 if target_lit else 48.0
	var visual_candidate = has_clear_los and (commander_sector_ok or in_gunner_fov) and distance < max_visual_dist
	
	if visual_candidate:
		var obs = ObservationClass.new(
			sim_time,
			observer.position,
			"Gunner sight" if in_gunner_fov else "Commander optics",
			actual_bearing_deg + rng.randf_range(-0.4, 0.4),
			0.8 if in_gunner_fov else 2.0,
			distance * rng.randf_range(0.97, 1.03),
			distance * (0.04 if in_gunner_fov else 0.08),
			target.position + Vector3(rng.randf_range(-0.6, 0.6), 0, rng.randf_range(-0.6, 0.6)),
			maxf(1.5, distance * 0.02)
		)
		obs.is_direct_visual = true
		
		# Estimate target heading from orientation
		var target_yaw_deg = fposmod(rad_to_deg(-target.rotation.y), 360.0)
		obs.target_heading_deg = target_yaw_deg + rng.randf_range(-6.0, 6.0)
		obs.heading_uncertainty_deg = 8.0 if in_gunner_fov else 14.0
		
		# Estimate target speed
		obs.target_speed_mps = target.speed + rng.randf_range(-0.5, 0.5)
		obs.speed_uncertainty_mps = 1.2 if in_gunner_fov else 2.5
		
		obs.target_classification = "Heavy Cruiser Tank" if "Mastodon" in target.name else "Medium Armor"
		result["visual_observation"] = obs
		
	# Acoustic Sensing (Gun report or Engine noise)
	var acoustic_eligible = gun_report or (target.engine_on and target.model.functional("Engine") and distance < 240.0)
	if acoustic_eligible:
		var arc_deg = 3.0 if gun_report else (8.0 if not observer.engine_on else 15.0)
		var measured_bearing_rad = actual_bearing_rad + deg_to_rad(rng.randf_range(-arc_deg, arc_deg))
		var measured_bearing_deg = fposmod(rad_to_deg(measured_bearing_rad), 360.0)
		
		var dir_2d = Vector2(sin(measured_bearing_rad), -cos(measured_bearing_rad))
		var here_2d = Vector2(observer.position.x, observer.position.z)
		
		var range_guess = distance * rng.randf_range(0.70, 1.30)
		var estimated_pt = here_2d + dir_2d * range_guess
		var pos_uncertainty = maxf(6.0, distance * 0.35)
		var range_uncertainty = maxf(15.0, distance * 0.30)
		var source_name = "Gun report" if gun_report else "Engine noise"
		
		# Cross-bearing triangulation check with observer history
		for hist in observer.history:
			if here_2d.distance_to(hist.position) < 12.0 or (sim_time - hist.time) > 25.0:
				continue
			var cross = dir_2d.cross(hist.direction)
			if absf(cross) < 0.15:
				continue # Crossing angle too shallow
			var t = (hist.position - here_2d).cross(hist.direction) / cross
			var old_t = (hist.position - here_2d).cross(dir_2d) / cross
			if t > 10.0 and t < 600.0 and old_t > 0:
				estimated_pt = here_2d + dir_2d * t
				pos_uncertainty = maxf(4.0, t * deg_to_rad(arc_deg) / absf(cross))
				range_uncertainty = pos_uncertainty * 1.2
				range_guess = t
				source_name = "Cross-bearing fix"
				break
				
		# Update history if moved sufficiently
		if observer.history.is_empty() or here_2d.distance_to(observer.history.back().position) > 8.0:
			observer.history.append({"position": here_2d, "direction": dir_2d, "time": sim_time})
			if observer.history.size() > 15:
				observer.history.pop_front()
				
		var obs_acoustic = ObservationClass.new(
			sim_time,
			observer.position,
			source_name,
			measured_bearing_deg,
			arc_deg,
			range_guess,
			range_uncertainty,
			Vector3(estimated_pt.x, target.position.y, estimated_pt.y),
			pos_uncertainty
		)
		result["acoustic_observation"] = obs_acoustic

	# Impact observation (check if shell landing was observed)
	if impact_pos != null and has_clear_los:
		var target_dist = observer.position.distance_to(target.position)
		var impact_dist = observer.position.distance_to(impact_pos)
		var diff = impact_dist - target_dist
		var relation = "HIT"
		if diff < -4.0:
			relation = "SHORT"
		elif diff > 4.0:
			relation = "OVER"
		else:
			# Check lateral
			var gun_dir = (target.position - observer.position).normalized()
			var lateral = (impact_pos - target.position).cross(Vector3.UP).dot(gun_dir)
			if lateral > 2.0: relation = "RIGHT"
			elif lateral < -2.0: relation = "LEFT"
		result["impact_observation"] = relation

	return result
