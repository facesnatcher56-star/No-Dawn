extends RefCounted
class_name SensorModel
## Truth is read only here to generate noisy, property-specific measurements.
const ObservationClass = preload("res://scripts/wego/Observation.gd")
const Cue = preload("res://scripts/wego/ReconCue.gd")
const Visibility = preload("res://scripts/wego/CrewVisibility.gd")
var rng: RandomNumberGenerator

func _init(p_rng: RandomNumberGenerator = null) -> void:
	rng = p_rng if p_rng != null else RandomNumberGenerator.new()

func evaluate(observer, target, world_3d: World3D, sim_time: float,
	gun_report: bool = false, impact_pos: Variant = null, delta_time: float = 0.25) -> Dictionary:
	var result = {"visual_observation": null, "acoustic_observation": null,
		"impact_observation": null, "cue": null, "gunner_can_acquire": false,
		"has_los": false, "visible_fraction": 0.0}
	if observer == null or target == null: return result
	var offset: Vector3 = target.position - observer.position
	var distance: float = offset.length()
	var bearing: float = rad_to_deg(atan2(offset.x, -offset.z))
	var best = null
	var best_detail: Dictionary = {}
	var best_quality: float = -1.0
	for station in observer.observers.values():
		var visibility = Visibility.sample_vehicle(observer, station, target, world_3d)
		var fraction: float = visibility.fraction
		station.visible_fraction = fraction
		station.debug_rays = visibility.rays
		station.los_state = fraction > 0.0
		result.visible_fraction = maxf(result.visible_fraction, fraction)
		result.has_los = result.has_los or fraction > 0.0
		if fraction <= 0.0:
			station.lose_evidence(target.name, delta_time)
			continue
		var gunner_active: bool = false
		if station.role_name == "Gunner":
			if station.current_task in ["DESIGNATING", "TRACKING"]:
				gunner_active = true
			elif station.is_sector_assigned:
				gunner_active = true
			elif observer.get("gunner_sight") != null and observer.gunner_sight.is_active():
				gunner_active = true
		var deliberate: bool = (station.role_name == "Commander" and station.is_sector_assigned) or gunner_active
		var close_threat: bool = distance < 120.0 and fraction >= 0.4
		var skill: float = observer.crew_skill.get("gunner_tracking" if station.role_name == "Gunner" else "commander_spotting", 1.0)
		var exposed: bool = observer.orders.get("commander_exposed", false) and station.role_name == "Commander"
		var noticeable: bool = target.speed > 0.4 or target.flash > 0.0 or close_threat or deliberate
		var detail: Dictionary = station.evidence.get(target.name, {"bearing": 0.0, "range": 0.0, "classification": 0.0, "motion": 0.0, "notice": 0.0, "lost": 0.0})
		station.evidence[target.name] = detail
		detail.lost = 0.0
		if noticeable:
			detail.notice += delta_time * fraction * skill * (1.4 if exposed else 1.0)
			if detail.notice > (0.15 if close_threat else 1.5):
				result.cue = make_cue(observer, station.role_name, sim_time, bearing,
					"MUZZLE_FLASH" if target.flash > 0.0 else ("MOVEMENT" if target.speed > 0.4 else "SILHOUETTE"), 12.0 / maxf(0.5, skill))
				result.cue.distance_category = "NEAR" if distance < 250 else ("MEDIUM" if distance < 800 else "LONG RANGE")
		if not deliberate and not close_threat:
			station.lose_evidence(target.name, delta_time)
			continue
		var angular_factor: float = clampf(1500.0 / maxf(80.0, distance), 0.35, 4.0)
		var width_factor: float = clampf(45.0 / station.horizontal_fov_deg, 0.5, 2.0)
		var vibration: float = 1.0 / (1.0 + absf(observer.speed) * 0.15)
		var quality: float = fraction * angular_factor * skill * station.optic_quality * vibration * width_factor
		if station.is_magnified: quality *= 1.25
		if exposed: quality *= 1.15
		if close_threat: quality *= 5.0
		# Independent evidence: broad movement can locate before detail identifies;
		# partial stationary silhouettes can identify before reliable motion exists.
		detail.bearing += delta_time * quality * (1.3 if target.speed > 0.4 else 1.0)
		detail.range += delta_time * quality * 0.7
		detail.classification += delta_time * quality * fraction * 0.6
		detail.motion += delta_time * quality * 0.45
		station.detection_progress[target.name] = clampf(detail.classification / 10.0, 0.0, 1.0)
		if detail.bearing >= 1.0 and quality > best_quality:
			best = station
			best_detail = detail
			best_quality = quality
		if station.role_name == "Gunner" and deliberate and detail.bearing > 1.0:
			result.gunner_can_acquire = true
	if best != null:
		result.visual_observation = visual_measurement(observer, target, best, best_detail, distance, bearing, sim_time, delta_time)
	# Reports remain bearings. No guessed range derived from hidden distance.
	var own_noise: float = (1.0 if observer.engine_on else 0.0) + absf(observer.speed) * 0.3
	if gun_report or (target.engine_on and target.model.functional("Engine") and distance < 180.0 / (1.0 + own_noise)):
		var arc: float = 8.0 if gun_report else 28.0 + own_noise * 5.0
		var acoustic = make_cue(observer, "Crew", sim_time, bearing, "GUN_REPORT" if gun_report else "ENGINE_NOISE", arc)
		acoustic.source_type = "ACOUSTIC"
		acoustic.strength = 1.0 if gun_report else 0.3
		result.cue = acoustic
		var fix = cross_bearing(observer, acoustic)
		if fix != null:
			result.acoustic_observation = fix
		else:
			var angle = deg_to_rad(acoustic.bearing_deg)
			var dir = Vector3(sin(angle), 0, -cos(angle))
			var single_obs = ObservationClass.new(
				sim_time,
				observer.position,
				"Gun report" if gun_report else "Engine noise",
				acoustic.bearing_deg,
				acoustic.bearing_uncertainty,
				0.0,
				150.0,
				observer.position + dir * 200.0,
				250.0
			)
			single_obs.position_uncertainty_m = 250.0
			result.acoustic_observation = single_obs
	if impact_pos != null and observer.track != null and observer.track.has_visual_los and Visibility.union_sees_point([observer], impact_pos + Vector3.UP * 0.6, world_3d):
		var difference: float = observer.position.distance_to(impact_pos) - observer.track.estimated_range
		result.impact_observation = "SHORT" if difference < -4.0 else ("OVER" if difference > 4.0 else "ON ESTIMATE")
	return result

func make_cue(observer, source: String, time: float, bearing: float, category: String, arc: float):
	var cue = Cue.new()
	cue.cue_id = "%s:%s" % [source, category]
	cue.source = source
	cue.timestamp = time
	cue.observer_position = observer.position
	cue.bearing_deg = fposmod(bearing + rng.randf_range(-arc, arc), 360.0)
	cue.bearing_uncertainty = arc
	cue.category = category
	return cue

func visual_measurement(observer, target, station, detail: Dictionary, distance: float, bearing: float, time: float, dt: float):
	var stage: int = 2
	if detail.bearing >= 4.0 and detail.range >= 2.5: stage = 3
	if detail.classification >= 5.0 and stage >= 3: stage = 4
	if detail.classification >= 10.0 and detail.motion >= 6.0 and detail.range >= 8.0: stage = 5
	var bearing_error: float = maxf(0.4, 7.0 / sqrt(maxf(1.0, detail.bearing)))
	var range_error: float = distance * maxf(0.025, 0.35 / sqrt(maxf(1.0, detail.range)))
	var measured_bearing: float = bearing + rng.randf_range(-bearing_error, bearing_error)
	var measured_range: float = maxf(1.0, distance + rng.randf_range(-range_error, range_error))
	var direction = Vector3(sin(deg_to_rad(measured_bearing)), 0, -cos(deg_to_rad(measured_bearing)))
	var estimated_position: Vector3 = observer.position + direction * measured_range
	var report = ObservationClass.new(time, observer.position, station.role_name + " optics", measured_bearing,
		bearing_error, measured_range, range_error, estimated_position, maxf(range_error, distance * deg_to_rad(bearing_error)))
	report.is_direct_visual = true
	report.contact_stage = stage
	report.visible_fraction = station.visible_fraction
	report.observation_duration = dt
	report.target_classification = "Possible vehicle" if stage == 2 else ("Tracked vehicle" if stage == 3 else ("Armored vehicle" if detail.classification < 10.0 else "Enemy tank"))
	if station.visible_fraction < 0.35: report.target_classification = "Possible turret"
	report.has_orientation = detail.motion >= 3.0 and station.visible_fraction >= 0.4
	report.has_speed_estimate = detail.motion >= 6.0
	if report.has_orientation:
		report.heading_uncertainty_deg = maxf(6.0, 40.0 / sqrt(detail.motion))
		report.target_heading_deg = fposmod(rad_to_deg(-target.rotation.y) + rng.randf_range(-report.heading_uncertainty_deg, report.heading_uncertainty_deg), 360.0)
	if report.has_speed_estimate:
		report.speed_uncertainty_mps = maxf(0.8, 5.0 / sqrt(detail.motion))
		report.target_speed_mps = maxf(0.0, target.speed + rng.randf_range(-report.speed_uncertainty_mps, report.speed_uncertainty_mps))
	return report

func cross_bearing(observer, cue):
	var here = Vector2(cue.observer_position.x, cue.observer_position.z)
	var angle = deg_to_rad(cue.bearing_deg)
	var direction = Vector2(sin(angle), -cos(angle))
	var report = null
	for previous in observer.history:
		if cue.timestamp - previous.time > 20.0 or here.distance_to(previous.position) < 40.0: continue
		var cross: float = direction.cross(previous.direction)
		if absf(cross) < 0.15: continue
		var t: float = (previous.position - here).cross(previous.direction) / cross
		var old_t: float = (previous.position - here).cross(direction) / cross
		if t <= 0.0 or old_t <= 0.0 or t > 4000.0: continue
		var uncertainty: float = maxf(40.0, (t + old_t) * deg_to_rad(cue.bearing_uncertainty) / absf(cross))
		var point: Vector2 = here + direction * t
		report = ObservationClass.new(cue.timestamp, cue.observer_position, "Cross-bearing fix", cue.bearing_deg,
			cue.bearing_uncertainty, t, uncertainty, Vector3(point.x, cue.observer_position.y, point.y), uncertainty)
		report.source = "Cross-bearing fix"
		report.position_uncertainty_m = uncertainty
		break
	if observer.history.is_empty() or here.distance_to(observer.history.back().position) >= 40.0:
		observer.history.append({"position": here, "direction": direction, "time": cue.timestamp})
		if observer.history.size() > 15: observer.history.pop_front()
	return report
