extends RefCounted
class_name FiringSolution
## Calculates moving-target lead, separates firing-solution prediction error
## from physical weapon dispersion, models platform stabilization (NONE, VERTICAL_ONLY,
## BASIC_TWO_AXIS, MODERN_TWO_AXIS), and tracks continuous solution convergence.

const ArmorModel = preload("res://scripts/wego/ArmorModel.gd")
const VehicleConfig = preload("res://scripts/wego/VehicleConfig.gd")

var predicted_target_position: Vector3 = Vector3.ZERO
var aim_point: Vector3 = Vector3.ZERO
var flight_time: float = 0.0
var solution_quality: String = "POOR" # "POOR", "DEVELOPING", "ACQUIRED", "OPTIMAL"
var target_error_offset: Vector3 = Vector3.ZERO
var dispersion_cone_rad: float = 0.0012
var gun_lay_error_rad: float = 0.0
var range_m: float = 75.0
var lead_offset: Vector3 = Vector3.ZERO

# Uncertainty ellipse data (for overlay display)
var ellipse_center: Vector3 = Vector3.ZERO
var ellipse_major_m: float = 20.0
var ellipse_minor_m: float = 5.0
var ellipse_angle_rad: float = 0.0

static func calculate(
	shooter,
	track,
	rng: RandomNumberGenerator,
	muzzle_speed: float = 880.0
) -> RefCounted:
	var sol = (load("res://scripts/wego/FiringSolution.gd") as GDScript).new()
	if shooter == null or track == null:
		return sol

	var config: VehicleConfig = shooter.config if ("config" in shooter and shooter.config != null) else VehicleConfig.create_mastodon()
	var origin: Vector3 = shooter.position + Vector3(0, 2.65, 0)
	var est_pos: Vector3 = track.estimated_position
	sol.range_m = maxf(10.0, origin.distance_to(est_pos))
	sol.flight_time = sol.range_m / maxf(100.0, muzzle_speed)
	
	# 1. Moving Target Lead (uses ESTIMATED speed and heading, NOT hidden truth!)
	var heading_rad = deg_to_rad(track.estimated_heading_deg)
	var est_vel = Vector3(sin(heading_rad), 0, -cos(heading_rad)) * track.estimated_speed_mps
	sol.lead_offset = est_vel * sol.flight_time
	sol.predicted_target_position = est_pos + sol.lead_offset
	sol.predicted_target_position.y = 1.45 # Target center of mass
	
	# 2. Continuous Solution Quality & Convergence
	# Affected by tracking duration, observation history, and target maneuvers
	var base_quality = "POOR"
	if track.gunner_acquired and track.range_uncertainty <= 8.0:
		base_quality = "OPTIMAL"
	elif track.gunner_acquired or track.range_uncertainty <= 16.0:
		base_quality = "ACQUIRED"
	elif track.has_visual_los or track.range_uncertainty <= 35.0:
		base_quality = "DEVELOPING"
	else:
		base_quality = "POOR"
		
	# 3. Target / Firing-Solution Error (Uncertainty in knowledge)
	var los_dir = (sol.predicted_target_position - origin).normalized()
	los_dir.y = 0.0
	los_dir = los_dir.normalized()
	var right_dir = los_dir.cross(Vector3.UP).normalized()
	
	var range_error_std = track.range_uncertainty * 0.45
	var lateral_error_std = maxf(1.0, track.position_uncertainty * 0.4 + track.speed_uncertainty * sol.flight_time * 0.5)
	
	var sample_range_err = rng.randfn(0.0, range_error_std)
	var sample_lat_err = rng.randfn(0.0, lateral_error_std)
	sol.target_error_offset = los_dir * sample_range_err + right_dir * sample_lat_err
	
	# Aim center incorporates knowledge error (where the crew BELIEVES they should aim)
	sol.aim_point = sol.predicted_target_position + sol.target_error_offset
	
	# Gravity drop compensation for flight time
	sol.aim_point.y += 0.5 * 9.81 * sol.flight_time * sol.flight_time
	
	# 4. Physical Gun Lay Error & Stabilization Disturbance
	var target_yaw = -atan2(sol.aim_point.x - origin.x, -(sol.aim_point.z - origin.z))
	var current_barrel_yaw = shooter.rotation.y + shooter.model.turret_yaw
	sol.gun_lay_error_rad = absf(angle_difference(current_barrel_yaw, target_yaw))
	
	# Physical platform disturbances:
	var speed: float = shooter.speed if "speed" in shooter else 0.0
	var yaw_rate: float = absf(shooter.yaw_rate) if "yaw_rate" in shooter else 0.0
	var roughness: float = shooter.terrain_roughness if "terrain_roughness" in shooter else 0.0
	var stabilizer_ok: bool = ("stabilizer_damaged" not in shooter or not shooter.stabilizer_damaged) and shooter.model.functional("Turret drive")
	var stab_mode: String = config.gun_stabilization if stabilizer_ok else "NONE"
	
	var stab_disturbance: float = 0.0
	match stab_mode:
		"NONE":
			# Unstabilized tank: moving severely disturbs sight picture and gun lay!
			if speed > 0.2:
				stab_disturbance += speed * 0.0065
				stab_disturbance += yaw_rate * 0.045
				stab_disturbance += roughness * 0.020
				# Movement breaks optimal solution on unstabilized platform
				if base_quality in ["OPTIMAL", "ACQUIRED"]:
					base_quality = "DEVELOPING" if speed < 3.0 else "POOR"
		"VERTICAL_ONLY":
			# Pitch stabilized, but yaw still causes sight disturbance
			if speed > 0.2:
				stab_disturbance += speed * 0.0018
				stab_disturbance += yaw_rate * 0.030
				stab_disturbance += roughness * 0.010
				if base_quality == "OPTIMAL" and speed > 2.0:
					base_quality = "ACQUIRED"
		"BASIC_TWO_AXIS":
			# Mastodon gyroscopic 2-axis stabilization:
			# Smooth road movement at moderate speed retains good firing solution!
			# High speed, rough terrain, or rapid turns exceed gyro response:
			if speed > 4.5:
				stab_disturbance += (speed - 4.5) * 0.0025
			if yaw_rate > 0.25:
				stab_disturbance += (yaw_rate - 0.25) * 0.035
			if roughness > 0.15:
				stab_disturbance += (roughness - 0.15) * 0.018
		"MODERN_TWO_AXIS":
			# Modern computerized fire control: smooth high-speed engagement
			if speed > 10.0:
				stab_disturbance += (speed - 10.0) * 0.0008
			if roughness > 0.35:
				stab_disturbance += (roughness - 0.35) * 0.010
				
	sol.solution_quality = base_quality
	
	# 5. Mechanical Weapon Dispersion
	var cone = 0.0010 * (1.0 / maxf(0.5, config.fire_control_quality))
	cone += stab_disturbance
	
	# Crew condition impacts
	if not shooter.model.occupied("Gunner"):
		if config.commander_weapon_override and shooter.model.occupied("Commander"):
			cone += 0.0035 # Commander laying gun via override
		else:
			cone += 0.0090 # Emergency untrained gun laying
	else:
		for c in shooter.model.crew:
			if c.station == "Gunner" and c.state == "Wounded":
				cone += 0.0028
			elif c.station == "Gunner" and c.state == "Seriously wounded":
				cone += 0.0065
				
	# Damaged optics penalty
	if not shooter.model.functional("Gunsight"):
		cone += 0.0075
		
	sol.dispersion_cone_rad = cone
	
	# Ellipse parameters for visualization
	sol.ellipse_center = sol.predicted_target_position
	sol.ellipse_major_m = maxf(3.0, track.range_uncertainty)
	sol.ellipse_minor_m = maxf(2.0, lateral_error_std * 2.0 + stab_disturbance * sol.range_m)
	sol.ellipse_angle_rad = atan2(los_dir.x, -los_dir.z)
	
	return sol

func compute_shell_direction(origin: Vector3, rng: RandomNumberGenerator) -> Vector3:
	var nominal_dir = (aim_point - origin).normalized()
	var right = nominal_dir.cross(Vector3.UP).normalized()
	var up = right.cross(nominal_dir).normalized()
	var disp_x = rng.randfn(0.0, dispersion_cone_rad)
	var disp_y = rng.randfn(0.0, dispersion_cone_rad)
	return (nominal_dir + right * disp_x + up * disp_y).normalized()
